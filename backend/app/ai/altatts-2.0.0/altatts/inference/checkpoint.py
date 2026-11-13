"""Checkpoint folder I/O.

A trained ALTATTS voice is a folder (mirroring ALTASR's convention):

    my-voice/
        config.json       full Config (model.version 1 = ALTATTS 0.1, 2 = ALTATTS 2)
        tokenizer.json    character vocabulary (+ special tokens, languages)
        speakers.json     training speakers: name -> {id, gender, n_clips, ...}
        voices.json       anonymized default voices + enrolled voices (v2)
        model.pt          inference weights (generator, no posterior encoder)
        lexicon.json      optional custom pronunciations
        checkpoint.pt / best.pt   full training state (optional; resume)

Both generations load through the same function; a v1 folder builds the
exact legacy network.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Tuple

from ..config import Config, load_config
from ..text import CharTokenizer, load_tokenizer
from ..training.data import SpeakerRegistry
from .voices import VoiceBank

_WEIGHT_FILES = ("model.pt", "best.pt", "checkpoint.pt")


@dataclass
class CheckpointBundle:
    model: object
    cfg: Config
    tokenizer: CharTokenizer
    speakers: SpeakerRegistry
    voices: VoiceBank
    folder: str
    weight_path: str


def load_checkpoint_bundle(folder: str, device: str = "auto") -> CheckpointBundle:
    import torch
    from ..utils import resolve_device
    from ..model import build_model

    folder = os.path.expanduser(folder)
    for name in ("config.json", "tokenizer.json", "speakers.json"):
        if not os.path.isfile(os.path.join(folder, name)):
            raise FileNotFoundError(
                f"{name} not found in {folder!r}. Expected a checkpoint folder "
                "written by altatts-train (config.json + tokenizer.json + "
                "speakers.json + model.pt).")

    cfg = load_config(os.path.join(folder, "config.json"))
    tokenizer = load_tokenizer(os.path.join(folder, "tokenizer.json"))
    speakers = SpeakerRegistry.load(os.path.join(folder, "speakers.json"))
    voices = VoiceBank.load(folder)

    weight_path = None
    for name in _WEIGHT_FILES:
        p = os.path.join(folder, name)
        if os.path.isfile(p):
            weight_path = p
            break
    if weight_path is None:
        raise FileNotFoundError(f"No weights (model.pt) found in {folder!r}.")

    dev = torch.device(resolve_device(device))
    model = build_model(cfg, len(tokenizer))
    state = torch.load(weight_path, map_location="cpu", weights_only=True)
    if "net_g" in state:                      # full training checkpoint
        state = state["net_g"]
    missing, unexpected = model.load_state_dict(state, strict=False)
    # Inference weights legitimately omit the posterior encoder (enc_q.*).
    real_missing = [k for k in missing if not k.startswith("enc_q.")]
    if real_missing or unexpected:
        raise RuntimeError(
            f"Checkpoint/model mismatch in {weight_path!r}: "
            f"missing={real_missing[:5]} unexpected={list(unexpected)[:5]}. "
            f"If this is an ALTATTS 0.1 folder, make sure config.json has no "
            f"'model.version' key (legacy) or re-save it with altatts 0.1.")
    model.remove_weight_norm()                # fuse for faster inference
    model.to(dev).eval()
    return CheckpointBundle(model, cfg, tokenizer, speakers, voices, folder,
                            weight_path)


def ensure_posterior_weights(model, folder: str) -> bool:
    """Few-shot adaptation needs the posterior encoder (enc_q), which the
    inference-only model.pt omits. Load it from checkpoint.pt / best.pt when
    present; return False when no full checkpoint exists."""
    import torch
    for name in ("best.pt", "checkpoint.pt", "checkpoint_step.pt"):
        path = os.path.join(folder, name)
        if not os.path.isfile(path):
            continue
        state = torch.load(path, map_location="cpu", weights_only=False)
        sd = state.get("net_g", state)
        enc_q = {k: v for k, v in sd.items() if k.startswith("enc_q.")}
        if not enc_q:
            continue
        missing, unexpected = model.load_state_dict(enc_q, strict=False)
        if not unexpected:
            return True
    return False


def load_checkpoint_folder(folder: str, device: str = "auto"
                           ) -> Tuple[object, Config, CharTokenizer, SpeakerRegistry]:
    """Load (model, config, tokenizer, speakers) -- the ALTATTS 0.1 signature.
    Use :func:`load_checkpoint_bundle` to also get the voice bank."""
    b = load_checkpoint_bundle(folder, device)
    return b.model, b.cfg, b.tokenizer, b.speakers
