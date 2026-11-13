"""
Distributed launching -- three tiers, one code path (the ALTASR design).

Tier 1 (no launcher knowledge): ``altatts-train --gpus all|0,1,3|4``
    re-execs through ``torch.distributed.run`` with one process per GPU.
    Default with NO flag: a single process on the first GPU (CPU if none),
    exactly like ALTATTS 0.1 -- pass ``--gpus all`` to use every GPU.
Tier 2 (multi-node): ``--nodes 4 --gpus-per-node 8 --master-addr node0
    --master-port 29500 --node-rank 0``; under SLURM everything is
    auto-detected from SLURM_* so the same command works inside srun.
Tier 3 (external launcher): if RANK/WORLD_SIZE are already set (torchrun,
    srun --ntasks), spawn nothing and just run.

Elastic: ``--max-restarts N`` is forwarded to torchrun; combined with the
trainer's auto-resume, a died node restarts from the last checkpoint instead
of from scratch. CPU-only machines can still run several processes
(``--gpus`` is ignored, ``--cpu-procs N`` spawns N gloo ranks).
"""
from __future__ import annotations

import os
import subprocess
import sys
from typing import List, Optional, Sequence, Tuple

#: flags consumed by the launcher and stripped before re-exec
_LAUNCH_FLAGS = {"--gpus": 1, "--nodes": 1, "--gpus-per-node": 1,
                 "--master-addr": 1, "--master-port": 1, "--node-rank": 1,
                 "--max-restarts": 1, "--cpu-procs": 1}


def parse_gpus(spec: Optional[str]) -> Tuple[Optional[List[int]], int, int]:
    """--gpus value -> (visible gpu ids or None for 'as-is', nproc, n_available).

    'all' = every visible GPU; '0,1,3' = that subset; '4' = first 4.
    None = no flag = single process. On a CPU-only machine (None, 1, 0).
    """
    try:
        import torch
        n_avail = torch.cuda.device_count() if torch.cuda.is_available() else 0
    except ImportError:
        n_avail = 0
    if n_avail == 0:
        return None, 1, 0
    if spec is None or spec == "":
        return None, 1, n_avail
    if spec == "all":
        return None, n_avail, n_avail
    if "," in spec:
        ids = [int(x) for x in spec.split(",") if x.strip() != ""]
        return ids, len(ids), n_avail
    n = int(spec)
    if n <= 0:
        raise ValueError("--gpus must be 'all', a count, or a comma list")
    return list(range(min(n, n_avail))), min(n, n_avail), n_avail


def _slurm_env() -> Optional[dict]:
    if "SLURM_JOB_ID" not in os.environ:
        return None
    nodes = int(os.environ.get("SLURM_NNODES", "1"))
    node_rank = int(os.environ.get("SLURM_NODEID", "0"))
    nodelist = os.environ.get("SLURM_JOB_NODELIST", "")
    master = os.environ.get("SLURM_LAUNCH_NODE_IPADDR", "")
    if not master and nodelist:
        try:
            master = subprocess.run(
                ["scontrol", "show", "hostnames", nodelist],
                capture_output=True, text=True, timeout=5
            ).stdout.splitlines()[0].strip()
        except Exception:                        # noqa: BLE001
            master = ""
    return {"nodes": nodes, "node_rank": node_rank,
            "master_addr": master or "127.0.0.1"}


def strip_launch_flags(argv: Sequence[str]) -> List[str]:
    out: List[str] = []
    skip = 0
    for a in argv:
        if skip:
            skip -= 1
            continue
        base = a.split("=", 1)[0]
        if base in _LAUNCH_FLAGS:
            if "=" not in a:
                skip = _LAUNCH_FLAGS[base]
            continue
        out.append(a)
    return out


def maybe_relaunch(module: str, args, argv: Optional[Sequence[str]]) -> bool:
    """Tier detection. Returns False when the caller should just run
    (single process, or already under a launcher). Otherwise re-execs
    through torch.distributed.run and raises SystemExit with its code."""
    if os.environ.get("RANK") is not None and \
            os.environ.get("WORLD_SIZE") is not None:
        return False                              # Tier 3: launcher set us up

    slurm = _slurm_env()
    nodes = args.nodes or (slurm["nodes"] if slurm else 1)
    node_rank = (args.node_rank if args.node_rank is not None
                 else (slurm["node_rank"] if slurm else 0))
    master_addr = args.master_addr or (slurm["master_addr"] if slurm
                                       else "127.0.0.1")
    gpu_ids, nproc, n_avail = parse_gpus(args.gpus)
    if args.gpus_per_node:
        nproc = args.gpus_per_node
    cpu_mode = n_avail == 0 or getattr(args, "device", None) == "cpu"
    cpu_procs = getattr(args, "cpu_procs", None)
    if cpu_procs and cpu_mode:
        nproc = max(1, int(cpu_procs))
        gpu_ids = []                              # hide the GPUs from the ranks
    elif cpu_procs:
        print(f"[launch] --cpu-procs ignored: {n_avail} CUDA GPU(s) visible "
              f"(add --device cpu to force CPU ranks)", flush=True)
    if args.gpus and n_avail == 0:
        print(f"[launch] --gpus {args.gpus} requested but no CUDA GPUs are "
              f"usable; running on CPU. See `altatts doctor`.", flush=True)
    if nodes <= 1 and nproc <= 1:
        return False                              # plain single process

    cmd = [sys.executable, "-m", "torch.distributed.run",
           f"--nproc_per_node={nproc}",
           f"--max-restarts={args.max_restarts}"]
    if nodes > 1:
        cmd += [f"--nnodes={nodes}", f"--node_rank={node_rank}",
                f"--master_addr={master_addr}",
                f"--master_port={args.master_port}"]
    else:
        cmd += ["--standalone"]
    cmd += ["-m", module] + strip_launch_flags(
        list(argv if argv is not None else sys.argv[1:]))

    env = dict(os.environ)
    if gpu_ids is not None:
        env["CUDA_VISIBLE_DEVICES"] = ",".join(map(str, gpu_ids))   # "" = CPU ranks
    env.setdefault("ALTATTS_NO_CLEAR", "1")        # ranks must not wipe logs
    env.setdefault("OMP_NUM_THREADS", "1")         # avoid CPU oversubscription
    print(f"[launch] {nodes} node(s) x {nproc} proc(s)"
          + (f", gpus={gpu_ids}" if gpu_ids else "")
          + f" -> torch.distributed.run", flush=True)
    raise SystemExit(subprocess.run(cmd, env=env).returncode)


def add_launch_args(parser) -> None:
    g = parser.add_argument_group("distributed launching")
    g.add_argument("--gpus", default=None, metavar="all|N|i,j,k",
                   help="GPUs to train on: 'all', a count, or ids. Spawns "
                        "one process per GPU -- no torchrun knowledge needed. "
                        "Default: one process (first GPU, or CPU).")
    g.add_argument("--nodes", type=int, default=None,
                   help="Number of nodes (multi-node; auto under SLURM).")
    g.add_argument("--gpus-per-node", type=int, default=None)
    g.add_argument("--node-rank", type=int, default=None)
    g.add_argument("--master-addr", default=None)
    g.add_argument("--master-port", type=int, default=29500)
    g.add_argument("--max-restarts", type=int, default=0,
                   help="Elastic restarts; with auto-resume a died job "
                        "continues from the last checkpoint.")
    g.add_argument("--cpu-procs", type=int, default=None,
                   help="Run N CPU data-parallel processes (gloo backend); "
                        "applies on CPU-only machines or with --device cpu.")
