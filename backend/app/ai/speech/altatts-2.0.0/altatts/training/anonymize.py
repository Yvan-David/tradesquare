"""
Anonymized default (production) voices -- privacy by construction.

Problem: a TTS deployed to the public should not reproduce the voice of any
individual who recorded the training data unless they opted in. Trained
speaker embeddings ARE those individuals. ALTATTS therefore ships every
model with *synthetic* production voices built from **mixtures** of trained
speakers and **verified** to be far from every training speaker in
speaker-encoder space (the x-vector averaging + verification approach of the
VoicePrivacy challenge).

The voice plan
--------------
Voices are organised in **groups by language family** (``privacy`` config):

* ``plan="auto"``: one group per family present in ``text.languages`` --
  ``french`` (fr), ``english`` (en), ``bantu`` (rw, sw) -- each with
  ``n_female`` + ``n_male`` voices (default 2 + 2). A rw+en+fr+sw model
  ships **12 production voices**; a single-language model ships one group
  with ``single_family_per_gender`` (3) voices per gender spread over the
  age groups.
* ``plan="custom"``: ``privacy.groups`` lists the groups explicitly.

Training speakers are assigned to the family that owns most of their clips;
**cross-lingual (code-switching) speakers join the family of the model's
primary language** (the Bantu group for a Kinyarwanda-first model), so the
Bantu voices speak Kinyarwanda, Swahili and mixed sentences natively while
a tiny Swahili pool is backed by the Kinyarwanda speakers.

Algorithm (per voice)
---------------------
1. Candidates = the group's speakers of the requested gender (fallback: the
   group's speakers, then every speaker of that gender, flagged
   ``approximate``). Base = mean of their table embeddings; a single
   candidate is pre-mixed with the gender centroid so no base IS a speaker.
   The k-th voice of a gender starts from a different seeded mixture.
2. Loop (max ``max_iterations``): synthesize a test sentence in the group's
   language with the candidate vector, embed the result with the model's
   reference encoder, compare (cosine) with every training speaker's
   reference embedding measured on real clips.
3. Accept when max similarity <= threshold AND the synthesized pitch matches
   the requested gender; otherwise push the vector along a seeded random
   direction of growing magnitude plus a pull toward the global mean.
4. Threshold = ``max_similarity`` when set, else the midpoint between the
   measured intra-speaker and inter-speaker similarities (a voice must be
   at least as different from every speaker as two speakers are from each
   other); degenerate statistics fall back to a fixed 0.5.

Output: ``voices.json`` (voices ``<group>_<gender>_<k>``, aliases ``female``,
``male``, ``<lang>_female``, ``<group>_male``, ...) and
``privacy_report.json``. Deterministic given ``privacy.seed``. Re-run any
time with ``altatts voices build --model <folder>``.
"""
from __future__ import annotations

import json
import os
import random
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np
import torch

from ..audio import mel_spectrogram_torch, resample
from ..config import Config
from ..languages import LANGUAGE_ALIASES, canonical_code
from ..metrics import GENDER_F0_THRESHOLD, median_f0
from ..inference.voices import VoiceBank
from .data import AGE_GROUPS, SpeakerRegistry

_TEST_SENTENCES = {
    "rw": "muraho neza. amakuru yawe? turabafasha uyu munsi.",
    "en": "hello and welcome. how can we help you today?",
    "fr": "bonjour et bienvenue. comment pouvons-nous vous aider aujourd'hui?",
    "sw": "habari na karibu. tunaweza kukusaidia vipi leo?",
}


# --------------------------------------------------------------------------- #
#  Voice plan (pure functions -- unit tested without a model)
# --------------------------------------------------------------------------- #
@dataclass
class VoiceGroup:
    name: str
    languages: List[str]
    n_female: int = 2
    n_male: int = 2
    ages: List[str] = field(default_factory=lambda: list(AGE_GROUPS))
    cross_lingual: bool = False          # receives code-switching speakers

    def n_voices(self) -> int:
        return self.n_female + self.n_male


