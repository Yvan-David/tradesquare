"""
The compatibility verdict -- the point of the doctor.

Compares: NVIDIA driver version, the driver's max supported CUDA, torch's
CUDA build version, and each GPU's compute capability against torch's
compiled arch list. **Pure logic over plain values**, unit-testable against
fixture combinations without hardware.

The rule that matters most: **CUDA minor-version compatibility**. A torch
built against CUDA 12.1 runs on ANY driver supporting CUDA 12.x --
reporting that as a problem sends users into needless multi-gigabyte
reinstalls. A genuine incompatibility is only:

  1. the driver is older than the minimum for the torch CUDA MAJOR version;
  2. a GPU's compute capability is absent from the torch build's arch list
     (binary compatibility within a CC major and PTX JIT count as covered);
  3. torch is CPU-only while CUDA GPUs are present;
  4. the torch/torchaudio triple is mismatched (pytorch section).

Driver minimums live in ``compat_table.json`` -- versioned data with a
source URL and a last-verified date, never hardcoded rules.
"""
from __future__ import annotations

import datetime as _dt
import json
import os
import re
from typing import Any, Dict, List, Optional, Sequence

from .checks import FAIL, INFO, PASS, WARN, CheckResult

_SECTION = "compatibility verdict"
TABLE_PATH = os.path.join(os.path.dirname(__file__), "compat_table.json")
TABLE_MAX_AGE_DAYS = 183


def load_table(path: str = TABLE_PATH) -> Dict[str, Any]:
    with open(path, encoding="utf-8") as fh:
        table = json.load(fh)
    for key in ("source", "last_verified", "min_driver_linux"):
        if key not in table:
            raise ValueError(f"compat_table.json missing {key!r}")
    return table


def table_age_days(table: Dict[str, Any],
                   today: Optional[_dt.date] = None) -> int:
    last = table["last_verified"]
    if isinstance(last, str):
        last = _dt.date.fromisoformat(last)
    return ((today or _dt.date.today()) - last).days


def _ver_tuple(version: str) -> tuple:
    return tuple(int(p) for p in re.findall(r"\d+", version or "")[:4])


