"""
``altatts doctor --fix`` -- repair what is safe to repair, following the
same 10-step protocol as ALTASR:

 1. refuse if a training job is running on the GPUs (absent --force);
 2. refuse to touch system Python (absent --force), name the env;
 3. back up current torch/torchaudio/torchvision versions to
    ``~/.altatts/env_backup/<timestamp>.json``;
 4. CROSS-CHECK which torch build this machine can run (driver ceiling,
    GPU compute-capability floor, Python/arch wheels actually published --
    see ``wheels.py``), print the plan (exact pins, index URL, size) and
    confirm (skipped with --yes);
 5. check network reachability of the index BEFORE uninstalling anything;
 6. uninstall the triple together -- never torch alone;
 7. install the matched triple from the right index with the env's own
    package manager;
 8. re-verify in the target interpreter: import, CPU and GPU matmul,
    ``torch.cuda.is_available()``, and the compatibility verdict again;
 9. on verification failure, ROLL BACK automatically to the recorded
    versions and report both the original problem and the failed fix;
10. print a before/after diff.

Will fix: mismatched torch/torchaudio triple, CPU-only torch on a CUDA
machine, torch CUDA build incompatible with the driver, torch build lacking
the GPU's capability, missing pure-Python runtime deps (soundfile, av).

Will NOT fix (report only): NVIDIA driver changes (root + reboot), /dev/shm,
ulimits, anything needing root absent --allow-root-actions, hardware faults.

``--dry-run`` prints the plan and exits without changes -- use it first.
The executor is injected so the whole protocol (including rollback) is
unit-testable without touching a real environment.
"""
from __future__ import annotations

import datetime as _dt
import json
import os
import re
import sys
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Sequence, Tuple

from .checks import (FAIL, CheckResult, detect_gpus, detect_python_env,
                     _run)
from .wheels import WheelChoice, cu_tag, resolve_wheel

Resolver = Callable[..., WheelChoice]

Executor = Callable[[List[str]], Tuple[int, str]]

#: pip downloads of CUDA wheels take minutes: a dedicated runner with a long
#: timeout that streams pip's own output (the 5 s probe runner killed the
#: install and the rollback on a real server -- 2.0.0 bug).
PIP_TIMEOUT_S = 3600.0


def _run_long(cmd: List[str], timeout: float = PIP_TIMEOUT_S) -> Tuple[int, str]:
    """Run a long command, echo its output live, never raise."""
    import subprocess
    import time as _time
    lines: List[str] = []
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, bufsize=1)
        deadline = _time.time() + timeout
        assert proc.stdout is not None
        for line in proc.stdout:
            lines.append(line)
            print("      " + line.rstrip(), flush=True)
            if _time.time() > deadline:
                proc.kill()
                lines.append(f"\n[fix] killed after {timeout:.0f}s\n")
                break
        rc = proc.wait()
        return rc, "".join(lines)[-4000:]
    except (OSError, subprocess.SubprocessError) as exc:
        return -1, str(exc)

#: pure-Python runtime deps the fixer may install when their check FAILs
_PURE_PY = {"pyav (mp3/opus/m4a decode)": "av",
            "soundfile decode": "soundfile"}

_TRIPLE = ("torch", "torchaudio", "torchvision")


@dataclass
class FixAction:
    title: str
    commands: List[List[str]]
    note: str = ""


