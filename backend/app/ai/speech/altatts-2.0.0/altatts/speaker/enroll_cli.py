"""``altatts-enroll`` -- add a voice to a model from a few seconds of audio.

    altatts-enroll --model runs/kinyarwanda --name agent_claire \
        --audio claire_1.wav claire_2.wav [--gender female]

    # few-shot refinement (needs transcripts, one per clip):
    altatts-enroll --model runs/kinyarwanda --name agent_claire \
        --audio a.wav b.wav --text "Muraho neza." "Murakoze guhamagara." \
        --adapt-steps 300

    altatts-enroll --model runs/kinyarwanda --list
    altatts-enroll --model runs/kinyarwanda --remove agent_claire
"""
from __future__ import annotations

import argparse
import sys
from typing import List, Optional

from ..utils import clear_terminal, quiet_warnings


def main(argv: Optional[List[str]] = None) -> int:
    quiet_warnings()
    clear_terminal()
    p = argparse.ArgumentParser(prog="altatts-enroll",
                                description="Enroll / list / remove voices "
                                            "(zero-shot cloning, no training)")
    p.add_argument("--model", required=True, help="Checkpoint folder")
    p.add_argument("--name", default=None, help="Voice name to create")
    p.add_argument("--audio", nargs="+", default=None,
                   help="Reference clip(s): 3-30 s of clean speech each")
    p.add_argument("--text", nargs="+", default=None,
                   help="Transcripts (one per clip) for --adapt-steps")
    p.add_argument("--gender", choices=["male", "female"], default=None)
    p.add_argument("--age-group", choices=["16-25", "25-45", "45+"], default=None)
    p.add_argument("--adapt-steps", type=int, default=0,
                   help="Few-shot refinement steps (0 = pure zero-shot)")
    p.add_argument("--list", action="store_true", help="List voices and exit")
    p.add_argument("--remove", default=None, metavar="NAME")
    p.add_argument("--test", default=None, metavar="TEXT",
                   help="After enrolling, synthesize TEXT with the new voice")
    p.add_argument("--out", default="enrolled_test.wav")
    p.add_argument("--device", default="auto")
    args = p.parse_args(argv)

    from ..inference.synthesizer import Synthesizer
    tts = Synthesizer.from_pretrained(args.model, device=args.device)
    if args.list:
        for name, info in tts.voices().items():
            extra = ", ".join(f"{k}={v}" for k, v in info.items()
                              if k in ("gender", "kind", "age_group", "alias_of"))
            print(f"  {name:<24} {extra}")
        return 0
    if args.remove:
        ok = tts.remove_speaker(args.remove)
        print(f"removed {args.remove!r}" if ok else f"no voice named {args.remove!r}")
        return 0 if ok else 1
    if not args.name or not args.audio:
        print("Provide --name and --audio (or --list / --remove).", file=sys.stderr)
        return 2
    info = tts.enroll_speaker(args.name, args.audio, gender=args.gender,
                              age_group=args.age_group, adapt_steps=args.adapt_steps,
                              texts=args.text)
    print(f"enrolled {args.name!r}: {info}")
    print(f"voices.json updated in {args.model}")
    if args.test:
        tts.tts_to_file(args.test, args.out, voice=args.name)
        print(f"test synthesis -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