def plan_voice_groups(cfg: Config) -> List[VoiceGroup]:
    """The voice plan for this config's languages."""
    p = cfg.privacy
    langs = [canonical_code(c, c) for c in cfg.text.languages] or ["rw"]
    primary = langs[0]
    ages = list(p.age_groups) or list(AGE_GROUPS)
    if p.plan == "custom" and p.groups:
        groups = []
        for g in p.groups:
            groups.append(VoiceGroup(
                name=str(g["name"]),
                languages=[canonical_code(c, c) for c in g.get("languages", [])],
                n_female=int(g.get("n_female", p.n_female)),
                n_male=int(g.get("n_male", p.n_male)),
                ages=list(g.get("ages", ages)),
                cross_lingual=bool(g.get("cross_lingual", False))))
        if not any(g.cross_lingual for g in groups):
            for g in groups:
                if primary in g.languages:
                    g.cross_lingual = True
                    break
        return groups
    # auto: one group per family that has at least one trained language
    families = {name: [canonical_code(c, c) for c in codes]
                for name, codes in p.families.items()}
    present: List[VoiceGroup] = []
    covered = set()
    for name, codes in families.items():
        mine = [c for c in langs if c in codes]
        if mine:
            present.append(VoiceGroup(name, mine, p.n_female, p.n_male, ages))
            covered.update(mine)
    for c in langs:                       # a language outside every family
        if c not in covered:
            present.append(VoiceGroup(c, [c], p.n_female, p.n_male, ages))
    if len(present) == 1:                 # single-language model
        n = max(1, p.single_family_per_gender)
        present[0].n_female = present[0].n_male = n
    for g in present:
        if primary in g.languages:
            g.cross_lingual = True
            break
    return present


def assign_speakers(speakers: SpeakerRegistry, groups: Sequence[VoiceGroup],
                    primary: str) -> Dict[str, List[int]]:
    """group name -> speaker ids. A speaker goes to the group owning most of
    its clips; cross-lingual speakers go to the ``cross_lingual`` group."""
    out: Dict[str, List[int]] = {g.name: [] for g in groups}
    home = next((g for g in groups if g.cross_lingual), groups[0] if groups else None)
    by_lang: Dict[str, VoiceGroup] = {}
    for g in groups:
        for c in g.languages:
            by_lang.setdefault(c, g)
    for name, e in speakers.table.items():
        langs = e.get("languages") or {}
        target = None
        if e.get("cross_lingual") and home is not None:
            target = home
        elif langs:
            shares: Dict[str, int] = {}
            for code, n in langs.items():
                g = by_lang.get(canonical_code(code, code))
                if g is not None:
                    shares[g.name] = shares.get(g.name, 0) + int(n)
            if shares:
                target = next(g for g in groups if g.name == max(shares, key=shares.get))
        if target is None:
            target = by_lang.get(primary) or home or groups[0]
        out[target.name].append(e["id"])
    return out


def voice_name(group: str, gender: str, k: int) -> str:
    return f"{group}_{gender}_{k}"


# --------------------------------------------------------------------------- #
#  Measurements
# --------------------------------------------------------------------------- #
def _cos(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-8))


def _mel_of(wav: np.ndarray, cfg: Config, device) -> torch.Tensor:
    a = cfg.audio
    y = torch.from_numpy(np.ascontiguousarray(wav, dtype=np.float32)).unsqueeze(0).to(device)
    return mel_spectrogram_torch(y, a.sample_rate, a.n_fft, a.hop_length,
                                 a.win_length, a.n_mels, a.mel_fmin, a.mel_fmax)


@torch.no_grad()
def _synth(model, cfg, tokenizer, text: str, lang: str, g: np.ndarray, device,
           generator: torch.Generator) -> np.ndarray:
    ids, lids = tokenizer.encode_full(text, cfg.text.intersperse_blank,
                                      default_language=lang,
                                      detect_languages=cfg.text.language_detection)
    x = torch.LongTensor(ids).unsqueeze(0).to(device)
    xl = torch.LongTensor([x.size(1)]).to(device)
    lang_t = torch.LongTensor(lids).unsqueeze(0).to(device)
    gt = torch.from_numpy(np.asarray(g, dtype=np.float32)).unsqueeze(0).to(device)
    y, _, _ = model.infer(x, xl, g=gt, lang=lang_t, generator=generator,
                          steps=max(2, cfg.prior.steps))
    return y.squeeze().float().cpu().numpy()


