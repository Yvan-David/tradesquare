"""
Which torch wheel can THIS machine actually run?  (the cross-check behind
``altatts doctor --fix``)

Three things decide it:

* the NVIDIA driver caps the CUDA version it can drive (a 570.x driver runs
  CUDA <= 12.8 builds; a cu130 wheel on it imports fine but
  ``torch.cuda.is_available()`` is False);
* the GPU's compute capability sets a floor (Blackwell sm_100 / sm_120 only
  exist in CUDA >= 12.8 builds);
* the PyTorch wheel index decides what was actually published for this
  Python version and CPU architecture (cp312 / aarch64 ...).

``resolve_wheel`` lists the candidate indexes (newest CUDA first, within
the driver's ceiling and the GPU's floor), reads each one's torch and
torchaudio listings, and picks the **newest torch the machine can run**
(ties -> newest CUDA).  Everything is pure logic over an injectable
``fetch`` so the whole decision is unit-testable offline; the data (which
tags exist, driver minimums, capability floors) lives in
``compat_table.json``.
"""
from __future__ import annotations

import html as _html
import platform
import re
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional, Sequence, Tuple

INDEX_ROOT = "https://download.pytorch.org/whl"
Fetch = Callable[[str], str]

_WHEEL_RE = re.compile(r'<a\s+href="([^"]+)"[^>]*>\s*([^<\s]+\.whl)\s*</a>', re.I)
_RELEASE_RE = re.compile(r"^\d+(\.\d+)*$")           # no .dev / rc / a / b
_MACHINES = {"amd64": "x86_64", "x64": "x86_64", "arm64": "aarch64"}


