"""
The combine pipeline: many corpora -> one versioned ALTATTS training set.

    from altatts.datasets import run, DATASETS
    result = run(DATASETS, out_dir, workers=16)

Steps (each prints progress and lands in the report):
1. **load**      adapter -> canonical records; audio existence; durations and
                 sample rates probed from the file headers when missing
2. **clean**     drop missing/unreadable audio, empty text, clips outside the
                 duration bounds, over-long text, exact duplicates; tag
                 code-switched clips (`language=mixed`, `cross_lingual`)
3. **balance**   per-speaker and per-dataset hour caps (every speaker kept)
4. **gender**    pitch-based gender for speakers without a label; hints verified
5. **split**     train / dev per (dataset, speaker) with a seeded shuffle;
                 `role="test"` datasets go to test only
6. **convert**   every clip -> mono FLAC at one sample rate (parallel,
                 resumable; names are stable so unchanged audio is reused)
7. **write**     manifests, speakers.json, 3 listening samples per dataset,
                 statistics, report.md / report.json, VERSION.json; orphan
                 audio from older versions is deleted
"""
from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
import random
import re
import shutil
import time
from collections import Counter, defaultdict
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Tuple

from .adapters import get_adapter
from .spec import RECORD_KEYS, DatasetSpec, Record, speaker_key
from .stats import dataset_stats, family_language_totals, hours, render_report

_AUDIO_EXT = (".wav", ".flac", ".mp3", ".ogg", ".opus", ".webm", ".m4a", ".aac")
_METADATA_FILES = ("train.jsonl", "dev.jsonl", "test.jsonl", "report.md", "report.json",
                   "speakers.json", "config.json", "VERSION.json", "train.sh",
                   "README_TRAINING.md")


@dataclass
class CombineResult:
    out_dir: str
    version: Dict
    options: Dict
    datasets: List[Dict] = field(default_factory=list)
    totals: Dict = field(default_factory=dict)
    warnings: List[str] = field(default_factory=list)
    voice_plan: List[Dict] = field(default_factory=list)
    manifests: Dict[str, str] = field(default_factory=dict)
    report_path: str = ""
    samples: Dict[str, List[Dict]] = field(default_factory=dict)

    def summary_table(self) -> List[Dict]:
        rows = []
        for d in self.datasets:
            k = d["kept"]
            rows.append({"dataset": d["name"], "family": d["family"], "language": d["language"],
                         "role": d["role"], "raw_clips": d["raw"].get("clips", 0),
                         "kept_clips": k.get("clips", 0), "hours": k.get("hours", 0.0),
                         "speakers": k.get("speakers", 0),
                         "female": k.get("speakers_by_gender", {}).get("female", 0),
                         "male": k.get("speakers_by_gender", {}).get("male", 0),
                         "median_s": round(k.get("duration", {}).get("median", 0) or 0, 2),
                         "emotion_cov": k.get("emotion", {}).get("coverage", 0.0),
                         "train": d["splits"].get("train", 0), "dev": d["splits"].get("dev", 0),
                         "test": d["splits"].get("test", 0)})
        return rows


# --------------------------------------------------------------------------- #
#  1. load
# --------------------------------------------------------------------------- #
def _probe(path: str) -> Tuple[Optional[float], Optional[int], Optional[str]]:
    """(duration_s, sample_rate, format) from the file header; None on failure."""
    try:
        import soundfile as sf
        info = sf.info(path)
        return float(info.frames) / float(info.samplerate), int(info.samplerate), str(info.format).lower()
    except Exception:                                        # noqa: BLE001
        pass
    try:
        import av
        with av.open(path) as c:
            s = c.streams.audio[0]
            dur = float(c.duration) / 1e6 if c.duration else (float(s.duration * s.time_base) if s.duration else None)
            return dur, int(s.rate), str(s.codec_context.name)
    except Exception:                                        # noqa: BLE001
        return None, None, None