@torch.no_grad()
def measure_speakers(model, cfg, speakers: SpeakerRegistry, dataset, device,
                     max_speakers: int = 60, clips_per_speaker: int = 4
                     ) -> Tuple[Dict[int, np.ndarray], Dict[int, float], Dict[str, float]]:
    """Reference-encoder embeddings of real clips per speaker (mean), median
    F0 per speaker, and intra/inter-speaker similarity statistics."""
    refs: Dict[int, List[np.ndarray]] = {}
    f0s: Dict[int, List[float]] = {}
    rng = random.Random(cfg.privacy.seed)
    index: Dict[int, List[int]] = dict(dataset.by_speaker) if dataset.by_speaker else {}
    if not index:
        for i, it in enumerate(dataset.items):
            index.setdefault(it[2], []).append(i)
    sids = sorted(index)
    rng.shuffle(sids)
    for sid in sids[:max_speakers]:
        idxs = list(index.get(sid, []))
        rng.shuffle(idxs)
        for i in idxs[:clips_per_speaker]:
            try:
                y = dataset._audio(dataset.items[i][0])
            except Exception:                                # noqa: BLE001
                continue
            mel = _mel_of(y.squeeze(0).numpy(), cfg, device)
            emb = model.embed_reference(mel).squeeze(0).float().cpu().numpy()
            refs.setdefault(sid, []).append(emb)
            wav16 = resample(y.squeeze(0).numpy(), cfg.audio.sample_rate, 16000)
            f0 = median_f0(wav16, 16000)
            if not np.isnan(f0):
                f0s.setdefault(sid, []).append(float(f0))
    intra, inter = [], []
    means = {s: np.mean(v, axis=0) for s, v in refs.items() if v}
    for s, v in refs.items():
        for i in range(len(v)):
            for j in range(i + 1, len(v)):
                intra.append(_cos(v[i], v[j]))
    keys = list(means)
    for i in range(len(keys)):
        for j in range(i + 1, len(keys)):
            inter.append(_cos(means[keys[i]], means[keys[j]]))
    stats = {"intra_speaker_mean": float(np.mean(intra)) if intra else float("nan"),
             "inter_speaker_mean": float(np.mean(inter)) if inter else float("nan"),
             "n_speakers_measured": len(means)}
    return means, {s: float(np.median(v)) for s, v in f0s.items() if v}, stats


