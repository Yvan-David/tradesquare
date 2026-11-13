"""
The doctor's check framework and every individual check (ALTATTS flavour of
the ALTASR doctor).

Design rules:
- Every check reports PASS / WARN / FAIL / INFO, the value found, the value
  expected, and -- for anything not PASS/INFO -- a concrete remediation.
  **A FAIL without a remediation is rejected by the framework itself.**
- Nothing here may crash on a CPU-only machine without an NVIDIA driver, or
  in an interpreter without torch: every probe is wrapped, absence of a
  component is a *finding*, never an exception.
- Probes are cheap: the full read-only doctor must finish in a few seconds.
"""
from __future__ import annotations

import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

PASS, WARN, FAIL, INFO = "PASS", "WARN", "FAIL", "INFO"


@dataclass
class CheckResult:
    section: str
    name: str
    status: str
    found: str = ""
    expected: str = ""
    remediation: str = ""

    def __post_init__(self) -> None:
        if self.status not in (PASS, WARN, FAIL, INFO):
            raise ValueError(f"bad status {self.status!r}")
        if self.status == FAIL and not self.remediation:
            raise ValueError(
                f"check {self.section}/{self.name} FAILed without a "
                f"remediation -- a FAIL that doesn't tell the user what to "
                f"do is a bug.")

    def to_dict(self) -> Dict[str, str]:
        return {"section": self.section, "name": self.name,
                "status": self.status, "found": self.found,
                "expected": self.expected, "remediation": self.remediation}