def fetch_text(url: str, timeout: float = 20.0) -> str:
    """GET a page as text (raises on any failure; callers decide)."""
    req = urllib.request.Request(url, headers={"User-Agent": "altatts-doctor"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", "replace")


def ver_tuple(version: str) -> Tuple[int, ...]:
    return tuple(int(p) for p in re.findall(r"\d+", version.split("+", 1)[0]))


def cuda_of_tag(tag: str) -> Optional[Tuple[int, int]]:
    """'cu128' -> (12, 8); 'cu118' -> (11, 8); 'cu130' -> (13, 0); 'cpu' -> None."""
    m = re.fullmatch(r"cu(\d+)(\d)", tag or "")
    return (int(m.group(1)), int(m.group(2))) if m else None


def cu_tag(cuda_version: Optional[str]) -> Optional[str]:
    """'12.8' -> 'cu128'; None -> None."""
    if not cuda_version:
        return None
    parts = str(cuda_version).split(".")
    return f"cu{parts[0]}{parts[1]}" if len(parts) >= 2 else None


def norm_machine(machine: Optional[str] = None) -> str:
    m = (machine or platform.machine() or "").lower()
    return _MACHINES.get(m, m)


def parse_index(page: str, package: str, python_tag: str, machine: str,
                local_tag: Optional[str], base_url: str = INDEX_ROOT + "/"
                ) -> Dict[str, str]:
    """``{version: wheel_url}`` for the *release* wheels of ``package`` on a
    PEP 503 index page that fit this Python tag, Linux architecture and
    ``+local_tag`` build, newest first."""
    found: Dict[str, str] = {}
    prefix = package.replace("-", "_") + "-"
    for href, name in _WHEEL_RE.findall(page):
        name = urllib.parse.unquote(_html.unescape(name))
        if not name.startswith(prefix):
            continue
        parts = name[:-4].split("-")
        if len(parts) < 5:
            continue
        version, _, local = parts[1].partition("+")
        py, plat = parts[2], "-".join(parts[4:])
        if py != python_tag or machine not in plat or "linux" not in plat:
            continue
        if not _RELEASE_RE.match(version):
            continue
        if local_tag and local != local_tag and not (local_tag == "cpu" and local == ""):
            continue                                 # old CPU wheels carry no +cpu
        url = _html.unescape(href).split("#", 1)[0]
        found.setdefault(version, urllib.parse.urljoin(base_url, url))
    return dict(sorted(found.items(), key=lambda kv: ver_tuple(kv[0]), reverse=True))


def min_cuda_for_caps(gpu_caps: Sequence[str], table: Dict) -> Optional[str]:
    """The newest CUDA floor among the GPUs' compute capabilities."""
    mapping = table.get("min_cuda_for_compute_cap", {})
    best: Optional[str] = None
    for cap in gpu_caps:
        cap = str(cap)
        need = mapping.get(cap) or mapping.get(cap.split(".")[0])
        if need and (best is None or ver_tuple(need) > ver_tuple(best)):
            best = need
    return best


def candidate_tags(driver_cuda_max: Optional[str], min_cuda: Optional[str],
                   table: Dict, max_probe: int = 4
                   ) -> Tuple[List[str], List[Tuple[str, str]]]:
    """(tags to probe, newest CUDA first; [(tag, why skipped), ...])."""
    tags = set(table.get("torch_wheel_tags", []))
    direct = cu_tag(driver_cuda_max)
    if direct:
        tags.add(direct)                              # a tag newer than the table
    if not driver_cuda_max:
        return ["cpu"], [(t, "no NVIDIA driver detected -> CPU build") for t in sorted(tags)]
    ceiling = ver_tuple(driver_cuda_max)[:2]
    floor = ver_tuple(min_cuda)[:2] if min_cuda else (0, 0)
    keep: List[str] = []
    skipped: List[Tuple[str, str]] = []
    for tag in sorted(tags, key=lambda t: cuda_of_tag(t) or (0, 0), reverse=True):
        c = cuda_of_tag(tag)
        if c is None:
            continue
        if c > ceiling:
            skipped.append((tag, f"needs a driver for CUDA {c[0]}.{c[1]}; this driver "
                                 f"supports <= {driver_cuda_max}"))
        elif c < floor:
            skipped.append((tag, f"older than CUDA {min_cuda}, the floor for this GPU's "
                                 f"compute capability"))
        else:
            keep.append(tag)
    skipped += [(t, "not probed (older than the candidates above)") for t in keep[max_probe:]]
    return keep[:max_probe], skipped


@dataclass
class Candidate:
    tag: str
    index_url: str
    torch_version: Optional[str] = None
    torchaudio_version: Optional[str] = None
    reason: str = ""          # why it was rejected
    note: str = ""            # extra information when it was usable
    chosen: bool = False

    @property
    def ok(self) -> bool:
        return bool(self.torch_version)


@dataclass
class WheelChoice:
    tag: Optional[str] = None
    index_url: Optional[str] = None
    torch_version: Optional[str] = None
    torchaudio_version: Optional[str] = None
    python_tag: str = ""
    machine: str = ""
    driver_cuda_max: Optional[str] = None
    min_cuda: Optional[str] = None
    candidates: List[Candidate] = field(default_factory=list)
    skipped: List[Tuple[str, str]] = field(default_factory=list)
    note: str = ""

    @property
    def ok(self) -> bool:
        return bool(self.tag and self.torch_version)

    def pins(self, with_torchvision: bool = False) -> List[str]:
        """pip requirement strings for the matched set."""
        if not self.ok:
            return ["torch", "torchaudio"] + (["torchvision"] if with_torchvision else [])
        local = f"+{self.tag}" if cuda_of_tag(self.tag) or self.tag == "cpu" else ""
        pins = [f"torch=={self.torch_version}{local}"]
        pins.append(f"torchaudio=={self.torchaudio_version}{local}"
                    if self.torchaudio_version else "torchaudio")
        if with_torchvision:
            pins.append("torchvision")
        return pins

    def describe(self) -> str:
        head = [f"CROSS-CHECK: driver supports CUDA <= {self.driver_cuda_max}"
                if self.driver_cuda_max else "CROSS-CHECK: no NVIDIA driver -> CPU build"]
        if self.min_cuda:
            head[0] += f"; the GPU needs CUDA >= {self.min_cuda}"
        head[0] += f"; python {self.python_tag}, linux {self.machine}"
        lines = head
        for tag, why in self.skipped:
            lines.append(f"  {tag:<7} skipped: {why}")
        for c in self.candidates:
            if c.ok:
                desc = f"torch {c.torch_version}" + (
                    f" + torchaudio {c.torchaudio_version}" if c.torchaudio_version
                    else " (torchaudio resolved by pip)")
                if c.note:
                    desc += f"  [{c.note}]"
                if c.chosen:
                    desc += "   <- chosen: newest torch this machine can run"
            else:
                desc = f"rejected: {c.reason}"
            lines.append(f"  {c.tag:<7} {desc}")
        if self.ok:
            lines.append(f"  => {' '.join(self.pins())}  from {self.index_url}")
        else:
            lines.append(f"  => no compatible torch build found" + (f": {self.note}" if self.note else ""))
        return "\n".join(lines)


def _torch_pin_of(fetch: Fetch, wheel_url: str) -> Optional[str]:
    """torchaudio's ``Requires-Dist: torch==X`` from its PEP 658 metadata
    (one small request); None when absent or unavailable."""
    try:
        meta = fetch(wheel_url + ".metadata")
    except Exception:                                # noqa: BLE001
        return None
    m = re.search(r"^Requires-Dist:\s*torch\s*==\s*([\w.]+)", meta, re.M)
    return m.group(1).split("+", 1)[0] if m else None


def resolve_wheel(driver_cuda_max: Optional[str],
                  gpu_caps: Sequence[str] = (),
                  table: Optional[Dict] = None,
                  python_version: Optional[Tuple[int, int]] = None,
                  machine: Optional[str] = None,
                  fetch: Fetch = fetch_text,
                  max_probe: int = 4,
                  override: Optional[str] = None) -> WheelChoice:
    """Pick the newest torch (+ matching torchaudio) this machine can run.

    ``override`` is a tag (``cu126``, ``cpu``) or a full index URL: only
    that index is probed. Network failures reject the candidate instead of
    raising; a completely offline machine yields ``choice.ok == False``.
    """
    if table is None:
        from .compat import load_table
        table = load_table()
    py = tuple(python_version or sys.version_info[:2])
    choice = WheelChoice(python_tag=f"cp{py[0]}{py[1]}", machine=norm_machine(machine),
                         driver_cuda_max=driver_cuda_max,
                         min_cuda=min_cuda_for_caps(gpu_caps, table))
    if override:
        if override.startswith("http"):
            url = override.rstrip("/")
            targets = [(url.rsplit("/", 1)[-1], url)]
        else:
            targets = [(override, f"{INDEX_ROOT}/{override}")]
        choice.note = f"index chosen by --index-url {override}"
    else:
        tags, choice.skipped = candidate_tags(driver_cuda_max, choice.min_cuda, table, max_probe)
        targets = [(t, f"{INDEX_ROOT}/{t}") for t in tags]

    for tag, index_url in targets:
        cand = Candidate(tag=tag, index_url=index_url)
        choice.candidates.append(cand)
        local = tag if (cuda_of_tag(tag) or tag == "cpu") else None
        try:
            page = fetch(f"{index_url}/torch/")
        except Exception as exc:                     # noqa: BLE001
            cand.reason = f"index unreachable ({str(exc).splitlines()[0][:80]})"
            continue
        torch_wheels = parse_index(page, "torch", choice.python_tag, choice.machine, local,
                                   base_url=f"{index_url}/torch/")
        if not torch_wheels:
            cand.reason = f"no torch wheel for {choice.python_tag} linux {choice.machine}"
            continue
        cand.torch_version = next(iter(torch_wheels))
        try:
            ta = parse_index(fetch(f"{index_url}/torchaudio/"), "torchaudio",
                             choice.python_tag, choice.machine, local,
                             base_url=f"{index_url}/torchaudio/")
        except Exception:                            # noqa: BLE001
            ta = {}
        if ta:
            ta_version, ta_url = next(iter(ta.items()))
            cand.torchaudio_version = ta_version
            pin = _torch_pin_of(fetch, ta_url)
            if pin and pin != cand.torch_version:
                if pin in torch_wheels:
                    cand.torch_version = pin
                    cand.note = f"torch held at {pin}: torchaudio {ta_version} requires it"
                else:
                    cand.torchaudio_version = None
                    cand.note = "torchaudio version left to pip"
        else:
            cand.note = "no torchaudio wheel listed here; pip will resolve it"

    usable = [c for c in choice.candidates if c.ok]
    if not usable:
        choice.note = choice.note or "; ".join(f"{c.tag}: {c.reason}" for c in choice.candidates)
        return choice
    best = max(usable, key=lambda c: (ver_tuple(c.torch_version), cuda_of_tag(c.tag) or (0, 0)))
    best.chosen = True
    choice.tag, choice.index_url = best.tag, best.index_url
    choice.torch_version, choice.torchaudio_version = best.torch_version, best.torchaudio_version
    return choice
