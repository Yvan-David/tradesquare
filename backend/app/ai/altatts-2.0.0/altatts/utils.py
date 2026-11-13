"""
Shared utilities: terminal clearing (same CLI UX as ALTASR), seeding, device
resolution, writable-dir probing, and the DDP helpers used by multi-GPU /
multi-node training.
"""
from __future__ import annotations

import datetime as _dt
import os
import random
import subprocess
import sys
import warnings


def quiet_warnings() -> None:
    """Silence library warnings that are noise for end users (deprecation /
    future-API notices and hardware-capability chatter from torch, torchaudio,
    and numpy). Set ALTATTS_VERBOSE=1 to see everything."""
    if os.environ.get("ALTATTS_VERBOSE") == "1":
        return
    noisy_modules = r"(torch|torchaudio|torchvision|numpy|soundfile|onnx|onnxruntime|transformers|av)(\..*)?"
    for cat in (FutureWarning, DeprecationWarning, PendingDeprecationWarning, UserWarning):
        warnings.filterwarnings("ignore", category=cat, module=noisy_modules)
    for pattern in (r".*cuda capability.*", r".*weight_norm.*deprecated.*",
                    r".*torch\.load.*weights_only.*", r".*TypedStorage is deprecated.*",
                    r".*Consider using tensor\.detach\(\).*"):
        warnings.filterwarnings("ignore", message=pattern)
    # Spawned DataLoader workers and torchrun ranks are fresh interpreters
    # that know nothing about the filters above; PYTHONWARNINGS is the only
    # channel that reaches them before their first import.
    os.environ.setdefault("PYTHONWARNINGS", CHILD_WARNING_FILTERS)


#: -W style filters inherited by child processes (see quiet_warnings).
CHILD_WARNING_FILTERS = ",".join((
    "ignore::FutureWarning", "ignore::DeprecationWarning",
    "ignore::PendingDeprecationWarning",
    "ignore:`torch.jit.script` is deprecated:FutureWarning",
))


def clear_terminal() -> None:
    """Clear on CLI start; skipped for pipes, non-zero DDP ranks, or when
    ALTATTS_NO_CLEAR=1 (identical policy to ALTASR)."""
    if os.environ.get("ALTATTS_NO_CLEAR") == "1":
        return
    if int(os.environ.get("RANK", "0")) != 0:
        return
    if not sys.stdout.isatty():
        return
    try:
        subprocess.run(["cls" if os.name == "nt" else "clear"],
                       shell=(os.name == "nt"), check=False)
    except Exception:                                        # noqa: BLE001
        pass


def set_seed(seed: int) -> None:
    random.seed(seed)
    try:
        import numpy as np
        np.random.seed(seed)
    except Exception:                                        # noqa: BLE001
        pass
    try:
        import torch
        torch.manual_seed(seed)
        torch.cuda.manual_seed_all(seed)
    except Exception:                                        # noqa: BLE001
        pass


def resolve_device(device: str = "auto") -> str:
    import torch
    if device not in ("auto", "", None):
        if device.startswith("cuda") and not torch.cuda.is_available():
            warnings.warn("CUDA requested but not available -- falling back to "
                          "CPU (run `altatts doctor`)", RuntimeWarning)
            return "cpu"
        return device
    return "cuda" if torch.cuda.is_available() else "cpu"


def ensure_writable_dir(path: str) -> None:
    """Create ``path`` and PROVE it is writable before any expensive setup."""
    os.makedirs(path, exist_ok=True)
    probe = os.path.join(path, ".write_probe")
    try:
        with open(probe, "w") as fh:
            fh.write("ok")
        os.unlink(probe)
    except OSError as exc:
        raise SystemExit(f"output dir {path!r} is not writable ({exc})")


def fmt_duration(seconds: float) -> str:
    """Compact human duration: 42s / 3m10s / 7h25m / 2d03h."""
    seconds = max(0, int(seconds))
    d, rem = divmod(seconds, 86400)
    h, rem = divmod(rem, 3600)
    m, sec = divmod(rem, 60)
    if d:
        return f"{d}d{h:02d}h"
    if h:
        return f"{h}h{m:02d}m"
    if m:
        return f"{m}m{sec:02d}s"
    return f"{sec}s"


