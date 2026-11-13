"""Statistics over canonical records and the human-readable report."""
from __future__ import annotations

import math
from collections import Counter, defaultdict
from typing import Dict, List, Optional, Sequence

from .spec import Record

_DUR_BINS = [0, 1, 2, 3, 5, 8, 12, 16, 20, 30, 60, 1e9]


def _pct(sorted_vals: List[float], p: float) -> float:
    if not sorted_vals:
        return float("nan")
    k = min(len(sorted_vals) - 1, max(0, int(round(p / 100.0 * (len(sorted_vals) - 1)))))
    return float(sorted_vals[k])


def hours(records: Sequence[Record]) -> float:
    return sum(float(r.get("duration") or 0.0) for r in records) / 3600.0


def duration_summary(values: Sequence[float]) -> Dict:
    vals = sorted(float(v) for v in values if v is not None)
    if not vals:
        return {"n": 0}
    hist = Counter()
    for v in vals:
        for lo, hi in zip(_DUR_BINS[:-1], _DUR_BINS[1:]):
            if lo <= v < hi:
                hist[f"{lo:g}-{hi:g}s" if hi < 1e8 else f">{lo:g}s"] += 1
                break
    return {"n": len(vals), "min": vals[0], "p10": _pct(vals, 10), "median": _pct(vals, 50),
            "mean": sum(vals) / len(vals), "p90": _pct(vals, 90), "max": vals[-1],
            "histogram": dict(hist)}


def dataset_stats(records: Sequence[Record], name: Optional[str] = None) -> Dict:
    """Everything a human wants to know about one corpus (or any record list)."""
    recs = list(records)
    speakers: Dict[str, Dict] = {}
    for r in recs:
        s = speakers.setdefault(str(r.get("speaker")), {"clips": 0, "seconds": 0.0,
                                                        "gender": r.get("gender") or "unknown",
                                                        "age": r.get("age")})
        s["clips"] += 1
        s["seconds"] += float(r.get("duration") or 0.0)
        if r.get("gender") and s["gender"] == "unknown":
            s["gender"] = r["gender"]
    genders = Counter(s["gender"] for s in speakers.values())
    texts = [str(r.get("text") or "") for r in recs]
    chars = sorted(len(t) for t in texts)
    words = sorted(len(t.split()) for t in texts)
    emo = Counter(str(r.get("emotion")).lower() for r in recs if r.get("emotion"))
    n = max(1, len(recs))
    out = {
        "name": name, "clips": len(recs), "hours": round(hours(recs), 2),
        "speakers": len(speakers), "speakers_by_gender": dict(genders),
        "speaker_table": dict(sorted(speakers.items(), key=lambda kv: -kv[1]["seconds"])),
        "duration": duration_summary([r.get("duration") for r in recs]),
        "text": {"chars_median": _pct(chars, 50) if chars else 0, "chars_max": chars[-1] if chars else 0,
                 "words_mean": (sum(words) / len(words)) if words else 0,
                 "words_max": words[-1] if words else 0},
        "languages": dict(Counter(str(r.get("language")) for r in recs)),
        "cross_lingual_share": round(sum(1 for r in recs if r.get("cross_lingual")) / n, 3),
        "emotion": {"coverage": round(sum(1 for r in recs if r.get("emotion")) / n, 3),
                    "labels": dict(emo.most_common()),
                    "intensity_coverage": round(sum(1 for r in recs if r.get("intensity") is not None) / n, 3)},
        "domains": dict(Counter(str(r.get("domain")) for r in recs if r.get("domain")).most_common(12)),
        "sample_rates": dict(Counter(r.get("sample_rate") for r in recs if r.get("sample_rate"))),
        "formats": dict(Counter(str(r.get("format")) for r in recs if r.get("format"))),
        "source_splits": dict(Counter(str(r.get("source_split")) for r in recs if r.get("source_split"))),
    }
    return out