def load_dataset(spec: DatasetSpec, root: str, limit: int = 0, probe: bool = True,
                 workers: int = 8, verbose: bool = True) -> List[Record]:
    """Read one corpus into canonical records (no cleaning yet)."""
    adapter = get_adapter(spec.adapter)
    t0 = time.time()
    records: List[Record] = []
    for r in adapter(spec, root):
        r.setdefault("dataset", spec.name)
        r["dataset"] = spec.name
        r["family"] = spec.family
        r["language"] = r.get("language") or spec.language
        r["speaker"] = speaker_key(spec.name, r.get("speaker", "spk0"))
        if r.get("gender"):
            r["gender"] = _norm_gender(r["gender"])
        if not r.get("gender"):
            hint = spec.speaker_genders.get(str(r["speaker"]).split("/", 1)[-1])
            if hint:
                r["gender"] = hint
                r["gender_source"] = "hint"
        else:
            r["gender_source"] = "metadata"
        r["audio_path"] = os.path.abspath(str(r["audio_path"]))
        records.append(r)
        if limit and len(records) >= limit:
            break
    # existence + probing (header reads; threads are enough)
    def _check(r):
        p = r["audio_path"]
        if not os.path.isfile(p):
            r["exists"] = False
            return
        r["exists"] = True
        if probe and (r.get("duration") is None or r.get("sample_rate") is None):
            dur, sr, fmt = _probe(p)
            if dur is not None and r.get("duration") is None:
                r["duration"] = round(dur, 3)
            r["sample_rate"], r["format"] = sr, fmt
            if dur is None and sr is None:
                r["unreadable"] = True
        else:
            r["format"] = os.path.splitext(p)[1].lstrip(".").lower()
    with ThreadPoolExecutor(max_workers=max(1, workers)) as ex:
        list(ex.map(_check, records))
    if verbose:
        n_missing = sum(1 for r in records if not r.get("exists"))
        print(f"[load] {spec.name}: {len(records):,} records, {hours(records):.1f} h, "
              f"{n_missing} missing audio ({time.time() - t0:.0f}s)")
    return records


def _norm_gender(g) -> Optional[str]:
    from ..training.data import normalize_gender
    v = normalize_gender(g)
    return v if v in ("male", "female") else None


# --------------------------------------------------------------------------- #
#  2. clean
# --------------------------------------------------------------------------- #
_EN_WORDS = None


def tag_language(text: str, default: str = "rw") -> Tuple[str, bool]:
    """('mixed', True) when >= 2 words look English/French in a Bantu text."""
    from ..languages import detect_word_language
    words = re.findall(r"[A-Za-zÀ-ɏ']+", text)
    prev, foreign = None, 0
    for w in words:
        prev = detect_word_language(w, ["rw", "en", "fr", "sw"], default, prev)
        if prev in ("en", "fr"):
            foreign += 1
    return ("mixed", True) if foreign >= 2 else (default, False)


def clean(records: Sequence[Record], spec: DatasetSpec) -> Tuple[List[Record], Dict[str, int]]:
    dropped: Counter = Counter()
    seen = set()
    kept: List[Record] = []
    for r in records:
        if not r.get("exists"):
            dropped["missing_audio"] += 1
            continue
        if r.get("unreadable"):
            dropped["unreadable_audio"] += 1
            continue
        text = str(r.get("text") or "").strip()
        if not text or not re.search(r"[A-Za-zÀ-ɏ]", text):
            dropped["empty_text"] += 1
            continue
        if len(text) > spec.max_text_chars:
            dropped["text_too_long"] += 1
            continue
        d = r.get("duration")
        if d is None:
            dropped["no_duration"] += 1
            continue
        if d < spec.min_duration_s:
            dropped["too_short"] += 1
            continue
        if d > spec.max_duration_s:
            dropped["too_long"] += 1
            continue
        key = (r["speaker"], re.sub(r"\s+", " ", text.lower()), round(float(d), 1))
        if key in seen:
            dropped["duplicate"] += 1
            continue
        seen.add(key)
        if spec.language == "mixed" or r.get("language") == "mixed":
            lang, cross = tag_language(text, "rw")
            r["language"] = lang
            r["cross_lingual"] = True          # the speaker reads mixed material
        kept.append(r)
    return kept, dict(dropped)


# --------------------------------------------------------------------------- #
#  3. balance
# --------------------------------------------------------------------------- #
def balance(records: Sequence[Record], spec: DatasetSpec, seed: int = 1234) -> List[Record]:
    """Apply per-speaker and per-dataset hour caps; every speaker survives."""
    if not spec.max_hours and not spec.max_hours_per_speaker:
        return list(records)
    rng = random.Random(seed)
    by_spk: Dict[str, List[Record]] = defaultdict(list)
    for r in records:
        by_spk[r["speaker"]].append(r)
    for spk, recs in by_spk.items():
        rng.shuffle(recs)
        if spec.max_hours_per_speaker:
            budget, out = spec.max_hours_per_speaker * 3600, []
            for r in recs:
                if budget - float(r["duration"]) < 0:
                    continue
                budget -= float(r["duration"])
                out.append(r)
            by_spk[spk] = out
    if not spec.max_hours:
        return [r for recs in by_spk.values() for r in recs]
    # round-robin over speakers so the cap keeps every voice proportionally
    budget = spec.max_hours * 3600
    queues = {s: list(v) for s, v in by_spk.items() if v}
    out: List[Record] = []
    while queues and budget > 0:
        for s in list(queues):
            if not queues[s]:
                del queues[s]
                continue
            r = queues[s].pop()
            if budget - float(r["duration"]) < 0:
                queues.pop(s, None)
                continue
            budget -= float(r["duration"])
            out.append(r)
    return out