def _age_assignments(speakers: SpeakerRegistry, f0_by_sid: Dict[int, float]
                     ) -> Tuple[Dict[int, str], str]:
    table = speakers.table
    with_meta = {e["id"]: e["age_group"] for e in table.values()
                 if e.get("age_group") in AGE_GROUPS}
    if with_meta:
        return with_meta, "metadata"
    if not f0_by_sid:
        return {}, "none"
    out: Dict[int, str] = {}
    for gender in ("male", "female", "unknown"):
        sids = [e["id"] for e in table.values()
                if e.get("gender") == gender and e["id"] in f0_by_sid]
        if not sids:
            continue
        sids.sort(key=lambda s: -f0_by_sid[s])          # higher pitch = younger
        n = len(sids)
        for k, s in enumerate(sids):
            out[s] = AGE_GROUPS[min(2, (k * 3) // max(1, n))]
    return out, "f0_proxy"


def _pick_sentence(group: VoiceGroup, cfg: Config, dataset) -> Tuple[str, str]:
    """(text, language) in one of the group's languages."""
    if cfg.privacy.test_sentence:
        return cfg.privacy.test_sentence[:160], group.languages[0]
    if dataset is not None:
        for it in dataset.items:
            if it[5] in group.languages and len(it[1]) > 12:
                return it[1][:160], it[5]
    for c in group.languages:
        if c in _TEST_SENTENCES:
            return _TEST_SENTENCES[c], c
    return _TEST_SENTENCES["rw"], group.languages[0]


# --------------------------------------------------------------------------- #
#  Builder
# --------------------------------------------------------------------------- #
@torch.no_grad()
def build_default_voices(model, cfg: Config, speakers: SpeakerRegistry,
                         tokenizer, out_dir: str, dataset=None, device=None,
                         verbose: bool = True, voices: Optional[VoiceBank] = None
                         ) -> VoiceBank:
    """Build the anonymized production voices and write voices.json."""
    if model.legacy:
        raise RuntimeError("default-voice builder needs an ALTATTS 2 model")
    device = device or next(model.parameters()).device
    was_training = model.training
    model.eval()
    p = cfg.privacy
    bank = voices or VoiceBank.load(out_dir)
    for name, e in list(bank.voices.items()):          # keep enrolled voices
        if e.get("kind") == "anonymized":
            bank.remove(name)

    groups = plan_voice_groups(cfg)
    primary = canonical_code(cfg.text.languages[0], cfg.text.languages[0])
    membership = assign_speakers(speakers, groups, primary)

    table = model.emb_g.weight.detach().float().cpu().numpy()      # (S, gin)
    sid_gender = {e["id"]: e.get("gender", "unknown") for e in speakers.table.values()}
    n_spk = min(table.shape[0], (max(sid_gender) + 1) if sid_gender else table.shape[0])
    table = table[:n_spk]
    global_mean = table.mean(axis=0)

    refs, f0_by_sid, stats = ({}, {}, {"n_speakers_measured": 0})
    if dataset is not None and model.has_cloning:
        refs, f0_by_sid, stats = measure_speakers(model, cfg, speakers, dataset, device)
    if not refs:
        refs = {s: table[s] for s in range(n_spk)}
        stats.setdefault("note", "no audio available: similarity measured "
                                 "against table embeddings")
    threshold = p.max_similarity
    threshold_source = "config"
    if threshold <= 0:
        intra, inter = stats.get("intra_speaker_mean"), stats.get("inter_speaker_mean")
        usable = (intra is not None and inter is not None
                  and not (np.isnan(intra) or np.isnan(inter))
                  and inter < 0.9 and (intra - inter) > 0.05)
        if usable:
            threshold = float((intra + inter) / 2.0)
            threshold_source = "adaptive (midpoint of intra/inter-speaker similarity)"
        else:
            threshold = 0.5
            threshold_source = ("fixed 0.5 (speaker statistics degenerate: the "
                                "encoder does not separate speakers yet -- "
                                "train longer)" if intra is not None else
                                "fixed 0.5 (no audio statistics)")
    ages, age_source = _age_assignments(speakers, f0_by_sid)
    rng = np.random.default_rng(p.seed)
    report = {"plan": [{"group": g.name, "languages": g.languages,
                        "n_female": g.n_female, "n_male": g.n_male,
                        "speakers": len(membership.get(g.name, [])),
                        "cross_lingual_home": g.cross_lingual} for g in groups],
              "threshold": threshold, "threshold_source": threshold_source,
              "similarity_stats": stats, "age_source": age_source, "voices": {}}

    for gi, group in enumerate(groups):
        members = [s for s in membership.get(group.name, []) if s < n_spk]
        sentence, lang = _pick_sentence(group, cfg, dataset)
        for gender, count in (("female", group.n_female), ("male", group.n_male)):
            same_group = [s for s in members if sid_gender.get(s) == gender]
            any_gender = [s for s in range(n_spk) if sid_gender.get(s) == gender]
            pool = same_group or members or any_gender or list(range(n_spk))
            approximate = not same_group
            gender_pool = any_gender or list(range(n_spk))
            gender_centroid = table[gender_pool].mean(axis=0)
            for k in range(1, count + 1):
                name = voice_name(group.name, gender, k)
                age = group.ages[(k - 1) % len(group.ages)] if group.ages else None
                cands = ([s for s in pool if ages.get(s) == age] or pool) if age else pool
                # the k-th voice mixes the candidates with different seeded
                # weights so two voices of the same gender differ
                w = rng.dirichlet(np.ones(len(cands)) * (2.0 if k == 1 else 0.7))
                base = (table[cands] * w[:, None]).sum(axis=0)
                if len(cands) == 1 and len(gender_pool) > 1:
                    base = 0.5 * base + 0.5 * gender_centroid
                direction = rng.standard_normal(base.shape[0]).astype(np.float32)
                direction /= np.linalg.norm(direction) + 1e-8
                scale = float(np.linalg.norm(base)) + 1e-6
                e = base.copy()
                gen = torch.Generator(device=device if str(device) != "cpu" else "cpu")
                gen.manual_seed(p.seed + 1000 * gi + 100 * k + (0 if gender == "female" else 7))
                result = {"group": group.name, "gender": gender, "age_group": age,
                          "built_from": len(cands), "approximate": approximate,
                          "iterations": 0, "passed": False}
                for it in range(max(1, p.max_iterations)):
                    wav = _synth(model, cfg, tokenizer, sentence, lang, e, device, gen)
                    if model.has_cloning:
                        emb = model.embed_reference(_mel_of(wav, cfg, device)).squeeze(0).float().cpu().numpy()
                        sims = {int(s): _cos(emb, r) for s, r in refs.items()}
                    else:
                        sims = {int(s): _cos(e, r) for s, r in refs.items()}
                    max_sim = max(sims.values()) if sims else 0.0
                    f0 = median_f0(resample(wav, cfg.audio.sample_rate, 16000), 16000)
                    got = None if np.isnan(f0) else ("female" if f0 >= GENDER_F0_THRESHOLD else "male")
                    gender_ok = got in (None, gender) or not any_gender
                    result.update({"iterations": it + 1, "max_similarity": max_sim,
                                   "closest_speaker_id": (max(sims, key=sims.get) if sims else None),
                                   "median_f0_hz": None if np.isnan(f0) else round(float(f0), 1),
                                   "gender_detected": got,
                                   "reason": ("ok" if max_sim <= threshold and gender_ok else
                                              "too similar to a training speaker" if max_sim > threshold
                                              else "pitch does not match the requested gender")})
                    if max_sim <= threshold and gender_ok:
                        result["passed"] = True
                        break
                    alpha = 0.15 * (it + 1) * scale
                    beta = min(0.6, 0.1 * (it + 1))
                    e = base + alpha * direction + beta * (global_mean - base)
                    if not gender_ok and any_gender:
                        e = 0.5 * (e + gender_centroid)
                bank.add(name, e, kind="anonymized", gender=gender, age_group=age,
                         group=group.name, languages=list(group.languages),
                         age_source=age_source, approximate=approximate or None,
                         privacy={"max_similarity": round(result.get("max_similarity", 0.0), 4),
                                  "threshold": round(threshold, 4),
                                  "passed": result["passed"],
                                  "iterations": result["iterations"]})
                report["voices"][name] = result
                if verbose:
                    print(f"[voices] {name:<18} from {len(cands)} speaker(s)"
                          f"{' (approximate)' if approximate else ''}: similarity "
                          f"{result.get('max_similarity', 0):.3f} / {threshold:.3f} after "
                          f"{result['iterations']} iteration(s) -> "
                          f"{'OK' if result['passed'] else 'FAILED: ' + result['reason']}"
                          + (f", F0 {result['median_f0_hz']} Hz" if result.get('median_f0_hz') else ""))
        # aliases for this group
        for gender in ("female", "male"):
            first = voice_name(group.name, gender, 1)
            if first not in bank.voices:
                continue
            bank.set_alias(f"{group.name}_{gender}", first)
            for c in group.languages:
                bank.set_alias(f"{c}_{gender}", first)
                for alias, code in LANGUAGE_ALIASES.items():
                    if code == c and len(alias) == 3:
                        bank.set_alias(f"{alias}_{gender}", first)
            if group.cross_lingual:                 # primary-language group
                bank.set_alias(gender, first)
                if group.n_female == len(group.ages) and len(group.ages) == 3:
                    names = {"25-45": "adult", "16-25": "young", "45+": "senior"}
                    for k, age in enumerate(group.ages, 1):
                        bank.set_alias(f"{gender}_{names.get(age, age)}",
                                       voice_name(group.name, gender, k))
    if "female" not in bank.aliases:
        for gender in ("female", "male"):
            cand = next((n for n in bank.voices if n.endswith(f"_{gender}_1")), None)
            if cand:
                bank.set_alias(gender, cand)
    bank.meta.update({"default_voices_built": True, "threshold": threshold,
                      "threshold_source": threshold_source, "age_source": age_source,
                      "n_training_speakers": n_spk,
                      "plan": [{"group": g.name, "languages": g.languages,
                                "n_female": g.n_female, "n_male": g.n_male}
                               for g in groups]})
    bank.save(out_dir)
    with open(os.path.join(out_dir, "privacy_report.json"), "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, ensure_ascii=False)
    if verbose:
        n_ok = sum(v["passed"] for v in report["voices"].values())
        print(f"[voices] plan: " + ", ".join(
            f"{g.name}({'+'.join(g.languages)}: {g.n_female}F/{g.n_male}M, "
            f"{len(membership.get(g.name, []))} spk)" for g in groups))
        print(f"[voices] threshold {threshold:.3f} [{threshold_source}]; "
              f"{n_ok}/{len(report['voices'])} production voices verified anonymous "
              f"-> {os.path.join(out_dir, 'voices.json')} (details: privacy_report.json)")
    if was_training:
        model.train()
    return bank
