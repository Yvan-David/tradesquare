"""``altatts-synthesize`` -- synthesize speech from the command line.

    altatts-synthesize --model runs/kinyarwanda \
        --text "Muraho! Murakaza neza." --voice female --out hello.wav

    # expressive controls (ALTATTS 2 models)
    altatts-synthesize --model runs/kinyarwanda --voice male_young \
        --emotion happy --intensity 0.7 \
        --text "Twishimiye kubafasha [pause:0.5] murakoze!" --out hi.wav

    # instant voice cloning from a reference clip
    altatts-synthesize --model runs/kinyarwanda --reference agent.wav \
        --text "Muraho neza." --out cloned.wav

    # telephony-rate batch output
    altatts-synthesize --model runs/kinyarwanda --text-file prompts.txt \
        --voice male --sample-rate 8000 --out-dir prompts_8k/
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from typing import List, Optional

from ..utils import quiet_warnings, clear_terminal


def build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="altatts-synthesize",
                                description="Synthesize speech with ALTATTS")
    p.add_argument("--model", required=True, help="Checkpoint folder")
    p.add_argument("--text", default=None, help="Text to speak (tags allowed)")
    p.add_argument("--text-file", default=None,
                   help="File with one utterance per line")
    p.add_argument("--voice", default="female",
                   help='voice name, "male"/"female", speaker name, or a '
                        'reference audio path (see --list-voices)')
    p.add_argument("--reference", nargs="+", default=None, metavar="AUDIO",
                   help="Clone the speaker of these clip(s) (zero-shot)")
    p.add_argument("--emotion", default=None,
                   help="neutral | happy | sad | angry | calm | excited | ...")
    p.add_argument("--intensity", type=float, default=None, help="0..1")
    p.add_argument("--language", default=None,
                   help="Text language (rw/en/fr/sw); mixed text is detected "
                        "word by word")
    p.add_argument("--sample-rate", type=int, default=None,
                   help="Output rate: 8000 telephony, 16000 ASR, 22050 native, "
                        "44100/48000 media")
    p.add_argument("--speed", type=float, default=1.0,
                   help="Speaking rate (>1 faster, <1 slower)")
    p.add_argument("--noise-scale", type=float, default=0.667,
                   help="Prosody variability (0=flat .. 1=varied)")
    p.add_argument("--steps", type=int, default=None,
                   help="MeanFlow sampling steps (1 fastest .. 4 default)")
    p.add_argument("--cfg-scale", type=float, default=None)
    p.add_argument("--seed", type=int, default=None, help="Deterministic output")
    p.add_argument("--pause-scale", type=float, default=1.0)
    p.add_argument("--prior", choices=["meanflow", "flow"], default=None)
    p.add_argument("--out", default="out.wav", help="Output WAV (single text)")
    p.add_argument("--out-dir", default=None,
                   help="Output folder (with --text-file)")
    p.add_argument("--device", default="auto")
    p.add_argument("--lexicon", default=None,
                   help="JSON file of custom pronunciations (word -> how to "
                        "say it); overrides the model folder's lexicon.json")
    p.add_argument("--explain", action="store_true",
                   help="Print normalization, detected languages/entities and "
                        "the synthesis plan before synthesizing")
    p.add_argument("--list-voices", action="store_true",
                   help="Print available voices and exit")
    p.add_argument("--capabilities", action="store_true",
                   help="Print what this checkpoint supports and exit")
    return p


def main(argv: Optional[List[str]] = None) -> None:
    quiet_warnings()
    clear_terminal()
    args = build_argparser().parse_args(argv)

    from .synthesizer import Synthesizer

    tts = Synthesizer.from_pretrained(args.model, device=args.device)
    if args.lexicon:
        from ..lexicon import Lexicon
        tts.lexicon = Lexicon.load(args.lexicon)

    if args.capabilities:
        print(json.dumps(tts.capabilities(), indent=2, ensure_ascii=False))
        return
    if args.list_voices:
        print("Available voices:")
        for name, info in tts.voices().items():
            desc = ", ".join(f"{k}={v}" for k, v in info.items()
                             if k in ("gender", "age_group", "kind", "alias_of"))
            print(f"  {name:<24} {desc}")
        caps = tts.capabilities()
        if caps["voice_cloning"]:
            print("Cloning: pass --reference <clip.wav> or enroll with altatts-enroll")
        return

    kwargs = dict(voice=args.voice, sample_rate=args.sample_rate,
                  speed=args.speed, noise_scale=args.noise_scale,
                  emotion=args.emotion, intensity=args.intensity,
                  language=args.language, steps=args.steps,
                  cfg_scale=args.cfg_scale, seed=args.seed,
                  pause_scale=args.pause_scale, prior=args.prior)
    if args.reference:
        kwargs["speaker_embedding"] = tts.embed_speaker(args.reference)

    if args.text_file:
        out_dir = args.out_dir or "synthesized"
        os.makedirs(out_dir, exist_ok=True)
        with open(args.text_file, "r", encoding="utf-8") as f:
            lines = [ln.strip() for ln in f if ln.strip()]
        t0 = time.perf_counter()
        for i, line in enumerate(lines):
            path = os.path.join(out_dir, f"{i:05d}.wav")
            tts.tts_to_file(line, path, **kwargs)
            print(f"[{i + 1}/{len(lines)}] {path}")
        dt = time.perf_counter() - t0
        print(f"Done: {len(lines)} files in {dt:.1f}s -> {out_dir}/")
        return

    if not args.text:
        print("Provide --text or --text-file (or --list-voices).",
              file=sys.stderr)
        sys.exit(2)

    if args.explain:
        print(json.dumps(tts.analyze(args.text, args.language), indent=2,
                         ensure_ascii=False))
    t0 = time.perf_counter()
    wav, sr = tts.tts(args.text, **kwargs)
    dt = time.perf_counter() - t0
    from ..audio import save_wav
    save_wav(args.out, wav, sr)
    dur = len(wav) / sr
    print(f"Wrote {args.out}  ({dur:.2f}s audio @ {sr} Hz, "
          f"synthesized in {dt:.2f}s, RTF={dt / max(dur, 1e-6):.3f})")


if __name__ == "__main__":
    main()