def _run(cmd: List[str], timeout: float = 5.0) -> Tuple[int, str]:
    """Run a command, never raise: (returncode, stdout+stderr)."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=timeout)
        return p.returncode, (p.stdout or "") + (p.stderr or "")
    except (OSError, subprocess.SubprocessError) as exc:
        return -1, str(exc)


# =========================================================================== #
#  Environment detection (shared by several check groups and by --fix)
# =========================================================================== #
def detect_python_env() -> Dict[str, Any]:
    in_venv = sys.prefix != getattr(sys, "base_prefix", sys.prefix)
    conda = os.environ.get("CONDA_PREFIX", "")
    in_conda = bool(conda) and sys.prefix.startswith(conda)
    kind = "venv" if in_venv else ("conda" if in_conda else "system")
    managers = [m for m in ("pip", "uv", "conda")
                if shutil.which(m) or _module_exists(m)]
    return {"python": platform.python_version(), "executable": sys.executable,
            "prefix": sys.prefix, "kind": kind, "managers": managers}


def _module_exists(name: str) -> bool:
    import importlib.util
    try:
        return importlib.util.find_spec(name) is not None
    except (ImportError, ValueError):
        return False


def detect_torch() -> Dict[str, Any]:
    """Everything about the installed torch stack, without assuming it
    exists or works."""
    info: Dict[str, Any] = {"ok": False, "version": None, "cuda_build": None,
                            "variant": "absent", "cuda_available": False,
                            "device_count": 0, "arch_list": [],
                            "cudnn": None, "nccl": None, "bf16": False,
                            "torchaudio": None, "torchaudio_ok": False,
                            "torchaudio_pin": None,
                            "torchvision": None, "error": ""}
    try:
        import torch
    except Exception as exc:                     # noqa: BLE001
        info["error"] = str(exc).splitlines()[0]
        return info
    info["ok"] = True
    info["version"] = torch.__version__
    cuda_build = getattr(torch.version, "cuda", None)
    hip = getattr(torch.version, "hip", None)
    if cuda_build:
        info["variant"], info["cuda_build"] = f"CUDA {cuda_build}", cuda_build
    elif hip:
        info["variant"] = f"ROCm {hip}"
    elif getattr(torch.backends, "mps", None) and \
            torch.backends.mps.is_available():
        info["variant"] = "MPS (Apple)"
    else:
        info["variant"] = "CPU-only"
    try:
        info["cuda_available"] = torch.cuda.is_available()
        if info["cuda_available"]:
            info["device_count"] = torch.cuda.device_count()
            info["arch_list"] = list(torch.cuda.get_arch_list())
            if torch.backends.cudnn.is_available():
                info["cudnn"] = torch.backends.cudnn.version()
            if hasattr(torch.cuda, "nccl"):
                try:
                    info["nccl"] = ".".join(map(str, torch.cuda.nccl.version()))
                except Exception:                # noqa: BLE001
                    pass
            try:
                info["bf16"] = bool(torch.cuda.is_bf16_supported())
            except Exception:                    # noqa: BLE001
                pass
    except Exception as exc:                     # noqa: BLE001
        info["error"] = str(exc).splitlines()[0]
    try:
        import torchaudio
        info["torchaudio"] = torchaudio.__version__
        info["torchaudio_ok"] = True
    except Exception as exc:                     # noqa: BLE001
        info["torchaudio"] = None
        info["error"] = info["error"] or str(exc).splitlines()[0]
    info["torchaudio_pin"] = _metadata_torch_pin("torchaudio")
    try:
        import importlib.metadata as md
        info["torchvision"] = md.version("torchvision")
    except Exception:                            # noqa: BLE001
        info["torchvision"] = None
    return info


def _metadata_torch_pin(dist: str) -> Optional[str]:
    try:
        import importlib.metadata as md
        for req in md.requires(dist) or []:
            m = re.match(r"torch\s*==\s*([\w.+]+)", req)
            if m:
                return m.group(1)
    except Exception:                            # noqa: BLE001
        pass
    return None


def detect_gpus() -> Dict[str, Any]:
    """NVIDIA driver + GPU inventory via nvidia-smi (no extra deps)."""
    info: Dict[str, Any] = {"present": False, "driver": None,
                            "driver_cuda_max": None, "gpus": [], "error": "",
                            "processes": []}
    if not shutil.which("nvidia-smi"):
        info["error"] = "nvidia-smi not found"
        return info
    rc, head = _run(["nvidia-smi"])
    if rc != 0:
        info["error"] = f"nvidia-smi failed: {head.strip()[:200]}"
        return info
    m = re.search(r"Driver Version:\s*([\d.]+)", head)
    if m:
        info["driver"] = m.group(1)
    m = re.search(r"CUDA Version:\s*([\d.]+)", head)
    if m:
        info["driver_cuda_max"] = m.group(1)
    fields = ("name,memory.total,memory.free,compute_cap,persistence_mode,"
              "utilization.gpu")
    rc, out = _run(["nvidia-smi", f"--query-gpu={fields}",
                    "--format=csv,noheader,nounits"])
    if rc == 0:
        for line in out.strip().splitlines():
            parts = [p.strip() for p in line.split(",")]
            if len(parts) >= 6:
                info["gpus"].append({
                    "name": parts[0], "mem_total_mib": _to_int(parts[1]),
                    "mem_free_mib": _to_int(parts[2]),
                    "compute_cap": parts[3],
                    "persistence": parts[4], "util_pct": _to_int(parts[5])})
    info["present"] = bool(info["gpus"])
    rc, out = _run(["nvidia-smi", "--query-compute-apps=pid,process_name,"
                    "used_memory", "--format=csv,noheader,nounits"])
    info["processes"] = ([l.strip() for l in out.strip().splitlines()]
                         if rc == 0 and out.strip() else [])
    return info


def _to_int(s: str) -> Optional[int]:
    try:
        return int(float(s))
    except ValueError:
        return None


# =========================================================================== #
#  Check groups
# =========================================================================== #
def python_checks() -> List[CheckResult]:
    S = "python & package"
    out = []
    py = platform.python_version()
    py_ok = (3, 9) <= sys.version_info[:2] <= (3, 14)
    out.append(CheckResult(S, "python version", PASS if py_ok else FAIL,
                           found=py, expected=">=3.9,<=3.14",
                           remediation="" if py_ok else
                           "Install a supported Python (3.9-3.14) and "
                           "recreate the environment."))
    env = detect_python_env()
    try:
        import altatts
        ver = altatts.__version__
        pkg_dir = os.path.dirname(altatts.__file__)
        editable = not pkg_dir.rstrip("/").endswith(
            os.path.join("site-packages", "altatts"))
        mode = "editable/source" if editable else "wheel"
        out.append(CheckResult(S, "altatts install", PASS,
                               found=f"v{ver} ({mode}) at {pkg_dir}"))
    except Exception as exc:                     # noqa: BLE001
        out.append(CheckResult(S, "altatts install", FAIL, found=str(exc),
                               remediation="pip install altatts (or pip "
                               "install -e . from the repo)"))
    kind_status = PASS if env["kind"] != "system" else WARN
    out.append(CheckResult(
        S, "python environment", kind_status,
        found=f"{env['kind']} ({env['prefix']})",
        expected="venv or conda env",
        remediation="" if kind_status == PASS else
        "Create a venv (python -m venv .venv) -- `altatts doctor --fix` "
        "refuses to modify system Python."))
    out.append(CheckResult(S, "package manager",
                           PASS if env["managers"] else FAIL,
                           found=", ".join(env["managers"]) or "none",
                           remediation="" if env["managers"] else
                           "Install pip: python -m ensurepip --upgrade"))
    out.append(CheckResult(S, "checkpoint formats supported", INFO,
                           found="folder v1 (ALTATTS 0.1 VITS), folder v2 "
                                 "(ALTATTS 2: style encoder + MeanFlow)"))
    return out


def pytorch_checks(t: Dict[str, Any], g: Dict[str, Any]) -> List[CheckResult]:
    S = "pytorch"
    out = []
    if not t["ok"]:
        cu = _cu_tag(g.get("driver_cuda_max")) or "cu126"
        out.append(CheckResult(
            S, "torch installed", FAIL, found=f"absent ({t['error']})",
            expected="torch>=2.3",
            remediation=f"pip install torch torchaudio --index-url "
                        f"https://download.pytorch.org/whl/{cu} (or: "
                        f"altatts doctor --fix)"))
        return out
    out.append(CheckResult(S, "torch installed", PASS,
                           found=f"{t['version']} ({t['variant']})"))
    ta = t["torchaudio"]
    if not t["torchaudio_ok"]:
        out.append(CheckResult(
            S, "torchaudio", FAIL,
            found="absent or import-broken",
            expected="matched with torch",
            remediation="Reinstall the matched pair: pip install torch "
                        "torchaudio --index-url <same index as torch> "
                        "(or: altatts doctor --fix)"))
    else:
        pin = t["torchaudio_pin"]
        torch_plain = (t["version"] or "").split("+")[0]
        if pin and pin.split("+")[0] != torch_plain:
            out.append(CheckResult(
                S, "torch/torchaudio match", FAIL,
                found=f"torchaudio {ta} built for torch {pin}, installed "
                      f"torch is {t['version']}",
                expected="matched versions",
                remediation="Reinstall as a matched set: pip install "
                            "--force-reinstall torch torchaudio --index-url "
                            "<your torch index> (never reinstall torch "
                            "alone). Or run: altatts doctor --fix"))
        else:
            out.append(CheckResult(S, "torch/torchaudio match", PASS,
                                   found=f"torch {t['version']} + "
                                         f"torchaudio {ta}"))
    tl = _local_tag(t["version"]); al = _local_tag(ta)
    if tl and al and tl != al:
        out.append(CheckResult(
            S, "build tags", WARN,
            found=f"torch +{tl} vs torchaudio +{al}",
            expected="same +cuXXX tag",
            remediation="Reinstall both from the same index URL."))
    if t["cudnn"]:
        out.append(CheckResult(S, "cuDNN", PASS, found=str(t["cudnn"])))
    if t["nccl"]:
        out.append(CheckResult(S, "NCCL", PASS, found=t["nccl"]))
    if t["cuda_available"]:
        out.append(CheckResult(S, "bf16 autocast", INFO,
                               found="supported (used for AMP)" if t["bf16"]
                               else "not supported (fp16 + GradScaler)"))
    if t["cuda_build"] and not t["cuda_available"]:
        if g["present"]:
            out.append(CheckResult(
                S, "torch.cuda.is_available", FAIL,
                found="False (CUDA-build torch, GPUs present)",
                expected="True",
                remediation="Driver/runtime mismatch -- see the compatibility "
                            "section; usually fixed by installing the torch "
                            "build matching the driver: altatts doctor --fix"))
        else:
            out.append(CheckResult(
                S, "torch.cuda.is_available", INFO,
                found="False (no NVIDIA GPU detected -- CPU mode)"))
    elif t["cuda_available"]:
        out.append(CheckResult(S, "torch.cuda.is_available", PASS,
                               found=f"True ({t['device_count']} GPU(s))"))
    return out


def _cu_tag(cuda_version: Optional[str]) -> Optional[str]:
    if not cuda_version:
        return None
    parts = cuda_version.split(".")
    if len(parts) < 2:
        return None
    return f"cu{parts[0]}{parts[1]}"


def _local_tag(version: Optional[str]) -> str:
    if version and "+" in version:
        return version.split("+", 1)[1]
    return ""


def gpu_checks(g: Dict[str, Any]) -> List[CheckResult]:
    S = "nvidia driver & gpus"
    out = []
    if not g["present"]:
        out.append(CheckResult(S, "nvidia gpus", INFO,
                               found=f"none detected ({g['error']})"))
        return out
    out.append(CheckResult(S, "driver", PASS,
                           found=f"{g['driver']} (max CUDA "
                                 f"{g['driver_cuda_max']})"))
    for i, gpu in enumerate(g["gpus"]):
        free, total = gpu["mem_free_mib"], gpu["mem_total_mib"]
        mem = (f"{free}/{total} MiB free" if free is not None
               and total is not None else "unified/shared memory")
        out.append(CheckResult(
            S, f"gpu{i}: {gpu['name']}", PASS,
            found=f"cc {gpu['compute_cap']}, {mem}, "
                  f"util {gpu['util_pct']}%"))
        if gpu["util_pct"] and gpu["util_pct"] > 20:
            out.append(CheckResult(
                S, f"gpu{i} busy", WARN,
                found=f"utilization {gpu['util_pct']}%",
                expected="idle before starting a run",
                remediation="Another job is using this GPU -- check "
                            "`nvidia-smi` processes before training."))
    if g["processes"]:
        out.append(CheckResult(S, "gpu processes", INFO,
                               found="; ".join(g["processes"][:4])))
    return out


def multigpu_checks(t: Dict[str, Any], g: Dict[str, Any]
                    ) -> List[CheckResult]:
    S = "multi-gpu readiness"
    out = []
    n = t.get("device_count", 0)
    if not (t["ok"] and t["cuda_available"] and n >= 1):
        return out
    out.append(CheckResult(S, "NCCL", PASS if t["nccl"] else WARN,
                           found=t["nccl"] or "not reported",
                           remediation="" if t["nccl"] else
                           "torch reports no NCCL -- multi-GPU (DDP) "
                           "training may fall back to gloo (slow). "
                           "Install a CUDA torch build."))
    if n >= 2:
        try:
            import torch
            pairs_no_p2p = [(i, j) for i in range(n) for j in range(n)
                            if i < j and
                            not torch.cuda.can_device_access_peer(i, j)]
            if pairs_no_p2p:
                out.append(CheckResult(
                    S, "peer-to-peer access", WARN,
                    found=f"no P2P between GPU pairs {pairs_no_p2p}",
                    expected="P2P on all pairs",
                    remediation="Cross-socket/PCIe-only pairs halve scaling "
                                "efficiency; check `nvidia-smi topo -m` and "
                                "prefer NVLink-connected pairs via "
                                "CUDA_VISIBLE_DEVICES."))
            else:
                out.append(CheckResult(S, "peer-to-peer access", PASS,
                                       found="all pairs"))
        except Exception as exc:                 # noqa: BLE001
            out.append(CheckResult(S, "peer-to-peer access", WARN,
                                   found=f"probe failed: {exc}",
                                   remediation="Check `nvidia-smi topo -m` "
                                               "manually."))
        rc, topo = _run(["nvidia-smi", "topo", "-m"])
        if rc == 0 and topo.strip():
            link = "NVLink" if "NV" in topo else ("PCIe" if "PIX" in topo
                                                  or "PHB" in topo else "?")
            out.append(CheckResult(S, "gpu topology", INFO, found=link))
    ib = os.path.isdir("/sys/class/infiniband") and \
        os.listdir("/sys/class/infiniband")
    out.append(CheckResult(S, "infiniband/rdma", INFO,
                           found=", ".join(ib) if ib else "none"))
    envs = {k: os.environ.get(k) for k in
            ("NCCL_SOCKET_IFNAME", "NCCL_IB_HCA", "NCCL_P2P_DISABLE",
             "CUDA_VISIBLE_DEVICES") if os.environ.get(k) is not None}
    out.append(CheckResult(S, "relevant env vars", INFO,
                           found=json.dumps(envs) if envs else "none set"))
    return out


def system_checks(planned_workers: int = 8,
                  data_dir: Optional[str] = None,
                  out_dir: Optional[str] = None) -> List[CheckResult]:
    S = "system"
    out = []
    if os.path.isdir("/dev/shm"):
        shm = shutil.disk_usage("/dev/shm").total
        gib = shm / 2**30
        status = PASS if gib >= 1.0 else FAIL
        out.append(CheckResult(
            S, "/dev/shm size", status, found=f"{gib:.1f} GiB",
            expected=">= 1 GiB",
            remediation="" if status == PASS else
            "DataLoader workers will die with opaque bus errors. In "
            "Docker, restart with --shm-size=8g (or --ipc=host)."))
    try:
        import resource
        soft, _hard = resource.getrlimit(resource.RLIMIT_NOFILE)
        need = max(4096, planned_workers * 256)
        status = PASS if soft >= need else WARN
        out.append(CheckResult(
            S, "open-files limit (ulimit -n)", status,
            found=str(soft), expected=f">= {need} for {planned_workers} "
                                      f"workers",
            remediation="" if status == PASS else
            f"Raise it: ulimit -n {need} (or set LimitNOFILE in systemd/"
            f"Docker)."))
    except Exception:                            # noqa: BLE001
        pass
    cores = os.cpu_count() or 1
    omp = os.environ.get("OMP_NUM_THREADS")
    if omp and omp.isdigit() and int(omp) * max(1, planned_workers) > cores:
        out.append(CheckResult(
            S, "thread oversubscription", WARN,
            found=f"OMP_NUM_THREADS={omp} x {planned_workers} workers "
                  f"> {cores} cores",
            expected="threads x workers <= cores",
            remediation="Set OMP_NUM_THREADS=1 for DataLoader-heavy "
                        "training."))
    else:
        out.append(CheckResult(S, "cpu cores", INFO,
                               found=f"{cores} (OMP_NUM_THREADS="
                                     f"{omp or 'unset'})"))
    try:
        with open("/proc/meminfo") as fh:
            mem = {l.split(":")[0]: int(l.split()[1]) for l in fh
                   if ":" in l and l.split()[1].isdigit()}
        tot = mem.get("MemTotal", 0) / 2**20
        avail = mem.get("MemAvailable", 0) / 2**20
        status = PASS if avail >= 4 else WARN
        out.append(CheckResult(
            S, "system ram", status,
            found=f"{avail:.0f} GiB free of {tot:.0f} GiB",
            expected=">= 4 GiB free",
            remediation="" if status == PASS else
            "Free memory before training (close other jobs)."))
    except OSError:
        pass
    for label, d in (("output dir", out_dir or os.getcwd()),
                     ("cache dir", os.path.expanduser("~/.cache"))):
        try:
            free = shutil.disk_usage(d).free / 2**30
            status = PASS if free >= 10 else WARN
            out.append(CheckResult(
                S, f"disk free ({label})", status,
                found=f"{free:.0f} GiB at {d}", expected=">= 10 GiB",
                remediation="" if status == PASS else
                f"Free disk space at {d} -- checkpoints (~1 GB each) will fill it."))
        except OSError:
            pass
    if data_dir and os.path.isdir(data_dir):
        mbps = _read_throughput(data_dir)
        if mbps is not None:
            status = PASS if mbps >= 50 else WARN
            out.append(CheckResult(
                S, "data volume read speed", status,
                found=f"{mbps:.0f} MB/s at {data_dir}", expected=">= 50 MB/s",
                remediation="" if status == PASS else
                "This volume may starve the GPUs; convert the corpus to FLAC "
                "(altatts-prepare-data --convert-audio flac) on local NVMe."))
    return out


def _read_throughput(data_dir: str, budget_bytes: int = 32 * 2**20
                     ) -> Optional[float]:
    import time
    read = 0
    t0 = time.time()
    try:
        for root, _dirs, files in os.walk(data_dir):
            for f in files:
                p = os.path.join(root, f)
                try:
                    with open(p, "rb") as fh:
                        while read < budget_bytes:
                            chunk = fh.read(2**20)
                            if not chunk:
                                break
                            read += len(chunk)
                except OSError:
                    continue
                if read >= budget_bytes or time.time() - t0 > 2.0:
                    raise StopIteration
    except StopIteration:
        pass
    except OSError:
        return None
    dt = time.time() - t0
    if read == 0 or dt <= 0:
        return None
    return read / 2**20 / dt


def audio_checks() -> List[CheckResult]:
    S = "audio & data deps"
    out = []
    try:
        import soundfile as sf
        import wave, struct, math
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as fh:
            path = fh.name
        with wave.open(path, "w") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
            w.writeframes(b"".join(
                struct.pack("<h", int(8000 * math.sin(i / 10.0)))
                for i in range(1600)))
        data, sr = sf.read(path, dtype="float32")
        os.unlink(path)
        ok = sr == 16000 and len(data) == 1600
        out.append(CheckResult(
            S, "soundfile decode", PASS if ok else FAIL,
            found=f"soundfile {sf.__version__}, decoded {len(data)} samples",
            remediation="" if ok else "pip install --force-reinstall soundfile"))
    except Exception as exc:                     # noqa: BLE001
        out.append(CheckResult(
            S, "soundfile decode", FAIL, found=str(exc)[:160],
            expected="WAV/FLAC/OGG decoding + writing",
            remediation="pip install soundfile (needs libsndfile; on "
                        "Debian/Ubuntu: apt install libsndfile1) -- or "
                        "altatts doctor --fix"))
    try:
        import av
        out.append(CheckResult(S, "pyav (mp3/opus/m4a decode)", PASS,
                               found=f"av {av.__version__}"))
    except Exception as exc:                     # noqa: BLE001
        ff = shutil.which("ffmpeg")
        out.append(CheckResult(
            S, "pyav (mp3/opus/m4a decode)", WARN if ff else FAIL,
            found=str(exc)[:120],
            expected="importable (or system ffmpeg)",
            remediation="pip install av -- needed to train on MP3/WebM/Opus "
                        "corpora (Common Voice); without it decoding falls "
                        "back to torchaudio/ffmpeg. altatts doctor --fix "
                        "installs it."))
    ff = shutil.which("ffmpeg")
    out.append(CheckResult(S, "system ffmpeg", INFO,
                           found=ff or "absent (optional decode fallback)"))
    try:
        import numba  # noqa: F401
        out.append(CheckResult(S, "numba (MAS speed-up)", INFO,
                               found=f"{numba.__version__} -- alignment JIT on"))
    except Exception:                            # noqa: BLE001
        out.append(CheckResult(S, "numba (MAS speed-up)", INFO,
                               found="absent (optional: pip install numba "
                                     "speeds up training alignment)"))
    try:
        import altasr
        out.append(CheckResult(S, "altasr (WER evaluation)", INFO,
                               found=f"{altasr.__version__}"))
    except Exception:                            # noqa: BLE001
        out.append(CheckResult(S, "altasr (WER evaluation)", INFO,
                               found="absent (optional: pip install altatts[asr] "
                                     "for round-trip WER / transcript checks)"))
    try:
        import onnxruntime as ort
        out.append(CheckResult(S, "onnxruntime", INFO,
                               found=f"{ort.__version__} providers: "
                                     f"{', '.join(ort.get_available_providers())}"))
    except Exception:                            # noqa: BLE001
        pass
    return out


def smoke_checks(t: Dict[str, Any]) -> List[CheckResult]:
    """Allocate + matmul on every device: real usability, not capability."""
    S = "live smoke"
    out = []
    if not t["ok"]:
        return out
    import torch
    try:
        x = torch.randn(64, 64)
        y = x @ x
        ok = torch.isfinite(y).all().item()
        out.append(CheckResult(S, "cpu matmul", PASS if ok else FAIL,
                               found="finite result" if ok else "non-finite",
                               remediation="" if ok else
                               "Torch CPU build is broken -- reinstall torch."))
    except Exception as exc:                     # noqa: BLE001
        out.append(CheckResult(S, "cpu matmul", FAIL, found=str(exc)[:160],
                               remediation="Reinstall torch: altatts doctor --fix"))
    try:
        from ..utils import cpu_grouped_conv_ok
        ok = cpu_grouped_conv_ok()
        out.append(CheckResult(
            S, "cpu grouped conv1d correctness", PASS if ok else WARN,
            found="matches reference" if ok else
                  "WRONG results (oneDNN bug: groups=4, stride=4 Conv1d) -- ALTATTS "
                  "disables oneDNN automatically for CPU runs",
            expected="exact",
            remediation="" if ok else
            "Nothing to do for ALTATTS (automatic workaround, slightly slower "
            "CPU training). For other code: ALTATTS_NO_MKLDNN=1 / "
            "torch.backends.mkldnn.enabled=False, or install a newer torch."))
    except Exception as exc:                     # noqa: BLE001
        out.append(CheckResult(S, "cpu grouped conv1d correctness", WARN, found=str(exc)[:100],
                               remediation="Could not run the conv self-test."))
    try:
        # forward-mode AD is what the MeanFlow prior trains with
        f = lambda z: torch.tanh(z) * 2          # noqa: E731
        _, tangent = torch.func.jvp(f, (torch.randn(4),), (torch.ones(4),))
        out.append(CheckResult(S, "forward-mode AD (torch.func.jvp)", PASS,
                               found="available"))
    except Exception as exc:                     # noqa: BLE001
        out.append(CheckResult(S, "forward-mode AD (torch.func.jvp)", WARN,
                               found=str(exc)[:120],
                               expected="torch >= 2.0",
                               remediation="MeanFlow training will use finite "
                                           "differences (prior.jvp_mode=fd); "
                                           "upgrade torch for exact JVPs."))
    if t["cuda_available"]:
        for i in range(t["device_count"]):
            try:
                x = torch.randn(256, 256, device=f"cuda:{i}")
                y = (x @ x).sum().item()
                ok = y == y
                out.append(CheckResult(
                    S, f"gpu{i} matmul", PASS if ok else FAIL,
                    found="finite result" if ok else "NaN",
                    remediation="" if ok else
                    f"GPU {i} computes garbage -- check ECC errors "
                    f"(nvidia-smi -q -d ECC) and thermals."))
            except Exception as exc:             # noqa: BLE001
                out.append(CheckResult(
                    S, f"gpu{i} matmul", FAIL, found=str(exc)[:160],
                    expected="allocation + matmul succeeds",
                    remediation="The device is unusable from this torch "
                                "build -- see the compatibility section; "
                                "altatts doctor --fix"))
    return out


def checkpoint_smoke(checkpoint: str) -> List[CheckResult]:
    """--checkpoint X: load it and synthesize a short sentence on CPU."""
    S = "checkpoint smoke"
    try:
        import time
        from ..inference.synthesizer import Synthesizer
        tts = Synthesizer.from_pretrained(checkpoint, device="cpu")
        caps = tts.capabilities()
        voices = list(tts.voices())
        voice = voices[0] if voices else "female"
        t0 = time.time()
        wav, sr = tts.tts("muraho neza.", voice=voice)
        dt = time.time() - t0
        return [CheckResult(
            S, "load + synthesize", PASS,
            found=f"v{caps['model_version']} model, {len(voices)} voice(s), "
                  f"{len(wav) / sr:.2f}s audio in {dt:.2f}s on CPU "
                  f"(RTF {dt / max(1e-6, len(wav) / sr):.2f}); cloning="
                  f"{caps['voice_cloning']}, emotions={bool(caps['emotions'])}")]
    except Exception as exc:                     # noqa: BLE001
        return [CheckResult(
            S, "load + synthesize", FAIL, found=str(exc)[:200],
            expected="checkpoint loads and speaks",
            remediation="Verify the folder contains config.json, "
                        "tokenizer.json, speakers.json and model.pt, and "
                        "that this altatts version supports its "
                        "model.version.")]
