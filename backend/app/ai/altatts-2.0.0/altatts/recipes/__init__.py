"""Ready-made training configs shipped with the package.

    altatts-train --recipe multilingual_callcenter ...
    altatts recipes            # list them

A recipe is a full config.json; CLI flags still override any field.
"""
from __future__ import annotations

import json
import os
from typing import Dict, List

_DIR = os.path.dirname(os.path.abspath(__file__))


def available() -> List[str]:
    return sorted(f[:-5] for f in os.listdir(_DIR) if f.endswith(".json"))


def path_of(name: str) -> str:
    name = name[:-5] if name.endswith(".json") else name
    p = os.path.join(_DIR, name + ".json")
    if not os.path.isfile(p):
        raise KeyError(f"unknown recipe {name!r}; available: {available()}")
    return p


def describe() -> Dict[str, str]:
    out = {}
    for name in available():
        with open(path_of(name), encoding="utf-8") as fh:
            d = json.load(fh)
        t, pr = d.get("text", {}), d.get("privacy", {})
        out[name] = (f"languages={t.get('languages')} prior.steps={d.get('prior', {}).get('steps')} "
                     f"voices={pr.get('plan')} ({pr.get('n_female')}F+{pr.get('n_male')}M per family)")
    return out


def main(argv=None) -> int:
    for name, desc in describe().items():
        print(f"  {name:<28} {desc}")
    return 0
