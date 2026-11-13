#!/usr/bin/env python3
"""
``altatts doctor`` / ``altatts-doctor`` -- one-command environment diagnosis
(and repair via --fix). The same tool ALTASR ships, tuned for TTS.

    altatts doctor                    # diagnose, exit 0/1/2
    altatts doctor --fix              # diagnose then repair what's safe
    altatts doctor --fix --dry-run    # cross-check + repair plan, change nothing
    altatts doctor --json             # machine readable, for CI
    altatts doctor --distributed      # additionally test multi-GPU comms
    altatts doctor --checkpoint X     # additionally load + speak with a model
    altatts --doctor / altatts --doctor-fix     # the same, as flags

Exit codes: 0 = all pass, 1 = warnings only, 2 = at least one failure.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from typing import Any, Dict, List, Optional

from .checks import (FAIL, INFO, PASS, WARN, CheckResult, audio_checks,
                     checkpoint_smoke, detect_gpus, detect_torch, gpu_checks,
                     multigpu_checks, python_checks, pytorch_checks,
                     smoke_checks, system_checks)
from .compat import compat_checks

JSON_SCHEMA_VERSION = 1

_COLORS = {PASS: "\033[32m", WARN: "\033[33m", FAIL: "\033[31m",
           INFO: "\033[36m"}
_RESET = "\033[0m"


def run_checks(distributed: bool = False,
               checkpoint: Optional[str] = None,
               data_dir: Optional[str] = None,
               out_dir: Optional[str] = None,
               workers: int = 8,
               smoke: bool = True) -> List[CheckResult]:
    """The full read-only diagnosis (everything except --fix)."""
    results: List[CheckResult] = []
    results += python_checks()
    t = detect_torch()
    g = detect_gpus()
    results += pytorch_checks(t, g)
    results += gpu_checks(g)
    try:
        results += compat_checks(t, g)
    except Exception as exc:                     # noqa: BLE001
        results.append(CheckResult(
            "compatibility verdict", "verdict", WARN,
            found=f"verdict unavailable: {exc}",
            remediation="Report this: the doctor itself hit an error."))
    results += multigpu_checks(t, g)
    results += system_checks(planned_workers=workers, data_dir=data_dir,
                             out_dir=out_dir)
    results += audio_checks()
    if smoke:
        results += smoke_checks(t)
    if distributed:
        from .distributed import distributed_checks
        results += distributed_checks(t)
    if checkpoint:
        results += checkpoint_smoke(checkpoint)
    return results


def summarize(results: List[CheckResult]) -> Dict[str, int]:
    return {"pass": sum(r.status == PASS for r in results),
            "warn": sum(r.status == WARN for r in results),
            "fail": sum(r.status == FAIL for r in results),
            "info": sum(r.status == INFO for r in results)}


def exit_code(results: List[CheckResult]) -> int:
    s = summarize(results)
    if s["fail"]:
        return 2
    if s["warn"]:
        return 1
    return 0


def render(results: List[CheckResult], verbose: bool = False,
           color: Optional[bool] = None, elapsed: Optional[float] = None
           ) -> str:
    if color is None:
        color = sys.stdout.isatty()

    def paint(status: str) -> str:
        tag = f"{status:<4}"
        return f"{_COLORS[status]}{tag}{_RESET}" if color else tag

    lines: List[str] = []
    section = None
    for r in results:
        if r.section != section:
            section = r.section
            lines.append("")
            lines.append(f"== {section} " + "=" * max(0, 58 - len(section)))
        row = f"  {paint(r.status)} {r.name:<34} {r.found}"
        if r.expected and r.status in (WARN, FAIL):
            row += f"   (expected: {r.expected})"
        lines.append(row)
    s = summarize(results)
    lines.append("")
    lines.append(f"summary: {s['pass']} pass, {s['warn']} warn, "
                 f"{s['fail']} fail, {s['info']} info"
                 + (f"  ({elapsed:.1f}s)" if elapsed is not None else ""))
    bad = [r for r in results if r.status in (WARN, FAIL)]
    if bad:
        lines.append("")
        lines.append("REMEDIATION")
        for r in bad:
            lines.append(f"  {paint(r.status)} {r.section} / {r.name}:")
            lines.append(f"       {r.remediation}")
        if any(r.status == FAIL for r in bad):
            lines.append("")
            lines.append("  -> `altatts doctor --fix --dry-run` shows what can be "
                         "repaired automatically; `altatts doctor --fix` does it.")
    return "\n".join(lines)


def to_json(results: List[CheckResult],
            elapsed: Optional[float] = None) -> Dict[str, Any]:
    return {"schema_version": JSON_SCHEMA_VERSION,
            "summary": summarize(results),
            "exit_code": exit_code(results),
            "elapsed_seconds": round(elapsed, 3) if elapsed else None,
            "checks": [r.to_dict() for r in results]}


# --------------------------------------------------------------------------- #
#  Fast startup preflight (run by training before any expensive setup)
# --------------------------------------------------------------------------- #
def fast_preflight(cfg) -> List[str]:
    """Cheap checks against a resolved Config. Returns error strings."""
    import os
    errors: List[str] = []
    dev = cfg.train.device
    if dev.startswith("cuda"):
        try:
            import torch
            if not torch.cuda.is_available():
                errors.append(f"train.device={dev!r} but "
                              "torch.cuda.is_available() is False")
            elif ":" in dev:
                idx = int(dev.split(":")[1])
                if idx >= torch.cuda.device_count():
                    errors.append(f"train.device={dev!r} but only "
                                  f"{torch.cuda.device_count()} GPU(s) visible")
        except ImportError:
            errors.append("torch is not importable in this environment")
    out_dir = cfg.train.out_dir
    try:
        os.makedirs(out_dir, exist_ok=True)
        probe = os.path.join(out_dir, ".doctor_write_probe")
        with open(probe, "w") as fh:
            fh.write("ok")
        os.unlink(probe)
    except OSError as exc:
        errors.append(f"output dir {out_dir!r} is not writable ({exc})")
    for p in list(cfg.data.train_metadata) + list(cfg.data.val_metadata):
        if not os.path.isfile(p):
            errors.append(f"metadata file not found: {p}")
    if cfg.data.audio_root and not os.path.isdir(cfg.data.audio_root):
        errors.append(f"audio root not found: {cfg.data.audio_root}")
    return errors


def preflight_or_die(cfg) -> None:
    errs = fast_preflight(cfg)
    if errs:
        for e in errs:
            print(f"[preflight] FAIL: {e}", file=sys.stderr)
        print("[preflight] run `altatts doctor` for a full diagnosis "
              "(or --fix to repair what's safe).", file=sys.stderr)
        raise SystemExit(2)


# --------------------------------------------------------------------------- #
#  CLI
# --------------------------------------------------------------------------- #
def build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="altatts doctor",
        description="Diagnose (and with --fix, repair) the ALTATTS "
                    "environment. Exit codes: 0 pass, 1 warnings, 2 failures.")
    p.add_argument("--fix", action="store_true",
                   help="After diagnosing, repair what is safe to repair "
                        "(torch triple reinstall, missing pure-Python deps). "
                        "Try --fix --dry-run first.")
    p.add_argument("--dry-run", action="store_true",
                   help="With --fix: print the repair plan, change nothing.")
    p.add_argument("--yes", action="store_true",
                   help="With --fix: skip the confirmation prompt.")
    p.add_argument("--force", action="store_true",
                   help="With --fix: proceed even if a training job is "
                        "running on the GPUs or the env is system Python.")
    p.add_argument("--index-url", default=None, metavar="TAG|URL",
                   help="With --fix: skip the wheel cross-check and install torch "
                        "from this PyTorch index (a tag such as cu126 or cpu, or a "
                        "full URL).")
    p.add_argument("--allow-root-actions", action="store_true",
                   help="Permit fixes that require root (default: report only).")
    p.add_argument("--json", action="store_true", dest="as_json",
                   help="Emit machine-readable JSON (stable schema) for CI.")
    p.add_argument("--verbose", action="store_true")
    p.add_argument("--distributed", action="store_true",
                   help="Spawn a process group and run an all-reduce + tiny "
                        "DDP step (multi-GPU comms test).")
    p.add_argument("--checkpoint", default=None, metavar="DIR",
                   help="Load this model folder and synthesize a sentence.")
    p.add_argument("--data-dir", default=None,
                   help="Probe read throughput of this data volume.")
    p.add_argument("--out-dir", default=None,
                   help="Check free space/writability of this output dir.")
    p.add_argument("--workers", type=int, default=8,
                   help="Planned DataLoader workers (for the ulimit check).")
    p.add_argument("--no-smoke", action="store_true",
                   help="Skip the live tensor/matmul smoke tests.")
    return p


def main(argv=None) -> int:
    from ..utils import quiet_warnings
    quiet_warnings()                      # torch's driver/jit chatter is reported as checks
    args = build_argparser().parse_args(argv)
    t0 = time.time()
    results = run_checks(distributed=args.distributed,
                         checkpoint=args.checkpoint,
                         data_dir=args.data_dir, out_dir=args.out_dir,
                         workers=args.workers, smoke=not args.no_smoke)
    elapsed = time.time() - t0

    if args.fix:
        if not args.as_json:
            print(render(results, verbose=args.verbose, elapsed=elapsed))
            print()
        from .fix import run_fix
        return run_fix(results, dry_run=args.dry_run, yes=args.yes,
                       force=args.force, allow_root=args.allow_root_actions,
                       as_json=args.as_json, index_url=args.index_url)

    if args.as_json:
        print(json.dumps(to_json(results, elapsed), indent=2))
    else:
        print(render(results, verbose=args.verbose, elapsed=elapsed))
    return exit_code(results)


if __name__ == "__main__":
    raise SystemExit(main())