def family_language_totals(records: Sequence[Record]) -> Dict:
    fam: Dict[str, Dict] = defaultdict(lambda: {"clips": 0, "hours": 0.0, "speakers": set(),
                                                "female": set(), "male": set(), "datasets": set()})
    lang: Dict[str, Dict] = defaultdict(lambda: {"clips": 0, "hours": 0.0, "speakers": set()})
    for r in records:
        f = fam[str(r.get("family"))]
        f["clips"] += 1
        f["hours"] += float(r.get("duration") or 0) / 3600
        f["speakers"].add(r.get("speaker"))
        f["datasets"].add(r.get("dataset"))
        if r.get("gender") in ("female", "male"):
            f[r["gender"]].add(r.get("speaker"))
        lg = lang[str(r.get("language"))]
        lg["clips"] += 1
        lg["hours"] += float(r.get("duration") or 0) / 3600
        lg["speakers"].add(r.get("speaker"))
    return {"families": {k: {"clips": v["clips"], "hours": round(v["hours"], 2),
                             "speakers": len(v["speakers"]), "female_speakers": len(v["female"]),
                             "male_speakers": len(v["male"]), "datasets": sorted(v["datasets"])}
                         for k, v in fam.items()},
            "languages": {k: {"clips": v["clips"], "hours": round(v["hours"], 2),
                              "speakers": len(v["speakers"])} for k, v in lang.items()}}


# --------------------------------------------------------------------------- #
#  Report rendering
# --------------------------------------------------------------------------- #
def text_hist(hist: Dict[str, int], width: int = 28) -> List[str]:
    if not hist:
        return []
    total = sum(hist.values()) or 1
    top = max(hist.values()) or 1
    lines = []
    for k, v in hist.items():
        bar = "█" * max(1, int(round(width * v / top))) if v else ""
        lines.append(f"{k:>8} | {bar:<{width}} {v:>7} ({100.0 * v / total:4.1f}%)")
    return lines


def _fmt(v, nd=1):
    if v is None or (isinstance(v, float) and math.isnan(v)):
        return "-"
    return f"{v:.{nd}f}" if isinstance(v, float) else str(v)