def verdict(torch_ok: bool,
            torch_cuda_build: Optional[str],
            cuda_available: bool,
            arch_list: Sequence[str],
            driver_version: Optional[str],
            driver_cuda_max: Optional[str],
            gpu_caps: Sequence[str],
            table: Dict[str, Any]) -> List[CheckResult]:
    out: List[CheckResult] = []
    gpus_present = bool(gpu_caps) or bool(driver_version)

    if not torch_ok:
        return out

    if torch_cuda_build is None and gpus_present:
        out.append(CheckResult(
            _SECTION, "torch build vs hardware", FAIL,
            found="CPU-only torch while NVIDIA GPU(s) are present",
            expected="a CUDA torch build",
            remediation="Install the CUDA build matching your driver "
                        f"(driver supports CUDA {driver_cuda_max}): "
                        "`altatts doctor --fix` cross-checks driver, GPU and "
                        "the wheel index and installs the newest torch this "
                        "machine can run (`--fix --dry-run` shows the choice)."))
        return out
    if torch_cuda_build is None:
        out.append(CheckResult(_SECTION, "torch build vs hardware", PASS,
                               found="CPU-only torch on a CPU-only machine"))
        return out
    if not gpus_present:
        out.append(CheckResult(
            _SECTION, "torch build vs hardware", INFO,
            found=f"CUDA {torch_cuda_build} torch but no NVIDIA driver/GPU "
                  f"detected -- will run on CPU"))
        return out

    major = str(_ver_tuple(torch_cuda_build)[0])
    min_driver = table["min_driver_linux"].get(major)
    if min_driver is None:
        out.append(CheckResult(
            _SECTION, "driver minimum", WARN,
            found=f"CUDA major {major} not in compat_table.json "
                  f"(last verified {table['last_verified']})",
            expected="an entry per supported CUDA major",
            remediation=f"Update altatts/env/compat_table.json from "
                        f"{table['source']}"))
    elif driver_version and _ver_tuple(driver_version) < _ver_tuple(min_driver):
        out.append(CheckResult(
            _SECTION, "driver minimum", FAIL,
            found=f"driver {driver_version} < required {min_driver} for "
                  f"CUDA {torch_cuda_build} torch",
            expected=f"driver >= {min_driver}",
            remediation="Preferred: install a torch built for CUDA "
                        f"<= {driver_cuda_max or 'your driver version'} "
                        "(`altatts doctor --fix` picks and installs it; "
                        "`--fix --dry-run` shows the cross-check first). "
                        "Alternative: upgrade the NVIDIA driver (needs root + "
                        "reboot; doctor will not do this)."))
    else:
        out.append(CheckResult(
            _SECTION, "driver minimum", PASS,
            found=f"driver {driver_version} >= {min_driver} for CUDA "
                  f"{torch_cuda_build} (minor versions are compatible)"))

    arch_caps = {m.group(1) for a in arch_list
                 for m in [re.search(r"sm_(\d+)", a)] if m}
    for i, cap in enumerate(gpu_caps):
        cap_key = cap.replace(".", "")
        if not arch_caps:
            continue
        covered, how = _covers(arch_list, arch_caps, cap_key)
        if covered:
            out.append(CheckResult(
                _SECTION, f"gpu{i} capability sm_{cap_key}", PASS, found=how))
        else:
            out.append(CheckResult(
                _SECTION, f"gpu{i} capability sm_{cap_key}", FAIL,
                found=f"not covered by torch arch list "
                      f"({', '.join(sorted(arch_list))})",
                expected=f"sm_{cap_key} supported",
                remediation="This GPU is newer than the torch build. "
                            "Install a newer torch/CUDA build that lists "
                            f"sm_{cap_key} (altatts doctor --fix), or a "
                            "nightly wheel if none is released yet."))

    if cuda_available is False:
        out.append(CheckResult(
            _SECTION, "cuda runtime usable", FAIL,
            found="torch.cuda.is_available() is False despite a CUDA build "
                  "and present GPUs",
            expected="True",
            remediation="Check the driver minimum verdict above; if it "
                        "passes, inspect CUDA_VISIBLE_DEVICES and container "
                        "GPU passthrough (--gpus all)."))
    return out


def _cc_split(key: str) -> tuple:
    return (int(key[:-1] or 0), int(key[-1:]))


def _covers(arch_list: Sequence[str], arch_caps: set, cap_key: str) -> tuple:
    if cap_key in arch_caps:
        return True, "exactly in torch arch list"
    major, minor = _cc_split(cap_key)
    for k in arch_caps:
        km, kn = _cc_split(k)
        if km == major and kn <= minor:
            return True, (f"covered by sm_{k} (binary-compatible within "
                          f"CC major {major})")
    for a in arch_list:
        m = re.search(r"compute_(\d+)", a)
        if m and _cc_split(m.group(1)) <= (major, minor):
            return True, f"covered by {a} (PTX JIT forward-compat)"
    return False, ""


def compat_checks(t: Dict[str, Any], g: Dict[str, Any]) -> List[CheckResult]:
    table = load_table()
    out = verdict(torch_ok=t["ok"],
                  torch_cuda_build=t["cuda_build"],
                  cuda_available=t["cuda_available"],
                  arch_list=t["arch_list"],
                  driver_version=g.get("driver"),
                  driver_cuda_max=g.get("driver_cuda_max"),
                  gpu_caps=[gpu["compute_cap"] for gpu in g.get("gpus", [])],
                  table=table)
    age = table_age_days(table)
    if age > TABLE_MAX_AGE_DAYS:
        out.append(CheckResult(
            _SECTION, "compat table freshness", WARN,
            found=f"last verified {table['last_verified']} ({age} days ago)",
            expected=f"<= {TABLE_MAX_AGE_DAYS} days",
            remediation=f"Re-verify altatts/env/compat_table.json against "
                        f"{table['source']} and bump last_verified."))
    return out