@dataclass
class FixPlan:
    actions: List[FixAction] = field(default_factory=list)
    index_url: Optional[str] = None
    reinstall_triple: bool = False
    crosscheck: str = ""                   # the wheel cross-check, verbatim
    choice: Optional[WheelChoice] = None
    blockers: List[str] = field(default_factory=list)

    def describe(self) -> str:
        lines: List[str] = []
        if self.crosscheck:
            lines += [self.crosscheck, ""]
        for b in self.blockers:
            lines.append(f"CANNOT FIX: {b}")
        if not self.actions:
            lines.append("nothing to fix -- no repairable FAILs found" if not self.blockers
                         else "no automatic repair possible (see above)")
            return "\n".join(lines)
        lines.append("FIX PLAN")
        for i, a in enumerate(self.actions, 1):
            lines.append(f"  {i}. {a.title}")
            for cmd in a.commands:
                lines.append(f"       $ {' '.join(cmd)}")
            if a.note:
                lines.append(f"       note: {a.note}")
        if self.reinstall_triple:
            lines.append("  download size: roughly 2-4 GB (torch CUDA "
                         "wheels are large)")
        return "\n".join(lines)


_cu_tag = cu_tag                         # backwards-compatible alias


def _installed_versions() -> Dict[str, str]:
    import importlib.metadata as md
    out = {}
    for pkg in _TRIPLE:
        try:
            out[pkg] = md.version(pkg)
        except md.PackageNotFoundError:
            pass
    return out


def build_fix_plan(results: Sequence[CheckResult],
                   gpu_info: Optional[Dict[str, Any]] = None,
                   python_exe: str = sys.executable,
                   resolver: Optional[Resolver] = None,
                   installed: Optional[Dict[str, str]] = None,
                   index_url: Optional[str] = None) -> FixPlan:
    """Translate FAILed checks into concrete repair actions.

    When the torch triple must be reinstalled, ``resolver`` (default:
    :func:`altatts.env.wheels.resolve_wheel`, which talks to the PyTorch
    index) cross-checks driver, GPU and published wheels and returns the
    exact build to install.  Offline, the plan falls back to the index
    matching the driver's CUDA version without pins."""
    plan = FixPlan()
    fails = {(r.section, r.name): r for r in results if r.status == FAIL}

    gpu_info = gpu_info if gpu_info is not None else {}
    cu = cu_tag(gpu_info.get("driver_cuda_max"))
    index = (f"https://download.pytorch.org/whl/{cu}" if cu else None)
    plan.index_url = index

    triple_reasons = []
    for key, reason in (
            (("pytorch", "torch installed"), "torch absent"),
            (("pytorch", "torch/torchaudio match"), "mismatched triple"),
            (("pytorch", "torchaudio"), "torchaudio broken"),
            (("compatibility verdict", "torch build vs hardware"),
             "CPU-only torch on a CUDA machine"),
            (("compatibility verdict", "driver minimum"),
             "torch CUDA build too new for the driver"),
    ):
        if key in fails:
            triple_reasons.append(reason)
    cap_fails = [r for (s, n), r in fails.items()
                 if s == "compatibility verdict" and "capability" in n]
    if cap_fails:
        triple_reasons.append("torch build lacks the GPU's compute capability")

    if triple_reasons:
        installed = installed if installed is not None else _installed_versions()
        with_tv = "torchvision" in installed
        pins = ["torch", "torchaudio"] + (["torchvision"] if with_tv else [])
        note = ("uninstalling the packages TOGETHER -- a torchaudio built "
                "against a removed torch import-fails confusingly")
        choice: Optional[WheelChoice] = None
        try:
            resolve = resolver or resolve_wheel
            choice = resolve(driver_cuda_max=gpu_info.get("driver_cuda_max"),
                             gpu_caps=[g.get("compute_cap") for g in gpu_info.get("gpus", [])
                                       if g.get("compute_cap")],
                             override=index_url)
        except Exception as exc:                     # noqa: BLE001
            plan.crosscheck = (f"CROSS-CHECK unavailable ({str(exc).splitlines()[0][:100]}); "
                               f"falling back to the index matching the driver's CUDA "
                               f"({gpu_info.get('driver_cuda_max') or 'none -> CPU build'})")
        if choice is not None:
            plan.choice = choice
            plan.crosscheck = choice.describe()
            if choice.ok:
                index = choice.index_url
                pins = choice.pins(with_torchvision=with_tv)
            else:
                plan.blockers.append(
                    "no torch build fits this machine (see the cross-check above). "
                    "Check the network, or pass --index-url cuXYZ|cpu|URL to choose one.")
        elif index is None:
            index = "https://download.pytorch.org/whl/cpu"
            note += "; no NVIDIA driver detected, installing the CPU build"
        plan.index_url = index
        if not plan.blockers:
            plan.reinstall_triple = True
            pip = [python_exe, "-m", "pip"]
            install = pip + ["install", "--force-reinstall", *pins, "--index-url", index]
            plan.actions.append(FixAction(
                title="Reinstall the torch triple as a matched set ("
                      + "; ".join(triple_reasons) + ")",
                commands=[pip + ["uninstall", "-y", *_TRIPLE], install],
                note=note))

    for (_s, name), r in fails.items():
        pkg = _PURE_PY.get(name)
        if pkg:
            plan.actions.append(FixAction(
                title=f"Install missing dependency {pkg!r}",
                commands=[[python_exe, "-m", "pip", "install", pkg]]))
    return plan