def render_report(result) -> str:
    """CombineResult -> markdown."""
    L: List[str] = []
    v = result.version
    L.append(f"# ALTA TTS combined dataset — version {v['version']}")
    L.append("")
    L.append(f"Created {v['created_at']} with altatts {v['altatts_version']} from `{v['data_root']}`.")
    L.append(f"Output: `{result.out_dir}` (audio: {result.options.get('sample_rate')} Hz mono "
             f"{result.options.get('format', 'flac').upper()}).")
    L.append("")
    t = result.totals
    L.append("## Totals (after cleaning, balancing and conversion)")
    L.append("")
    L.append("| split | clips | hours | speakers |")
    L.append("|---|---:|---:|---:|")
    for split in ("train", "dev", "test"):
        s = t["splits"].get(split, {})
        L.append(f"| {split} | {s.get('clips', 0):,} | {_fmt(s.get('hours', 0.0), 2)} | {s.get('speakers', 0)} |")
    L.append(f"| **all** | **{t['clips']:,}** | **{_fmt(t['hours'], 2)}** | **{t['speakers']}** |")
    L.append("")
    L.append("### By language family (voice-plan groups)")
    L.append("")
    L.append("| family | datasets | clips | hours | speakers | female | male |")
    L.append("|---|---|---:|---:|---:|---:|---:|")
    for k, f in sorted(t["families"].items()):
        L.append(f"| {k} | {', '.join(f['datasets'])} | {f['clips']:,} | {f['hours']} | {f['speakers']} | {f['female_speakers']} | {f['male_speakers']} |")
    L.append("")
    L.append("### By language")
    L.append("")
    L.append("| language | clips | hours | speakers |")
    L.append("|---|---:|---:|---:|")
    for k, f in sorted(t["languages"].items()):
        L.append(f"| {k} | {f['clips']:,} | {f['hours']} | {f['speakers']} |")
    L.append("")
    L.append("## Datasets")
    L.append("")
    L.append("| dataset | family | language | role | raw clips | kept | hours raw → kept | speakers (F/M) | median clip | emotion | dev | test |")
    L.append("|---|---|---|---|---:|---:|---|---|---:|---:|---:|---:|")
    for d in result.datasets:
        raw, kept = d["raw"], d["kept"]
        g = kept.get("speakers_by_gender", {})
        L.append(f"| {d['name']} | {d['family']} | {d['language']} | {d['role']} | {raw.get('clips', 0):,} | "
                 f"{kept.get('clips', 0):,} | {_fmt(raw.get('hours'), 1)} → {_fmt(kept.get('hours'), 1)} | "
                 f"{kept.get('speakers', 0)} ({g.get('female', 0)}/{g.get('male', 0)}) | "
                 f"{_fmt(kept.get('duration', {}).get('median'))} s | {kept.get('emotion', {}).get('coverage', 0):.0%} | "
                 f"{d['splits'].get('dev', 0):,} | {d['splits'].get('test', 0):,} |")
    L.append("")
    for d in result.datasets:
        kept = d["kept"]
        L.append(f"### {d['name']} — {d['description']}")
        L.append("")
        if d.get("notes"):
            L.append(f"*{d['notes']}*")
            L.append("")
        L.append(f"- Source: `{d['path']}` (adapter `{d['adapter']}`, license: {d.get('license') or 'n/a'})")
        L.append(f"- Raw: {d['raw'].get('clips', 0):,} clips, {_fmt(d['raw'].get('hours'), 1)} h; "
                 f"kept: {kept.get('clips', 0):,} clips, {_fmt(kept.get('hours'), 1)} h"
                 + (f" (balanced from {_fmt(d.get('hours_before_balance'), 1)} h)" if d.get("hours_before_balance") else ""))
        if d["dropped"]:
            L.append("- Dropped: " + ", ".join(f"{k} {v:,}" for k, v in sorted(d["dropped"].items(), key=lambda kv: -kv[1])))
        dur = kept.get("duration", {})
        if dur.get("n"):
            L.append(f"- Clip length: min {_fmt(dur['min'])} s, median {_fmt(dur['median'])} s, "
                     f"mean {_fmt(dur['mean'])} s, p90 {_fmt(dur['p90'])} s, max {_fmt(dur['max'])} s")
        tx = kept.get("text", {})
        L.append(f"- Text: median {_fmt(tx.get('chars_median'), 0)} chars, mean {_fmt(tx.get('words_mean'))} words, "
                 f"longest {tx.get('chars_max', 0)} chars")
        L.append(f"- Languages: {kept.get('languages')}; cross-lingual clips: {kept.get('cross_lingual_share', 0):.0%}")
        em = kept.get("emotion", {})
        if em.get("labels"):
            L.append(f"- Emotion labels ({em['coverage']:.0%} of clips, intensity on {em['intensity_coverage']:.0%}): {em['labels']}")
        else:
            L.append("- Emotion labels: none (unlabeled slot)")
        if kept.get("domains"):
            L.append(f"- Domains: {kept['domains']}")
        raw_st = d.get("raw", {})
        if raw_st.get("sample_rates"):
            L.append(f"- Source audio: {raw_st.get('formats')} at {raw_st.get('sample_rates')} Hz "
                     f"→ converted to {result.options.get('sample_rate')} Hz {result.options.get('format', 'flac').upper()}")
        if dur.get("histogram"):
            L.append("")
            L.append("```")
            L.extend(text_hist(dur["histogram"]))
            L.append("```")
        st = kept.get("speaker_table", {})
        if st:
            L.append("")
            L.append("| speaker | gender | clips | hours |")
            L.append("|---|---|---:|---:|")
            for name, s in list(st.items())[:12]:
                L.append(f"| {name} | {s['gender']} | {s['clips']:,} | {s['seconds'] / 3600:.2f} |")
            if len(st) > 12:
                L.append(f"| … {len(st) - 12} more | | | |")
        L.append("")
    if result.warnings:
        L.append("## Warnings and recommendations")
        L.append("")
        for w in result.warnings:
            L.append(f"- {w}")
        L.append("")
    if result.voice_plan:
        L.append("## Production-voice plan preview")
        L.append("")
        L.append("| group | languages | female voices | male voices | training speakers (F/M) |")
        L.append("|---|---|---:|---:|---|")
        for g in result.voice_plan:
            L.append(f"| {g['group']} | {', '.join(g['languages'])} | {g['n_female']} | {g['n_male']} | "
                     f"{g['speakers']} ({g['female']}/{g['male']}) |")
        L.append("")
    L.append("## How this version was built")
    L.append("")
    for k, val in sorted(result.options.items()):
        L.append(f"- `{k}` = `{val}`")
    L.append("")
    L.append("Re-run `altatts combine-data` (or the notebook) after adding a dataset to the "
             "registry: the previous version's manifests, report and samples are replaced, "
             "converted audio is reused when the source is unchanged, and the version number "
             "increases.")
    return "\n".join(L)
