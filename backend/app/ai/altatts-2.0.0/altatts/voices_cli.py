"""``altatts voices`` -- manage a model's voice bank.

    altatts voices list  --model runs/kinyarwanda
    altatts voices build --model runs/kinyarwanda \
        [--train-metadata data/tts_train.jsonl --audio-root data/]
    altatts voices remove --model runs/kinyarwanda --name agent_claire
    altatts voices report --model runs/kinyarwanda      # privacy report

``build`` (re)creates the anonymized default voices (3 female + 3 male,
mixed ages) and verifies them against the training speakers. Passing the
training metadata lets the builder measure real intra/inter-speaker
similarity for an adaptive threshold; without it, table-space similarity
with a fixed threshold is used.
"""
from __future__ import annotations

import argparse
import json
import os
from typing import List, Optional

from .utils import clear_terminal, quiet_warnings


def main(argv: Optional[List[str]] = None) -> int:
    quiet_warnings()
    clear_terminal()
    p = argparse.ArgumentParser(prog="altatts voices")
    p.add_argument("command", choices=["list", "build", "remove", "report"])
    p.add_argument("--model", required=True)
    p.add_argument("--name", default=None)
    p.add_argument("--train-metadata", nargs="+", default=None)
    p.add_argument("--audio-root", default=None)
    p.add_argument("--device", default="auto")
    p.add_argument("--seed", type=int, default=None)
    p.add_argument("--max-similarity", type=float, default=None)
    args = p.parse_args(argv)

    from .inference.synthesizer import Synthesizer
    tts = Synthesizer.from_pretrained(args.model, device=args.device)
    if args.command == "list":
        for name, info in tts.voices().items():
            desc = ", ".join(f"{k}={v}" for k, v in info.items()
                             if k in ("gender", "age_group", "kind", "alias_of"))
            priv = info.get("privacy")
            if priv:
                desc += (f", similarity {priv['max_similarity']:.2f}/"
                         f"{priv['threshold']:.2f} "
                         f"{'ok' if priv['passed'] else 'NOT anonymous'}")
            print(f"  {name:<24} {desc}")
        return 0
    if args.command == "remove":
        if not args.name:
            raise SystemExit("--name required")
        ok = tts.remove_speaker(args.name)
        print("removed" if ok else "no such voice")
        return 0 if ok else 1
    if args.command == "report":
        path = os.path.join(args.model, "privacy_report.json")
        if not os.path.isfile(path):
            print("no privacy_report.json -- run `altatts voices build` first")
            return 1
        print(json.dumps(json.load(open(path, encoding="utf-8")), indent=2))
        return 0
    # build
    if tts.cfg.is_legacy:
        raise SystemExit("default voices need an ALTATTS 2 model (fine-tune "
                         "the v1 model with altatts-train --init-from to upgrade)")
    if args.seed is not None:
        tts.cfg.privacy.seed = args.seed
    if args.max_similarity is not None:
        tts.cfg.privacy.max_similarity = args.max_similarity
    dataset = None
    if args.train_metadata:
        from .training.data import load_records, TTSDataset
        cfg = tts.cfg
        if args.audio_root is not None:
            cfg.data.audio_root = args.audio_root
        recs = load_records(args.train_metadata, cfg)
        dataset = TTSDataset(recs, cfg, tts.tokenizer, tts.speakers)
    from .training.anonymize import build_default_voices
    bank = build_default_voices(tts.model, tts.cfg, tts.speakers, tts.tokenizer,
                                args.model, dataset=dataset, device=tts.device,
                                voices=tts.voice_bank)
    print(f"{len([v for v in bank.voices.values() if v.get('kind') == 'anonymized'])} "
          f"default voices written to {os.path.join(args.model, 'voices.json')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
