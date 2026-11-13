"""``altatts combine-data`` -- build the versioned combined training set.

    altatts combine-data --out /data/TTS/Combined_Version_two_TTS_training --workers 16
    altatts combine-data --out ... --datasets kiswahili code_switching --limit-per-dataset 50 --no-convert
    altatts combine-data --out ... --fresh            # re-convert all audio too
    altatts combine-data --list                        # show the registry

Add datasets in ``altatts/datasets/registry.py`` (or pass ``--registry
my_registry.json`` exported from the notebook).
"""
from __future__ import annotations

import argparse
import json
import os
from typing import List, Optional

from ..utils import clear_terminal, quiet_warnings


def main(argv: Optional[List[str]] = None) -> int:
    quiet_warnings()
    clear_terminal()
    from .registry import DATASETS, OUTPUT_FOLDER, data_root
    from .spec import DatasetSpec
    p = argparse.ArgumentParser(prog="altatts combine-data",
                                description="Combine every registered TTS corpus into one "
                                            "versioned, uniformly formatted training set.")
    p.add_argument("--out", default=None,
                   help=f"Output folder (default: <data root>/{OUTPUT_FOLDER})")
    p.add_argument("--root", default=None, help="Data root (default: ALTA_TTS_DATA_ROOT or the registry default)")
    p.add_argument("--registry", default=None, help="JSON list of DatasetSpec dicts replacing the built-in registry")
    p.add_argument("--datasets", nargs="+", default=None, help="Only these dataset names")
    p.add_argument("--workers", type=int, default=max(2, (os.cpu_count() or 4) - 2))
    p.add_argument("--seed", type=int, default=1234)
    p.add_argument("--dev-fraction", type=float, default=0.02)
    p.add_argument("--dev-min", type=int, default=2)
    p.add_argument("--dev-max", type=int, default=60)
    p.add_argument("--sample-rate", type=int, default=22050)
    p.add_argument("--format", choices=["flac", "wav"], default="flac")
    p.add_argument("--limit-per-dataset", type=int, default=0, help="Quick runs: first N records per dataset")
    p.add_argument("--no-convert", action="store_true", help="Keep source audio paths (no transcoding)")
    p.add_argument("--no-gender", action="store_true", help="Skip pitch-based gender detection")
    p.add_argument("--fresh", action="store_true", help="Delete previously converted audio first")
    p.add_argument("--list", action="store_true", help="Print the registry and exit")
    p.add_argument("--kit-only", action="store_true",
                   help="Only (re)write train.sh + README_TRAINING.md into --out (no rebuild)")
    p.add_argument("--recipe", default="multilingual_callcenter", help="Recipe named in train.sh")
    args = p.parse_args(argv)

    specs = DATASETS
    if args.registry:
        with open(args.registry, encoding="utf-8") as fh:
            specs = [DatasetSpec.from_dict(d) for d in json.load(fh)]
    if args.list:
        for s in specs:
            print(f"  {s.name:<18} {s.family:<8} {s.language:<6} {s.role:<5} "
                  f"{'on ' if s.enabled else 'off'}  {s.path}  [{s.adapter}]"
                  + (f"  cap {s.max_hours} h" if s.max_hours else ""))
        return 0
    root = args.root or data_root()
    out = args.out or os.path.join(root, OUTPUT_FOLDER)
    if args.kit_only:
        from .combine import write_training_kit
        for name, path in write_training_kit(out, args.recipe).items():
            print(f"  wrote {path}")
        return 0
    from .combine import run
    run(specs, out, root, workers=args.workers, seed=args.seed, dev_fraction=args.dev_fraction,
        dev_min=args.dev_min, dev_max=args.dev_max, sample_rate=args.sample_rate, fmt=args.format,
        limit_per_dataset=args.limit_per_dataset, fresh=args.fresh, convert=not args.no_convert,
        detect_gender=not args.no_gender, only=args.datasets)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