# --------------------------------------------------------------------------- #
#  4. gender from pitch
# --------------------------------------------------------------------------- #
def _f0_job(args) -> Tuple[str, Optional[float]]:
    path, = args
    try:
        import numpy as np
        from ..audio import load_audio
        from ..metrics import median_f0
        wav = load_audio(path, 16000)
        f0 = median_f0(np.asarray(wav[: 16000 * 20], dtype=np.float32), 16000)
        return path, (None if np.isnan(f0) else float(f0))
    except Exception:                                        # noqa: BLE001
        return path, None


def detect_genders(records: Sequence[Record], workers: int = 8, clips_per_speaker: int = 8,
                   seed: int = 1234, verbose: bool = True) -> Dict[str, Dict]:
    """Assign a gender to every speaker: metadata > verified hint > pitch.
    Returns {speaker: {gender, source, median_f0}} and updates records."""
    from ..metrics import GENDER_F0_THRESHOLD
    rng = random.Random(seed)
    by_spk: Dict[str, List[Record]] = defaultdict(list)
    for r in records:
        by_spk[r["speaker"]].append(r)
    jobs, owner = [], {}
    for spk, recs in by_spk.items():
        src = recs[0].get("gender_source")
        if src == "metadata" and recs[0].get("gender"):
            continue
        sample = rng.sample(recs, min(clips_per_speaker, len(recs)))
        for r in sample:
            jobs.append((r["audio_path"],))
            owner[r["audio_path"]] = spk
    f0s: Dict[str, List[float]] = defaultdict(list)
    if jobs:
        with ProcessPoolExecutor(max_workers=max(1, workers)) as ex:
            for path, f0 in ex.map(_f0_job, jobs, chunksize=4):
                if f0 is not None:
                    f0s[owner[path]].append(f0)
    table: Dict[str, Dict] = {}
    for spk, recs in by_spk.items():
        g0, src = recs[0].get("gender"), recs[0].get("gender_source")
        entry = {"gender": g0, "source": src, "median_f0": None}
        if spk in f0s:
            med = sorted(f0s[spk])[len(f0s[spk]) // 2]
            pitch_gender = "female" if med >= GENDER_F0_THRESHOLD else "male"
            entry["median_f0"] = round(med, 1)
            if g0 and src == "hint":
                entry["source"] = "hint, confirmed by pitch" if pitch_gender == g0 else "hint, CONTRADICTED by pitch (hint kept)"
            elif not g0:
                entry["gender"], entry["source"] = pitch_gender, "pitch"
        elif not g0:
            entry["gender"], entry["source"] = "unknown", "undetectable"
        for r in recs:
            r["gender"] = entry["gender"]
        table[spk] = entry
        if verbose and entry["source"] not in ("metadata",):
            print(f"[gender] {spk:<40} {entry['gender']:<8} ({entry['source']}"
                  + (f", F0 {entry['median_f0']} Hz" if entry["median_f0"] else "") + ")")
    return table


# --------------------------------------------------------------------------- #
#  5. split
# --------------------------------------------------------------------------- #
def split_records(records: Sequence[Record], spec: DatasetSpec, dev_fraction: float = 0.02,
                  dev_min: int = 2, dev_max: int = 60, seed: int = 1234
                  ) -> Tuple[List[Record], List[Record], List[Record]]:
    if spec.role == "test":
        return [], [], list(records)
    frac = spec.dev_fraction if spec.dev_fraction is not None else dev_fraction
    rng = random.Random(seed)
    by_spk: Dict[str, List[Record]] = defaultdict(list)
    for r in records:
        by_spk[r["speaker"]].append(r)
    train, dev = [], []
    for spk in sorted(by_spk):
        recs = sorted(by_spk[spk], key=lambda r: str(r["id"]))
        rng.shuffle(recs)
        n = len(recs)
        n_dev = int(round(frac * n))
        if n >= 10:
            n_dev = max(dev_min, n_dev)
        elif n >= 4:
            n_dev = max(1, n_dev)
        else:
            n_dev = 0
        n_dev = min(n_dev, dev_max, max(0, n - 1))
        dev.extend(recs[:n_dev])
        train.extend(recs[n_dev:])
    return train, dev, []


# --------------------------------------------------------------------------- #
#  6. convert
# --------------------------------------------------------------------------- #
def stable_name(src: str, rid: str) -> str:
    h = hashlib.sha1(os.path.abspath(src).encode("utf-8")).hexdigest()[:10]
    safe = re.sub(r"[^A-Za-z0-9_-]+", "_", str(rid))[:60]
    return f"{safe}_{h}"


def _convert_job(args) -> Tuple[str, Optional[float], Optional[str]]:
    src, dst, sr, fmt = args
    try:
        import soundfile as sf
        if os.path.isfile(dst) and os.path.getsize(dst) > 44:
            info = sf.info(dst)
            if info.samplerate == sr:
                return dst, float(info.frames) / info.samplerate, None
        import numpy as np
        from ..audio import load_audio
        wav = load_audio(src, sr)
        if len(wav) < sr // 10:
            return dst, None, "decoded audio shorter than 0.1 s"
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        tmp = dst + ".part"
        sf.write(tmp, np.clip(wav, -1.0, 1.0).astype(np.float32), sr,
                 format=fmt.upper(), subtype="PCM_16")
        os.replace(tmp, dst)
        return dst, len(wav) / sr, None
    except Exception as exc:                                 # noqa: BLE001
        return dst, None, f"{type(exc).__name__}: {str(exc)[:120]}"


def convert_audio(records: Sequence[Record], out_dir: str, sample_rate: int = 22050,
                  fmt: str = "flac", workers: int = 8, verbose: bool = True
                  ) -> Tuple[List[Record], Dict[str, int]]:
    """Transcode every record into <out_dir>/audio/<dataset>/<stable>.<fmt>.
    Updates audio_path (relative to out_dir), duration and sample_rate."""
    from tqdm import tqdm
    jobs = []
    for r in records:
        dst = os.path.join(out_dir, "audio", r["dataset"], stable_name(r["audio_path"], r["id"]) + "." + fmt)
        r["_dst"] = dst
        jobs.append((r["audio_path"], dst, sample_rate, fmt))
    kept, failed = [], Counter()
    with ProcessPoolExecutor(max_workers=max(1, workers)) as ex:
        it = ex.map(_convert_job, jobs, chunksize=32)
        for r, (dst, dur, err) in zip(records, tqdm(it, total=len(jobs), unit="clip",
                                                   desc="[convert] audio", dynamic_ncols=True,
                                                   disable=not verbose)):
            if err is not None:
                failed[r["dataset"]] += 1
                r["_error"] = err
                continue
            r["source_audio_path"] = r["audio_path"]
            r["audio_path"] = os.path.relpath(dst, out_dir)
            r["duration"] = round(dur, 3)
            r["sample_rate"] = sample_rate
            r["format"] = fmt
            kept.append(r)
    if verbose and failed:
        print(f"[convert] failed: {dict(failed)}")
    return kept, dict(failed)


# --------------------------------------------------------------------------- #
#  7. write / versioning
# --------------------------------------------------------------------------- #
def pick_samples(records: Sequence[Record], k: int = 3, seed: int = 7) -> List[Record]:
    """k clips spread over speakers (and emotions when present)."""
    rng = random.Random(seed)
    by_spk: Dict[str, List[Record]] = defaultdict(list)
    for r in records:
        by_spk[r["speaker"]].append(r)
    out: List[Record] = []
    spks = sorted(by_spk)
    rng.shuffle(spks)
    i = 0
    while len(out) < min(k, len(records)) and spks:
        spk = spks[i % len(spks)]
        recs = [r for r in by_spk[spk] if r not in out]
        if recs:
            mid = [r for r in recs if 2.0 <= float(r.get("duration") or 0) <= 12.0] or recs
            out.append(rng.choice(mid))
        i += 1
        if i > 10 * k:
            break
    return out


def _bootstrap(out_dir: str, fresh: bool) -> Dict:
    os.makedirs(out_dir, exist_ok=True)
    vpath = os.path.join(out_dir, "VERSION.json")
    prev = None
    if os.path.isfile(vpath):
        with open(vpath, encoding="utf-8") as fh:
            prev = json.load(fh)
    elif os.listdir(out_dir) and not fresh:
        raise SystemExit(f"{out_dir} is not empty and has no VERSION.json -- refusing to "
                         f"delete unknown files. Use --fresh to take the folder over.")
    for f in _METADATA_FILES:
        p = os.path.join(out_dir, f)
        if os.path.isfile(p):
            os.remove(p)
    for d in ("stats", "samples"):
        shutil.rmtree(os.path.join(out_dir, d), ignore_errors=True)
    if fresh:
        shutil.rmtree(os.path.join(out_dir, "audio"), ignore_errors=True)
    return prev or {}


def _prune_orphans(out_dir: str, referenced: set, verbose: bool) -> int:
    audio_root = os.path.join(out_dir, "audio")
    n = 0
    for root, _dirs, files in os.walk(audio_root):
        for f in files:
            p = os.path.join(root, f)
            if p not in referenced:
                os.remove(p)
                n += 1
    for root, dirs, files in os.walk(audio_root, topdown=False):
        if not dirs and not files and root != audio_root:
            os.rmdir(root)
    if verbose and n:
        print(f"[write] removed {n} audio files that belong to no record of this version")
    return n


def _write_jsonl(path: str, records: Sequence[Record]) -> None:
    with open(path, "w", encoding="utf-8") as fh:
        for r in records:
            row = {k: r[k] for k in RECORD_KEYS if r.get(k) is not None}
            for k in ("project", "quality", "takes", "dialogue", "voice_set", "noise_condition",
                      "gender_source"):
                if r.get(k) is not None:
                    row[k] = r[k]
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")


_TRAIN_SH = """#!/usr/bin/env bash
# Train ALTATTS 2 on this dataset version. Paths are relative to this script,
# so the folder can be unzipped anywhere:   bash train.sh runs/callcenter_v2 [extra altatts-train flags]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-runs/callcenter_v2}"
shift || true
command -v altatts-train >/dev/null 2>&1 || { echo "altatts is not installed: pip install 'altatts[av]'"; exit 1; }
ulimit -n 65536 2>/dev/null || true          # DataLoader workers need many open files
altatts doctor --no-smoke || true
exec altatts-train --recipe {recipe} --gpus all \\
    --train-metadata "$HERE/train.jsonl" --val-metadata "$HERE/dev.jsonl" --audio-root "$HERE" \\
    --out "$OUT" "$@"
"""

_README_TRAINING = """# Training kit -- {folder} (version {version})

Everything needed to train is in this folder: `train.jsonl`, `dev.jsonl`, `test.jsonl`,
`audio/` (22.05 kHz FLAC), `report.md` (what is inside) and `train.sh`.

## On the training server

```bash
pip install "altatts[av]"                 # torch is installed for the GPU automatically; then:
altatts doctor --fix                      # repair the torch / CUDA / audio stack if needed
unzip -q {folder}.zip -d /data            # (or: tar xf {folder}.tar)
bash /data/{folder}/train.sh runs/callcenter_v2            # all GPUs, recipe {recipe}
bash /data/{folder}/train.sh runs/callcenter_v2 --gpus 0,1 --batch-size 16   # overrides pass through
```

Watch it:

```bash
tail -f runs/callcenter_v2/logs/train.log      # every log line
cat  runs/callcenter_v2/status.json            # live summary (epoch, ETA, best, per-dataset table)
altatts logs --run runs/callcenter_v2 --png curves.png
tensorboard --logdir runs/callcenter_v2/logs/tensorboard   # pip install tensorboard
```

Validation error is printed per dataset and per language after every epoch; early stopping
(patience 15 epochs on `val_mel_l1`) ends the run when it stops improving; `best.pt` keeps
the best epoch. Resume after an interruption by re-running the same command.

Evaluate and ship:

```bash
altatts-evaluate --model runs/callcenter_v2 --metadata /data/{folder}/test.jsonl \\
    --audio-root /data/{folder} --asr-model /path/altasr --target-wer 0.01 --robustness
altatts package --model runs/callcenter_v2 --out deploy/callcenter --gpu
```

## Making the archive (on the machine that holds the data)

```bash
cd {parent}
zip -0 -r -q {folder}.zip {folder}         # -0 = store only: FLAC is already compressed (fast; zip64 automatic)
sha256sum {folder}.zip > {folder}.zip.sha256
rsync -avP {folder}.zip {folder}.zip.sha256 user@server:/data/
# on the server: sha256sum -c {folder}.zip.sha256 && unzip -q {folder}.zip -d /data
```
`tar -cf {folder}.tar {folder}` is equally fine (faster on Linux); `zip -0 -r -s 4g ...` makes 4 GB parts.
"""


def write_training_kit(out_dir: str, recipe: str = "multilingual_callcenter") -> Dict[str, str]:
    """train.sh + README_TRAINING.md inside the dataset folder."""
    out_dir = os.path.abspath(out_dir)
    folder = os.path.basename(out_dir)
    version = "?"
    vp = os.path.join(out_dir, "VERSION.json")
    if os.path.isfile(vp):
        with open(vp, encoding="utf-8") as fh:
            version = json.load(fh).get("version", "?")
    sh = os.path.join(out_dir, "train.sh")
    with open(sh, "w", encoding="utf-8") as fh:
        fh.write(_TRAIN_SH.replace("{recipe}", recipe))
    os.chmod(sh, 0o755)
    rd = os.path.join(out_dir, "README_TRAINING.md")
    with open(rd, "w", encoding="utf-8") as fh:
        fh.write(_README_TRAINING.replace("{folder}", folder).replace("{version}", str(version))
                 .replace("{recipe}", recipe).replace("{parent}", os.path.dirname(out_dir)))
    return {"train.sh": sh, "README_TRAINING.md": rd}


def run(specs: Sequence[DatasetSpec], out_dir: str, root: Optional[str] = None, *,
        workers: int = 8, seed: int = 1234, dev_fraction: float = 0.02, dev_min: int = 2,
        dev_max: int = 60, sample_rate: int = 22050, fmt: str = "flac",
        limit_per_dataset: int = 0, fresh: bool = False, convert: bool = True,
        detect_gender: bool = True, only: Optional[Sequence[str]] = None,
        verbose: bool = True) -> CombineResult:
    """The whole pipeline. Returns a CombineResult (also used by the notebook)."""
    from .registry import data_root, FAMILIES
    from .. import __version__
    root = root or data_root()
    out_dir = os.path.abspath(out_dir)
    t_start = time.time()
    prev = _bootstrap(out_dir, fresh)
    version = {"version": int(prev.get("version", 0)) + 1,
               "previous_version": prev.get("version"),
               "created_at": _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
               "altatts_version": __version__, "data_root": root}
    options = {"workers": workers, "seed": seed, "dev_fraction": dev_fraction, "dev_min": dev_min,
               "dev_max": dev_max, "sample_rate": sample_rate, "format": fmt,
               "limit_per_dataset": limit_per_dataset, "convert": convert,
               "detect_gender": detect_gender, "families": FAMILIES}
    result = CombineResult(out_dir=out_dir, version=version, options=options)
    if verbose:
        print(f"[combine] version {version['version']} -> {out_dir}")

    # ---- load + clean + balance per dataset ---------------------------------
    per_dataset: Dict[str, List[Record]] = {}
    for spec in specs:
        if not spec.enabled or (only and spec.name not in only):
            if verbose and not spec.enabled:
                print(f"[skip] {spec.name}: disabled ({spec.notes or 'no notes'})")
            continue
        try:
            raw = load_dataset(spec, root, limit=limit_per_dataset, workers=workers, verbose=verbose)
        except Exception as exc:                             # noqa: BLE001
            result.warnings.append(f"{spec.name}: could not be read ({type(exc).__name__}: {exc}); skipped")
            if verbose:
                print(f"[load] {spec.name}: FAILED {exc}")
            continue
        raw_stats = dataset_stats(raw, spec.name)
        kept, dropped = clean(raw, spec)
        hours_before = hours(kept)
        kept = balance(kept, spec, seed)
        info = {"name": spec.name, "family": spec.family, "language": spec.language,
                "role": spec.role, "path": spec.resolved_path(root), "adapter": spec.adapter,
                "description": spec.description, "license": spec.license, "notes": spec.notes,
                "raw": raw_stats, "dropped": dropped,
                "hours_before_balance": round(hours_before, 2) if spec.max_hours or spec.max_hours_per_speaker else None,
                "kept": {}, "splits": {}}
        per_dataset[spec.name] = kept
        result.datasets.append(info)
        if verbose:
            print(f"[clean] {spec.name}: kept {len(kept):,} clips, {hours(kept):.1f} h"
                  + (f" (balanced from {hours_before:.1f} h)" if info["hours_before_balance"] else "")
                  + (f"; dropped {dropped}" if dropped else ""))
    all_records = [r for recs in per_dataset.values() for r in recs]
    if not all_records:
        raise SystemExit("no usable records in any dataset")

    # ---- gender ---------------------------------------------------------------
    if detect_gender:
        if verbose:
            print("[gender] detecting gender from pitch for speakers without a label ...")
        gender_table = detect_genders(all_records, workers=workers, seed=seed, verbose=verbose)
    else:
        gender_table = {}

    # ---- split -------------------------------------------------------------------
    train, dev, test = [], [], []
    spec_by_name = {s.name: s for s in specs}
    for name, recs in per_dataset.items():
        tr, dv, te = split_records(recs, spec_by_name[name], dev_fraction, dev_min, dev_max, seed)
        for r in tr:
            r["split"] = "train"
        for r in dv:
            r["split"] = "dev"
        for r in te:
            r["split"] = "test"
        train += tr
        dev += dv
        test += te

    # ---- convert -------------------------------------------------------------------
    failed_conv: Dict[str, int] = {}
    if convert:
        converted, failed_conv = convert_audio(train + dev + test, out_dir, sample_rate, fmt,
                                               workers, verbose)
        ok = set(id(r) for r in converted)
        train = [r for r in train if id(r) in ok]
        dev = [r for r in dev if id(r) in ok]
        test = [r for r in test if id(r) in ok]
        referenced = {os.path.join(out_dir, r["audio_path"]) for r in train + dev + test}
        _prune_orphans(out_dir, referenced, verbose)
    else:
        for r in train + dev + test:
            r["source_audio_path"] = r["audio_path"]

    # ---- stats per dataset after everything ------------------------------------
    final_by_ds: Dict[str, List[Record]] = defaultdict(list)
    for r in train + dev + test:
        final_by_ds[r["dataset"]].append(r)
    for info in result.datasets:
        recs = final_by_ds.get(info["name"], [])
        info["kept"] = dataset_stats(recs, info["name"])
        info["splits"] = dict(Counter(r["split"] for r in recs))
        if failed_conv.get(info["name"]):
            info["dropped"]["conversion_failed"] = failed_conv[info["name"]]
    all_final = train + dev + test
    totals = {"clips": len(all_final), "hours": round(hours(all_final), 2),
              "speakers": len({r["speaker"] for r in all_final}),
              "splits": {name: {"clips": len(recs), "hours": round(hours(recs), 2),
                                "speakers": len({r["speaker"] for r in recs})}
                         for name, recs in (("train", train), ("dev", dev), ("test", test))}}
    totals.update(family_language_totals(train + dev))
    result.totals = totals

    # ---- warnings / recommendations -------------------------------------------
    w = result.warnings
    for fam, f in totals["families"].items():
        if f["female_speakers"] < 2 or f["male_speakers"] < 2:
            w.append(f"family '{fam}' has {f['female_speakers']} female / {f['male_speakers']} male "
                     f"speakers: the production voice plan needs >= 2 per gender per family; "
                     f"voices will be approximate until more speakers are added.")
    for lang, f in totals["languages"].items():
        if f["speakers"] <= 1:
            w.append(f"language '{lang}' has a single speaker ({f['hours']} h): zero-shot cloning and "
                     f"anonymity for that language rely on the rest of its family.")
    emo_cov = sum(1 for r in train if r.get("emotion")) / max(1, len(train))
    w.append(f"emotion labels cover {emo_cov:.1%} of training clips (EMNS English + any labelled "
             f"Bantu data); other clips use the unlabeled slot.")
    for spk, e in gender_table.items():
        if "CONTRADICTED" in str(e.get("source")):
            w.append(f"speaker {spk}: metadata/hint gender '{e['gender']}' contradicted by pitch "
                     f"({e['median_f0']} Hz) -- check the recordings.")
    for info in result.datasets:
        if info["kept"].get("clips", 0) == 0:
            w.append(f"{info['name']}: no clips survived cleaning -- check the adapter and paths.")
    # voice plan preview
    try:
        from ..config import preset
        from ..training.anonymize import plan_voice_groups
        cfg = preset("base")
        cfg.text.languages = [c for c in ("rw", "en", "fr", "sw")
                              if any(r.get("language") == c for r in train)] or ["rw"]
        cfg.validate()
        groups = plan_voice_groups(cfg)
        by_group = {}
        for g in groups:
            spk = {r["speaker"]: r.get("gender") for r in train
                   if (r.get("language") in g.languages) or (r.get("cross_lingual") and g.cross_lingual)}
            by_group[g.name] = spk
        result.voice_plan = [{"group": g.name, "languages": g.languages, "n_female": g.n_female,
                              "n_male": g.n_male, "speakers": len(by_group[g.name]),
                              "female": sum(1 for v in by_group[g.name].values() if v == "female"),
                              "male": sum(1 for v in by_group[g.name].values() if v == "male")}
                             for g in groups]
    except Exception as exc:                                 # noqa: BLE001
        w.append(f"voice plan preview unavailable: {exc}")

    # ---- write ------------------------------------------------------------------------
    os.makedirs(os.path.join(out_dir, "stats"), exist_ok=True)
    for name, recs in (("train", train), ("dev", dev), ("test", test)):
        p = os.path.join(out_dir, f"{name}.jsonl")
        _write_jsonl(p, recs)
        result.manifests[name] = p
    speakers = {}
    for r in all_final:
        s = speakers.setdefault(r["speaker"], {"dataset": r["dataset"], "family": r["family"],
                                               "gender": r.get("gender"), "clips": 0, "hours": 0.0,
                                               "languages": Counter(), "age": r.get("age")})
        s["clips"] += 1
        s["hours"] += float(r["duration"]) / 3600
        s["languages"][str(r.get("language"))] += 1
    for s in speakers.values():
        s["hours"] = round(s["hours"], 3)
        s["languages"] = dict(s["languages"])
    with open(os.path.join(out_dir, "speakers.json"), "w", encoding="utf-8") as fh:
        json.dump({"speakers": speakers, "gender_detection": gender_table}, fh, ensure_ascii=False, indent=1)
    for info in result.datasets:
        with open(os.path.join(out_dir, "stats", f"{info['name']}.json"), "w", encoding="utf-8") as fh:
            json.dump(info, fh, ensure_ascii=False, indent=1)
    # listening samples
    for name, recs in final_by_ds.items():
        picks = pick_samples(recs, 3, seed)
        sdir = os.path.join(out_dir, "samples", name)
        os.makedirs(sdir, exist_ok=True)
        entries = []
        for i, r in enumerate(picks, 1):
            src = os.path.join(out_dir, r["audio_path"]) if convert else r["audio_path"]
            dst = os.path.join(sdir, f"sample_{i}{os.path.splitext(src)[1]}")
            try:
                shutil.copy2(src, dst)
            except OSError:
                continue
            entries.append({"file": os.path.relpath(dst, out_dir), "text": r["text"],
                            "speaker": r["speaker"], "gender": r.get("gender"),
                            "language": r.get("language"), "emotion": r.get("emotion"),
                            "intensity": r.get("intensity"), "duration": r.get("duration"),
                            "split": r.get("split")})
        with open(os.path.join(sdir, "samples.json"), "w", encoding="utf-8") as fh:
            json.dump(entries, fh, ensure_ascii=False, indent=1)
        result.samples[name] = entries
    with open(os.path.join(out_dir, "config.json"), "w", encoding="utf-8") as fh:
        json.dump({"options": options, "datasets": [s.to_dict() for s in specs]}, fh,
                  ensure_ascii=False, indent=1)
    version["datasets"] = [{"name": d["name"], "role": d["role"], "raw_clips": d["raw"].get("clips", 0),
                            "kept_clips": d["kept"].get("clips", 0), "hours": d["kept"].get("hours", 0)}
                           for d in result.datasets]
    version["totals"] = {"clips": totals["clips"], "hours": totals["hours"], "speakers": totals["speakers"],
                         "splits": totals["splits"]}
    version["elapsed_s"] = round(time.time() - t_start, 1)
    with open(os.path.join(out_dir, "VERSION.json"), "w", encoding="utf-8") as fh:
        json.dump(version, fh, ensure_ascii=False, indent=1)
    write_training_kit(out_dir, options.get("recipe", "multilingual_callcenter"))
    md = render_report(result)
    result.report_path = os.path.join(out_dir, "report.md")
    with open(result.report_path, "w", encoding="utf-8") as fh:
        fh.write(md)
    with open(os.path.join(out_dir, "report.json"), "w", encoding="utf-8") as fh:
        json.dump({"version": version, "totals": totals, "datasets": result.datasets,
                   "warnings": result.warnings, "voice_plan": result.voice_plan,
                   "options": options}, fh, ensure_ascii=False, indent=1)
    if verbose:
        s = totals["splits"]
        print(f"[done] version {version['version']}: train {s['train']['clips']:,} clips "
              f"({s['train']['hours']} h), dev {s['dev']['clips']:,} ({s['dev']['hours']} h), "
              f"test {s['test']['clips']:,} ({s['test']['hours']} h); {totals['speakers']} speakers "
              f"-> {out_dir} ({version['elapsed_s']}s)")
        print(f"[done] report: {result.report_path}")
        print(f"[done] training kit: {os.path.join(out_dir, 'train.sh')} (see README_TRAINING.md)")
        for line in result.warnings:
            print(f"[note] {line}")
    return result
