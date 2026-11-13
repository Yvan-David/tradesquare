"""
``altatts doctor --distributed`` -- actually exercise collective comms.

Spawns a real process group, runs warm-up + timed all-reduces and one tiny
DDP step, and reports achieved bus bandwidth. This catches "NCCL initializes
but hangs on the first collective" BEFORE it wastes a multi-node allocation
-- everything runs under a hard timeout and a hang is a FAIL, not a wait.

Backend/world choice: NCCL with one rank per GPU when >= 2 GPUs; otherwise
gloo with 2 CPU ranks (still validates spawn/rendezvous/collectives on
single-GPU or CPU-only boxes).
"""
from __future__ import annotations

import json
import os
import tempfile
import time
from typing import Any, Dict, List

from .checks import FAIL, INFO, PASS, WARN, CheckResult

_S = "distributed comms"
_TIMEOUT_S = 120.0
_TENSOR_MB = 16


def _worker(rank: int, world: int, backend: str, init_file: str,
            result_file: str) -> None:                 # pragma: no cover
    import torch
    import torch.distributed as dist
    dist.init_process_group(backend, init_method=f"file://{init_file}",
                            rank=rank, world_size=world)
    device = torch.device(f"cuda:{rank}" if backend == "nccl" else "cpu")
    if backend == "nccl":
        torch.cuda.set_device(device)
    n = _TENSOR_MB * (1 << 20) // 4
    x = torch.ones(n, device=device)
    dist.all_reduce(x)
    if backend == "nccl":
        torch.cuda.synchronize()
    iters = 5
    t0 = time.time()
    for _ in range(iters):
        dist.all_reduce(x)
    if backend == "nccl":
        torch.cuda.synchronize()
    dt = time.time() - t0
    from torch.nn.parallel import DistributedDataParallel as DDP
    model = torch.nn.Linear(64, 64).to(device)
    ddp = DDP(model, device_ids=[rank] if backend == "nccl" else None)
    out = ddp(torch.randn(8, 64, device=device)).sum()
    out.backward()
    if rank == 0:
        bus_gbs = (_TENSOR_MB / 1024) * iters * 2 * (world - 1) / world / dt
        with open(result_file, "w", encoding="utf-8") as fh:
            json.dump({"world": world, "backend": backend,
                       "allreduce_ms": round(dt / iters * 1e3, 2),
                       "bus_gbs": round(bus_gbs, 2)}, fh)
    dist.destroy_process_group()


def distributed_checks(t: Dict[str, Any]) -> List[CheckResult]:
    if not t.get("ok"):
        return [CheckResult(_S, "process group", WARN,
                            found="torch absent -- cannot test",
                            remediation="Install torch first (see the "
                                        "pytorch section).")]
    import torch.multiprocessing as mp

    n_gpu = t.get("device_count", 0)
    if t.get("cuda_available") and n_gpu >= 2:
        backend, world = "nccl", n_gpu
    else:
        backend, world = "gloo", 2
    note = (f"{backend} x {world}"
            + ("" if backend == "nccl" else
               f" (CPU ranks: {n_gpu} GPU(s) visible; NCCL needs >= 2)"))

    tmp = tempfile.mkdtemp(prefix="altatts_dist_")
    init_file = os.path.join(tmp, "init")
    result_file = os.path.join(tmp, "result.json")
    try:
        ctx = mp.spawn(_worker, args=(world, backend, init_file, result_file),
                       nprocs=world, join=False)
        deadline = time.time() + _TIMEOUT_S
        while time.time() < deadline:
            if ctx.join(timeout=2.0):
                break
        else:
            for p in ctx.processes:
                if p.is_alive():
                    p.terminate()
            return [CheckResult(
                _S, "all-reduce", FAIL,
                found=f"hung for {_TIMEOUT_S:.0f}s ({note})",
                expected="completes in seconds",
                remediation="Classic NCCL first-collective hang: check "
                            "NCCL_SOCKET_IFNAME (pick a real interface), "
                            "NCCL_P2P_DISABLE=1 as a test, IOMMU/ACS "
                            "settings, and firewalls between nodes. "
                            "NCCL_DEBUG=INFO shows where it stalls.")]
    except Exception as exc:                     # noqa: BLE001
        return [CheckResult(
            _S, "all-reduce", FAIL, found=str(exc)[:300], expected="clean run",
            remediation="Run with NCCL_DEBUG=INFO (or GLOO_LOG_LEVEL=DEBUG) "
                        "to locate the failing rank; verify all ranks see "
                        "their GPU (CUDA_VISIBLE_DEVICES).")]

    if not os.path.isfile(result_file):
        return [CheckResult(
            _S, "all-reduce", FAIL,
            found=f"workers exited without a result ({note})",
            expected="rank 0 reports bandwidth",
            remediation="Re-run with NCCL_DEBUG=INFO / GLOO logging; a rank "
                        "crashed during the collective.")]
    with open(result_file, encoding="utf-8") as fh:
        r = json.load(fh)
    out = [CheckResult(_S, "all-reduce + DDP step", PASS,
                       found=f"{note}: {r['allreduce_ms']} ms per "
                             f"{_TENSOR_MB} MiB all-reduce, "
                             f"~{r['bus_gbs']} GB/s bus")]
    if backend == "nccl" and r["bus_gbs"] < 5:
        out.append(CheckResult(
            _S, "bandwidth", WARN, found=f"{r['bus_gbs']} GB/s",
            expected=">= 5 GB/s intra-node",
            remediation="Far below NVLink/PCIe expectations -- check "
                        "`nvidia-smi topo -m` for cross-NUMA pairs and "
                        "NCCL_P2P_DISABLE."))
    return out