def _training_job_running(gpu_info: Dict[str, Any]) -> Optional[str]:
    """A process that looks like an ACTIVE training job: an altatts/altasr/
    torchrun process, or any process on a GPU that is busy (> 20 % util) or
    holding > 8 GB. Idle notebooks and small servers do not block a repair
    (they are listed as a note instead)."""
    busy = any((g.get("util_pct") or 0) > 20 for g in gpu_info.get("gpus", []))
    for proc in gpu_info.get("processes", []):
        low = proc.lower()
        if any(k in low for k in ("altatts", "altasr", "torchrun", "torch.distributed")):
            return proc
        parts = [p.strip() for p in proc.split(",")]
        mem = 0
        try:
            mem = int(float(parts[-1]))             # used_memory in MiB
        except (ValueError, IndexError):
            pass
        if busy or mem > 8192:
            return proc
    return None


def _backup_versions(backup_dir: Optional[str] = None) -> Tuple[str, Dict]:
    import importlib.metadata as md
    versions = {}
    for pkg in _TRIPLE:
        try:
            versions[pkg] = md.version(pkg)
        except md.PackageNotFoundError:
            pass
    backup_dir = backup_dir or os.path.expanduser("~/.altatts/env_backup")
    os.makedirs(backup_dir, exist_ok=True)
    stamp = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    path = os.path.join(backup_dir, f"{stamp}.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"timestamp": stamp, "python": sys.executable,
                   "versions": versions}, fh, indent=2)
    return path, versions


def _index_reachable(index_url: Optional[str]) -> Tuple[bool, str]:
    url = index_url or "https://pypi.org/simple/"
    import urllib.request
    try:
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=8):
            pass
        return True, url
    except Exception as exc:                     # noqa: BLE001
        return False, f"{url}: {exc}"


_SMOKE_CODE = """
import json, torch
x = torch.randn(32, 32); y = (x @ x).sum(); assert torch.isfinite(y), "cpu matmul non-finite"
info = {"version": torch.__version__, "cuda_build": getattr(torch.version, "cuda", None),
        "cuda_available": bool(torch.cuda.is_available()), "arch_list": [], "device_count": 0,
        "gpu_ok": None}
if info["cuda_available"]:
    info["device_count"] = torch.cuda.device_count()
    info["arch_list"] = list(torch.cuda.get_arch_list())
    z = torch.randn(32, 32, device="cuda"); info["gpu_ok"] = bool(torch.isfinite((z @ z).sum()))
try:
    import torchaudio; info["torchaudio"] = torchaudio.__version__
except Exception as exc:
    info["torchaudio_error"] = str(exc).splitlines()[0]
print("ALTATTS_SMOKE_JSON " + json.dumps(info))
"""


