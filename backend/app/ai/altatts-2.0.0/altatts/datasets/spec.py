"""Dataset specification and the canonical record."""
from __future__ import annotations

import os
from dataclasses import dataclass, field, asdict
from typing import Dict, List, Optional

#: canonical record keys written to the manifests (order kept)
RECORD_KEYS = ("id", "audio_path", "text", "speaker", "gender", "age", "language",
               "family", "dataset", "emotion", "intensity", "domain", "duration",
               "cross_lingual", "source_split", "sample_rate")

Record = Dict[str, object]


@dataclass
class DatasetSpec:
    """One source corpus. ``adapter`` names a reader in ``adapters.py``;
    ``options`` are passed to it. Everything else drives the pipeline."""
    name: str                              # short id: manifest `dataset` field + audio sub-folder
    path: str                              # root folder (absolute, or relative to the data root)
    adapter: str                           # reader function name
    language: str                          # rw | en | fr | sw | mixed
    family: str                            # bantu | english | french (voice-plan group)
    description: str = ""
    license: str = ""
    options: Dict = field(default_factory=dict)
    enabled: bool = True
    role: str = "train"                    # train (-> train/dev splits) | test (held out)
    max_hours: Optional[float] = None      # cap on the dataset (all speakers kept)
    max_hours_per_speaker: Optional[float] = None
    min_duration_s: float = 1.0
    max_duration_s: float = 20.0
    max_text_chars: int = 600
    dev_fraction: Optional[float] = None   # override the global dev fraction
    speaker_genders: Dict[str, str] = field(default_factory=dict)   # hints, verified by pitch
    notes: str = ""

    def resolved_path(self, root: str) -> str:
        return self.path if os.path.isabs(self.path) else os.path.join(root, self.path)

    def to_dict(self) -> Dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: Dict) -> "DatasetSpec":
        valid = {f.name for f in cls.__dataclass_fields__.values()}
        return cls(**{k: v for k, v in d.items() if k in valid})


def speaker_key(dataset: str, speaker: str) -> str:
    """Globally unique speaker name: '<dataset>/<speaker>'."""
    return f"{dataset}/{str(speaker).strip()}"