# --------------------------------------------------------------------------- #
#  CPU convolution sanity (oneDNN grouped-conv bug on some torch builds)
# --------------------------------------------------------------------------- #
_CONV_SANITY = {"checked": False, "ok": True, "message": ""}


def cpu_grouped_conv_ok() -> bool:
    """True when grouped + strided Conv1d on CPU matches a reference
    computation. torch 2.13 on aarch64 (oneDNN) returns garbage for the
    exact shape the scale discriminator uses (groups=4, stride=4, k=41)."""
    import torch
    import torch.nn.functional as F
    gen = torch.Generator().manual_seed(0)
    w = torch.randn(64, 4, 41, generator=gen) * 0.05
    # the bug is shape specific (it strikes at exactly 2048 samples on torch
    # 2.13/aarch64): test the segment lengths training actually uses
    for length in (2048, 4096, 8192, 1024):
        x = torch.randn(2, 16, length, generator=gen) * 0.3
        y = F.conv1d(x, w, None, stride=4, padding=20, groups=4)
        cols = F.pad(x, (20, 20)).unfold(2, 41, 4)
        ref = torch.cat([torch.einsum("bclk,ock->bol", cols[:, g * 4:(g + 1) * 4],
                                      w[g * 16:(g + 1) * 16]) for g in range(4)], 1)
        if not bool(torch.isfinite(y).all()) or float((y - ref).abs().max()) > 1e-3:
            return False
    return True


def ensure_cpu_conv_sanity(verbose: bool = True) -> str:
    """Run the self-test once per process; when the kernel is wrong (or
    ALTATTS_NO_MKLDNN=1), disable oneDNN so CPU training / inference are
    numerically correct. Returns a message when something was changed."""
    if _CONV_SANITY["checked"]:
        return _CONV_SANITY["message"]
    _CONV_SANITY["checked"] = True
    try:
        import torch
        forced = os.environ.get("ALTATTS_NO_MKLDNN") == "1"
        if not forced and cpu_grouped_conv_ok():
            return ""
        torch.backends.mkldnn.enabled = False
        ok_after = cpu_grouped_conv_ok()
        msg = ("[altatts] oneDNN disabled for CPU convolutions: " +
               ("ALTATTS_NO_MKLDNN=1" if forced else
                f"grouped Conv1d gave wrong results on this torch build "
                f"({torch.__version__}); workaround "
                f"{'verified' if ok_after else 'FAILED -- run `altatts doctor`'}"))
        _CONV_SANITY.update(ok=ok_after, message=msg)
        if verbose:
            print(msg, flush=True)
        return msg
    except Exception:                                        # noqa: BLE001
        return ""


# --------------------------------------------------------------------------- #
#  DDP helpers (torchrun / altatts-train --gpus / --nodes)
# --------------------------------------------------------------------------- #
def ddp_active() -> bool:
    return "RANK" in os.environ and "WORLD_SIZE" in os.environ


def ddp_rank() -> int:
    return int(os.environ.get("RANK", "0"))


def ddp_local_rank() -> int:
    return int(os.environ.get("LOCAL_RANK", "0"))


def ddp_world_size() -> int:
    return int(os.environ.get("WORLD_SIZE", "1"))


def ddp_init(timeout_min: int = 30) -> None:
    """Initialise the default process group when launched under a launcher.
    NCCL on CUDA machines, gloo for CPU-only (multi-process CPU training)."""
    if not ddp_active():
        return
    import torch
    import torch.distributed as dist
    if not dist.is_initialized():
        backend = "nccl" if torch.cuda.is_available() else "gloo"
        dist.init_process_group(backend=backend,
                                timeout=_dt.timedelta(minutes=timeout_min))
    if torch.cuda.is_available():
        torch.cuda.set_device(ddp_local_rank())


def ddp_barrier() -> None:
    try:
        import torch.distributed as dist
        if dist.is_available() and dist.is_initialized():
            dist.barrier()
    except Exception:                                        # noqa: BLE001
        pass


def ddp_cleanup() -> None:
    try:
        import torch.distributed as dist
        if dist.is_available() and dist.is_initialized():
            dist.destroy_process_group()
    except Exception:                                        # noqa: BLE001
        pass


def is_main_process() -> bool:
    return ddp_rank() == 0