def _post_fix_verify(python_exe: str, executor: Executor, expect_cuda: bool,
                     gpu_info: Optional[Dict[str, Any]] = None) -> Tuple[bool, str]:
    """Import + CPU/GPU matmul in the TARGET interpreter, then the
    compatibility verdict again on what it reports. (ok, summary)."""
    rc, out = executor([python_exe, "-c", _SMOKE_CODE])
    if rc != 0:
        return False, out.strip()[-400:]
    m = re.search(r"ALTATTS_SMOKE_JSON (\{.*\})", out)
    if not m:
        return (not expect_cuda), ("smoke passed (no details reported)" if not expect_cuda
                                   else "smoke gave no details, cannot confirm CUDA")
    info = json.loads(m.group(1))
    problems: List[str] = []
    if info.get("torchaudio_error"):
        problems.append(f"torchaudio import failed: {info['torchaudio_error']}")
    if expect_cuda:
        if not info.get("cuda_available"):
            problems.append("torch.cuda.is_available() is still False")
        elif info.get("gpu_ok") is False:
            problems.append("GPU matmul produced non-finite values")
        gpu_info = gpu_info or {}
        try:
            from .compat import load_table, verdict
            res = verdict(True, info.get("cuda_build"), bool(info.get("cuda_available")),
                          info.get("arch_list", []), gpu_info.get("driver"),
                          gpu_info.get("driver_cuda_max"),
                          [g.get("compute_cap") for g in gpu_info.get("gpus", [])
                           if g.get("compute_cap")], load_table())
            problems += [f"{r.name}: {r.found}" for r in res if r.status == FAIL
                         and "cuda runtime usable" not in r.name]
        except Exception as exc:                     # noqa: BLE001
            problems.append(f"verdict could not be re-run: {exc}")
    summary = (f"torch {info.get('version')} (CUDA build {info.get('cuda_build')}), "
               f"cuda available={info.get('cuda_available')}, "
               f"{info.get('device_count', 0)} GPU(s)"
               + (f", torchaudio {info['torchaudio']}" if info.get("torchaudio") else ""))
    if problems:
        return False, summary + "; " + "; ".join(problems)
    return True, summary


def _rollback_commands(python_exe: str, versions: Dict[str, str]
                       ) -> List[List[str]]:
    pins = [f"{p}=={v}" for p, v in versions.items()]
    if not pins:
        return []
    cmds = [[python_exe, "-m", "pip", "uninstall", "-y", *_TRIPLE]]
    install = [python_exe, "-m", "pip", "install", *pins]
    tags = {v.split("+", 1)[1] for v in versions.values() if "+" in v}
    if len(tags) == 1:
        install += ["--index-url",
                    f"https://download.pytorch.org/whl/{tags.pop()}"]
    cmds.append(install)
    return cmds


