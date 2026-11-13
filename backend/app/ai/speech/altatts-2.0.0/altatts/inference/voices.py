"""
``voices.json`` -- the voice bank of a model folder.

Two kinds of entries live here, both as plain style vectors (``gin_channels``
floats) that the synthesizer feeds to the model instead of a trained speaker
id:

* **anonymized default voices** built after training (3 female + 3 male,
  three age groups), verified to be far from every training speaker in
  speaker-encoder space -- what callers get when they ask for ``"female"``
  or ``"male"`` without enrolling anyone (see ``training/anonymize.py``);
* **enrolled voices** -- ``Synthesizer.enroll_speaker`` / ``altatts-enroll``
  embed a few seconds of someone's audio and store the result under a name,
  so a call center can add agents without any training.

Format::

    {"version": 2,
     "aliases": {"female": "female_adult", "male": "male_adult"},
     "voices": {
        "female_adult": {"embedding": [...], "gender": "female",
                         "age_group": "25-45", "kind": "anonymized", ...},
        "agent_claire": {"embedding": [...], "gender": "female",
                         "kind": "enrolled", "source": ["a.wav", "b.wav"]}}}
"""
from __future__ import annotations

import json
import os
import time
from typing import Dict, List, Optional

import numpy as np

VOICES_FILE = "voices.json"


class VoiceBank:
    def __init__(self, data: Optional[Dict] = None):
        data = data or {}
        self.version = int(data.get("version", 2))
        self.aliases: Dict[str, str] = dict(data.get("aliases", {}))
        self.voices: Dict[str, Dict] = dict(data.get("voices", {}))
        self.meta: Dict = dict(data.get("meta", {}))

    # -- persistence ---------------------------------------------------------- #
    @classmethod
    def load(cls, path: str) -> "VoiceBank":
        if os.path.isdir(path):
            path = os.path.join(path, VOICES_FILE)
        if not os.path.isfile(path):
            return cls()
        with open(path, "r", encoding="utf-8") as fh:
            return cls(json.load(fh))

    def save(self, path: str) -> str:
        if os.path.isdir(path):
            path = os.path.join(path, VOICES_FILE)
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump({"version": self.version, "aliases": self.aliases,
                       "voices": self.voices, "meta": self.meta}, fh,
                      ensure_ascii=False)
        os.replace(tmp, path)
        return path

    # -- access --------------------------------------------------------------- #
    def __len__(self) -> int:
        return len(self.voices)

    def __contains__(self, name: str) -> bool:
        return name in self.voices or name in self.aliases

    def names(self) -> List[str]:
        return list(self.voices)

    def resolve(self, name: str) -> Optional[Dict]:
        """Follow aliases; None when unknown."""
        seen = set()
        while name in self.aliases and name not in seen:
            seen.add(name)
            name = self.aliases[name]
        return self.voices.get(name)

    def embedding(self, name: str) -> Optional[np.ndarray]:
        e = self.resolve(name)
        if e is None:
            return None
        return np.asarray(e["embedding"], dtype=np.float32)

    def add(self, name: str, embedding, kind: str = "enrolled", **meta) -> Dict:
        emb = np.asarray(embedding, dtype=np.float32).reshape(-1)
        entry = {"embedding": [round(float(v), 6) for v in emb], "kind": kind,
                 "created": time.strftime("%Y-%m-%dT%H:%M:%S")}
        entry.update({k: v for k, v in meta.items() if v is not None})
        self.voices[name] = entry
        return entry

    def remove(self, name: str) -> bool:
        removed = self.voices.pop(name, None) is not None
        for a, target in list(self.aliases.items()):
            if target == name:
                del self.aliases[a]
        return removed

    def set_alias(self, alias: str, target: str) -> None:
        self.aliases[alias] = target

    def public(self, include_embeddings: bool = False) -> Dict[str, Dict]:
        """Listing for ``Synthesizer.voices()``: raw embeddings hidden."""
        out: Dict[str, Dict] = {}
        for name, e in self.voices.items():
            d = {k: v for k, v in e.items() if include_embeddings or k != "embedding"}
            out[name] = d
        for a, t in self.aliases.items():
            tgt = self.resolve(a)
            if tgt is not None:
                out[a] = {"alias_of": t, "gender": tgt.get("gender"),
                          "kind": tgt.get("kind")}
        return out
