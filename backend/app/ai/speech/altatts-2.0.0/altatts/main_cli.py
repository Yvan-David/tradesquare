#!/usr/bin/env python3
"""
The ``altatts`` umbrella command.

    altatts doctor [--fix]          environment diagnosis / repair
    altatts --doctor                same as `altatts doctor`
    altatts --doctor-fix            same as `altatts doctor --fix`
    altatts synthesize ...          text -> speech        (altatts-synthesize)
    altatts clone --reference X ... speak in a cloned voice
    altatts enroll ...              add a voice from audio (altatts-enroll)
    altatts voices list|build ...   manage voices.json
    altatts prepare ...             prepare data          (altatts-prepare-data)
    altatts segment ...             split long recordings (altatts-segment)
    altatts train ...               train / fine-tune     (altatts-train)
    altatts evaluate ...            metrics incl. WER     (altatts-evaluate)
    altatts benchmark ...           compare checkpoints   (altatts-benchmark)
    altatts export ...              ONNX export           (altatts-export)
    altatts serve --model X         HTTP + WebSocket API  (altatts-serve)
    altatts package --model X --out D   Docker deployment folder
    altatts --version

The dedicated ``altatts-*`` commands remain available and unchanged.
"""
from __future__ import annotations

import sys

_SUBCOMMANDS = {
    "doctor": ("altatts.env.doctor", "Diagnose (and --fix) the environment"),
    "synthesize": ("altatts.inference.synthesize", "Text -> speech"),
    "tts": ("altatts.inference.synthesize", "Alias of synthesize"),
    "clone": ("altatts.inference.synthesize",
              "Speak in a cloned voice (--reference clip.wav)"),
    "enroll": ("altatts.speaker.enroll_cli", "Add a voice from a few clips"),
    "voices": ("altatts.voices_cli", "List / build / remove voices"),
    "prepare": ("altatts.training.prepare", "Prepare dataset metadata"),
    "prepare-data": ("altatts.training.prepare", "Alias of prepare"),
    "segment": ("altatts.training.segment", "Split long recordings"),
    "train": ("altatts.training.train", "Train or fine-tune a model"),
    "evaluate": ("altatts.inference.evaluate", "Objective metrics + WER gate"),
    "benchmark": ("altatts.benchmark", "Compare checkpoints"),
    "export": ("altatts.export", "Export to ONNX"),
    "serve": ("altatts.serving", "Serve the model as an HTTP/WebSocket API"),
    "package": ("altatts.deploy", "Create a Docker deployment folder (API)"),
    "recipes": ("altatts.recipes", "List ready-made training configs"),
    "combine-data": ("altatts.datasets.cli", "Combine many corpora into one versioned training set"),
    "logs": ("altatts.training.logging", "Summarise a run: epochs table, status, curves PNG"),
}


def _usage() -> str:
    lines = ["usage: altatts <command> [options]   |   altatts --doctor[-fix]",
             "", "commands:"]
    for name, (_mod, help_) in _SUBCOMMANDS.items():
        lines.append(f"  {name:<14} {help_}")
    lines.append("")
    lines.append("Run `altatts <command> --help` for the options of a command.")
    return "\n".join(lines)


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or argv[0] in ("-h", "--help"):
        print(_usage())
        return 0
    if argv[0] in ("--version", "-V", "version"):
        from . import __version__
        print(f"altatts {__version__}")
        return 0
    if argv[0] == "--doctor":
        argv = ["doctor"] + argv[1:]
    elif argv[0] == "--doctor-fix":
        argv = ["doctor", "--fix"] + argv[1:]
    cmd, rest = argv[0], argv[1:]
    entry = _SUBCOMMANDS.get(cmd)
    if entry is None:
        print(f"altatts: unknown command {cmd!r}\n\n{_usage()}", file=sys.stderr)
        return 2
    import importlib
    module = importlib.import_module(entry[0])
    rc = module.main(rest)
    return int(rc or 0)


if __name__ == "__main__":
    raise SystemExit(main())