def run_fix(results: Sequence[CheckResult],
            dry_run: bool = False,
            yes: bool = False,
            force: bool = False,
            allow_root: bool = False,
            as_json: bool = False,
            executor: Optional[Executor] = None,
            gpu_info: Optional[Dict[str, Any]] = None,
            env_info: Optional[Dict[str, Any]] = None,
            backup_dir: Optional[str] = None,
            confirm: Optional[Callable[[str], bool]] = None,
            resolver: Optional[Resolver] = None,
            index_url: Optional[str] = None) -> int:
    """The full repair protocol; collaborators injectable for tests."""
    executor = executor or _run_long
    gpu_info = gpu_info if gpu_info is not None else detect_gpus()
    env_info = env_info if env_info is not None else detect_python_env()

    plan = build_fix_plan(results, gpu_info=gpu_info,
                          python_exe=env_info.get("executable", sys.executable),
                          resolver=resolver, index_url=index_url)
    print(plan.describe())
    if not plan.actions:
        return 2 if plan.blockers else 0
    if dry_run:
        print("\n--dry-run: no changes made.")
        return 0

    job = _training_job_running(gpu_info)
    if job and not force:
        print(f"REFUSING: a job appears to be running on the GPUs ({job}). "
              f"Reinstalling torch under a running job is a bad afternoon. "
              f"Stop it, or re-run with --force if it is not yours to stop "
              f"and not an ALTATTS/ALTASR run.", file=sys.stderr)
        return 2
    if gpu_info.get("processes") and not job:
        print(f"[fix] note: {len(gpu_info['processes'])} idle process(es) hold GPU memory "
              f"({'; '.join(gpu_info['processes'][:3])}); they do not use this venv's torch "
              f"unless they were started from it -- continuing.")
    if env_info.get("kind") == "system" and not force:
        print(f"REFUSING: this is the SYSTEM Python "
              f"({env_info.get('prefix')}). Create a venv/conda env, or "
              f"re-run with --force at your own risk.", file=sys.stderr)
        return 2

    backup_path, versions = _backup_versions(backup_dir)
    print(f"[fix] current versions backed up to {backup_path}: {versions}")

    ask = confirm or (lambda q: input(q).strip().lower() in ("y", "yes"))
    if not yes and not ask("Proceed with the plan above? [y/N] "):
        print("aborted -- nothing changed.")
        return 1

    if plan.reinstall_triple:
        ok, detail = _index_reachable(plan.index_url)
        if not ok:
            print(f"REFUSING: package index unreachable ({detail}). "
                  f"Fix the network first -- uninstalling now would leave "
                  f"you without a working torch.", file=sys.stderr)
            return 2

    for action in plan.actions:
        for cmd in action.commands:
            print(f"[fix] $ {' '.join(cmd)}", flush=True)
            rc, out = executor(cmd)
            if rc != 0:
                print(f"[fix] command failed (rc={rc}):\n{out[-800:]}",
                      file=sys.stderr)
                _attempt_rollback(env_info, versions, executor)
                return 2

    expect_cuda = bool(gpu_info.get("present")) and plan.reinstall_triple
    ok, detail = _post_fix_verify(env_info.get("executable", sys.executable),
                                  executor, expect_cuda, gpu_info)
    if ok:
        after = _installed_versions()
        print(f"[fix] post-fix verification PASSED: {detail}")
        print("[fix] post-fix smoke test PASSED.")
        print("[fix] before -> after:")
        for pkg in sorted(set(versions) | set(after)):
            print(f"    {pkg}: {versions.get(pkg, '-')} -> {after.get(pkg, '-')}")
        print("[fix] re-run `altatts doctor` for the full picture.")
        if plan.blockers:
            print("[fix] NOTE: the torch problem itself was NOT repaired (see CANNOT FIX "
                  "above); only the other actions ran.", file=sys.stderr)
            return 2
        return 0

    print(f"[fix] post-fix verification FAILED: {detail}", file=sys.stderr)
    _attempt_rollback(env_info, versions, executor)
    print("[fix] the fix did not work and has been rolled back. Original "
          "problem stands; please report the smoke-test output above.",
          file=sys.stderr)
    return 2


def _attempt_rollback(env_info: Dict[str, Any], versions: Dict[str, str],
                      executor: Executor) -> None:
    cmds = _rollback_commands(env_info.get("executable", sys.executable),
                              versions)
    if not cmds:
        print("[fix] nothing recorded to roll back to.", file=sys.stderr)
        return
    print("[fix] rolling back to the recorded versions ...", file=sys.stderr)
    for cmd in cmds:
        print(f"[fix] $ {' '.join(cmd)}", file=sys.stderr, flush=True)
        rc, out = executor(cmd)
        if rc != 0:
            print(f"[fix] ROLLBACK COMMAND FAILED (rc={rc}) -- restore "
                  f"manually from the backup file:\n{out[-400:]}",
                  file=sys.stderr)
            return
    print("[fix] rollback complete.", file=sys.stderr)
