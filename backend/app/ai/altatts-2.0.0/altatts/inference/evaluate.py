"""``altatts-evaluate`` -- score a trained voice with standard TTS metrics.

For every test utterance the model synthesizes the text (with the speaker
who recorded the reference clip -- or, for v2 models, with that speaker's
voice CLONED from the reference clip when ``--clone`` is set), then measures:

    mcd_db        Mel-Cepstral Distortion with DTW (lower = closer timbre)
    f0_rmse_hz    pitch accuracy on co-voiced frames (lower = better prosody)
    vuv_error     voiced/unvoiced decision error rate
    pmos          predicted MOS 1-5 (torchaudio SQUIM subjective; if available)
    rtf           real-time factor (synthesis seconds / audio seconds)
    gender_match  does the synthesized F0 match the requested voice's gender
    spk_sim       speaker similarity: cosine between the reference encoder's
                  embeddings of the real and the synthesized clip (v2)
    asr_wer/cer   intelligibility: transcribe the synthesized audio with an
                  ALTASR model and compare to the input text (needs
                  ``pip install altatts[asr]`` and --asr-model)

``--target-wer 0.01`` turns the run into a gate (exit code 3 when the
corpus WER is above the target) -- the production acceptance criterion.
``--robustness`` adds a built-in set of hard sentences (long numbers,
account codes, code-switching, long sentences) scored by WER only.

Usage:
    altatts-evaluate --model runs/kinyarwanda \
        --metadata data/tts_test.json --audio-root data/ \
        --out eval_report.json --asr-model path/to/altasr --target-wer 0.01
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from collections import defaultdict
from typing import Dict, List, Optional

import numpy as np

from ..utils import quiet_warnings, clear_terminal

ROBUSTNESS_SENTENCES = [
    "Konti yawe ifite amafaranga 1,250,000 kuri uyu munsi.",
    "Nimero ya telefoni ni 0788123456, kanda rimwe kugira ngo ukomeze.",
    "Kode yawe ni 48213, ntuyihe undi muntu.",
    "Twakiriye ubwishyu bwa FRW 2500 ku itariki ya 12.",
    "Murakoze guhamagara. Umukozi wacu araza kubasubiza mu minota 5.",
    "Igiciro cyazamutseho 12.5% ugereranyije n'umwaka ushize.",
    "Serivisi zacu zikora kuva saa mbiri za mu gitondo kugeza saa kumi n'ebyiri z'umugoroba, buri munsi w'icyumweru, harimo n'iminsi mikuru.",
    "Mu gihe ufite ikibazo, hamagara 3030 cyangwa wandike kuri serivisi@banki.rw.",
]


def _asr_transcribe(transcriber, syn, sr):
    from ..audio import resample
    hyp = transcriber.transcribe(resample(syn, sr, 16000), sample_rate=16000)
    if isinstance(hyp, dict):
        hyp = hyp.get("text", "")
    return str(getattr(hyp, "text", hyp))


def evaluate(
    model_dir: str,
    metadata: List[str],
    audio_root: str,
    out_path: Optional[str] = None,
    asr_model: Optional[str] = None,
    max_utterances: Optional[int] = None,
    device: str = "auto",
    verbose: bool = True,
    clone: bool = False,
    robustness: bool = False,
    steps: Optional[int] = None,
    seed: Optional[int] = 1234,
) -> Dict:
    from tqdm import tqdm

    from ..audio import load_audio, AudioDecodeError, mel_spectrogram_torch
    from ..metrics import (
        mcd, f0_metrics, median_f0, GENDER_F0_THRESHOLD,
        predicted_mos, corpus_tts_metrics,
    )
    from ..text import normalize_text, strip_punctuation, plain_text
    from ..training.data import load_records, resolve_audio_path
    from .synthesizer import Synthesizer

    tts = Synthesizer.from_pretrained(model_dir, device=device)
    cfg = tts.cfg
    sr = cfg.audio.sample_rate

    records = load_records(metadata, cfg) if metadata else []
    if max_utterances:
        records = records[:max_utterances]
    if not records and not robustness:
        raise SystemExit("No usable evaluation records.")
    cfg.data.audio_root = audio_root or cfg.data.audio_root

    transcriber = None
    if asr_model:
        try:
            from altasr import Transcriber
            transcriber = Transcriber.from_pretrained(asr_model, device=device)
        except ImportError:
            print("[evaluate] altasr not installed -- skipping ASR WER/CER. "
                  "Install with: pip install altatts[asr]")

    def norm_ref(text: str) -> str:
        t = cfg.text
        return strip_punctuation(normalize_text(
            plain_text(text), t.keep_punctuation, t.punctuation, t.expand_numbers,
            languages=t.languages, keep_tags=False))

    speaker_gender = {name: info.get("gender")
                      for name, info in tts.speakers.voices().items()}
    can_clone = clone and tts.capabilities()["voice_cloning"]
    pairs: List[Dict] = []
    per_voice: Dict[str, List[Dict]] = defaultdict(list)
    per_dataset: Dict[str, List[Dict]] = defaultdict(list)
    per_language: Dict[str, List[Dict]] = defaultdict(list)
    import torch
    for rec in tqdm(records, desc="evaluate", disable=not verbose):
        path = resolve_audio_path(cfg.data.audio_root, rec["audio_path"])
        try:
            ref = load_audio(path, target_sr=sr)
        except (AudioDecodeError, Exception) as e:            # noqa: BLE001
            if verbose:
                print(f"[evaluate] skipping {rec['audio_path']}: {e}")
            continue

        voice = rec.get("speaker") or rec.get("gender") or "female"
        emotion = None
        if rec.get("emotion_id") and tts.capabilities()["emotions"]:
            emotion = cfg.style.emotions[rec["emotion_id"] - 1]
        kw = dict(voice=str(voice), steps=steps, seed=seed)
        if emotion:
            kw.update(emotion=emotion, intensity=rec.get("intensity"))
        if can_clone:
            kw["reference_audio"] = (ref, sr)
        elif str(voice) not in tts.speakers.table and str(voice) not in tts.voice_bank:
            kw["voice"] = rec.get("gender") or "female"
        if rec.get("language"):
            kw["language"] = rec["language"]
        t0 = time.perf_counter()
        try:
            syn, _ = tts.tts(rec["text"], **kw)
        except Exception as e:                                # noqa: BLE001
            if verbose:
                print(f"[evaluate] synthesis failed for {rec.get('id')}: {e}")
            continue
        dt = time.perf_counter() - t0

        m: Dict = {"id": rec.get("id"), "voice": str(voice),
                   "dataset": rec.get("dataset"), "language": rec.get("language")}
        m["mcd_db"] = mcd(ref, syn, sr)
        m.update(f0_metrics(ref, syn, sr))
        m["rtf"] = dt / max(len(syn) / sr, 1e-6)
        m["pmos"] = predicted_mos(syn, sr)

        want = rec.get("gender") or speaker_gender.get(str(voice))
        if want in ("male", "female"):
            f0 = median_f0(syn, sr)
            if not np.isnan(f0):
                got = "female" if f0 >= GENDER_F0_THRESHOLD else "male"
                m["gender_match"] = 1.0 if got == want else 0.0

        if tts.capabilities()["voice_cloning"]:
            try:
                a = cfg.audio
                with torch.inference_mode():
                    def emb(w):
                        y = torch.from_numpy(np.ascontiguousarray(w, dtype=np.float32)).unsqueeze(0).to(tts.device)
                        mel = mel_spectrogram_torch(y, sr, a.n_fft, a.hop_length, a.win_length,
                                                    a.n_mels, a.mel_fmin, a.mel_fmax)
                        return tts.model.embed_reference(mel).squeeze(0).float().cpu().numpy()
                    e1, e2 = emb(ref), emb(syn)
                m["spk_sim"] = float(np.dot(e1, e2) / (np.linalg.norm(e1) * np.linalg.norm(e2) + 1e-8))
            except Exception:                                 # noqa: BLE001
                pass

        if transcriber is not None:
            try:
                hyp = _asr_transcribe(transcriber, syn, sr)
                m["ref_text"] = norm_ref(rec["text"])
                m["hyp_text"] = strip_punctuation(hyp.lower())
            except Exception as e:                            # noqa: BLE001
                if verbose:
                    print(f"[evaluate] ASR failed: {e}")

        pairs.append(m)
        per_voice[str(voice)].append(m)
        if rec.get("dataset"):
            per_dataset[str(rec["dataset"])].append(m)
        if rec.get("language"):
            per_language[str(rec["language"])].append(m)

    robust_rows: List[Dict] = []
    if robustness:
        voices = [v for v in ("female", "male") if v in tts.voices()] or list(tts.voices())[:1]
        for text in tqdm(ROBUSTNESS_SENTENCES, desc="robustness", disable=not verbose):
            for v in voices:
                t0 = time.perf_counter()
                try:
                    syn, _ = tts.tts(text, voice=v, steps=steps, seed=seed)
                except Exception as e:                        # noqa: BLE001
                    robust_rows.append({"text": text, "voice": v, "error": str(e)})
                    continue
                row = {"text": text, "voice": v,
                       "rtf": (time.perf_counter() - t0) / max(len(syn) / sr, 1e-6),
                       "seconds": round(len(syn) / sr, 2)}
                if transcriber is not None:
                    try:
                        row["ref_text"] = norm_ref(text)
                        row["hyp_text"] = strip_punctuation(
                            _asr_transcribe(transcriber, syn, sr).lower())
                    except Exception:                         # noqa: BLE001
                        pass
                robust_rows.append(row)

    summary = corpus_tts_metrics(pairs) if pairs else {}
    sims = [p["spk_sim"] for p in pairs if "spk_sim" in p]
    if sims:
        summary["spk_sim"] = float(np.mean(sims))
    report = {
        "model": os.path.abspath(model_dir),
        "capabilities": tts.capabilities(),
        "n_requested": len(records),
        "cloned_from_reference": bool(can_clone),
        "summary": summary,
        "per_voice": {v: corpus_tts_metrics(ps) for v, ps in per_voice.items()},
        "per_dataset": {v: corpus_tts_metrics(ps) for v, ps in per_dataset.items()},
        "per_language": {v: corpus_tts_metrics(ps) for v, ps in per_language.items()},
        "utterances": pairs,
    }
    if robustness:
        report["robustness"] = {"rows": robust_rows}
        if any("ref_text" in r for r in robust_rows):
            report["robustness"]["summary"] = corpus_tts_metrics(
                [r for r in robust_rows if "ref_text" in r])

    if out_path:
        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)

    if verbose:
        print("\n==== ALTATTS evaluation ====")
        for k, v in summary.items():
            print(f"  {k:<14} {v:.4f}" if isinstance(v, float) else f"  {k:<14} {v}")
        for voice, s in report["per_voice"].items():
            line = "  ".join(f"{k}={v:.3f}" for k, v in s.items() if isinstance(v, float))
            print(f"  [{voice}] {line}")
        for label, table in (("dataset", report["per_dataset"]), ("language", report["per_language"])):
            if len(table) > 1:
                print(f"  -- by {label} --")
                for k, s in table.items():
                    line = "  ".join(f"{kk}={vv:.3f}" for kk, vv in s.items()
                                     if isinstance(vv, float) and kk in ("mcd_db", "spk_sim", "asr_wer", "asr_cer", "pmos"))
                    print(f"  [{k}] n={s.get('n_utterances')} {line}")
        if robustness and "summary" in report["robustness"]:
            rs = report["robustness"]["summary"]
            print(f"  robustness set: WER={rs.get('asr_wer', float('nan')):.4f} "
                  f"CER={rs.get('asr_cer', float('nan')):.4f}")
        if out_path:
            print(f"Full report -> {out_path}")
    return report


def main(argv: Optional[List[str]] = None) -> int:
    quiet_warnings()
    clear_terminal()
    p = argparse.ArgumentParser(prog="altatts-evaluate",
                                description="Evaluate an ALTATTS voice")
    p.add_argument("--model", required=True, help="Checkpoint folder")
    p.add_argument("--metadata", nargs="+", default=None,
                   help="Test metadata (ALTASR / ALTATTS format)")
    p.add_argument("--audio-root", default="")
    p.add_argument("--out", default=None, help="JSON report path")
    p.add_argument("--asr-model", default=None,
                   help="ALTASR checkpoint for intelligibility WER/CER")
    p.add_argument("--target-wer", type=float, default=None,
                   help="Fail (exit 3) when corpus WER exceeds this, e.g. 0.01")
    p.add_argument("--clone", action="store_true",
                   help="v2: synthesize each utterance with the speaker cloned "
                        "from its reference clip (measures zero-shot cloning)")
    p.add_argument("--robustness", action="store_true",
                   help="Also score the built-in hard-sentence set (numbers, "
                        "codes, long sentences) by WER")
    p.add_argument("--steps", type=int, default=None)
    p.add_argument("--max-utterances", type=int, default=None)
    p.add_argument("--device", default="auto")
    args = p.parse_args(argv)
    if not args.metadata and not args.robustness:
        print("Provide --metadata (and/or --robustness).", file=sys.stderr)
        return 2
    report = evaluate(args.model, args.metadata or [], args.audio_root, args.out,
                      args.asr_model, args.max_utterances, args.device,
                      clone=args.clone, robustness=args.robustness,
                      steps=args.steps)
    if args.target_wer is not None:
        w = report["summary"].get("asr_wer")
        if w is None:
            print("[evaluate] --target-wer set but no WER was computed "
                  "(pass --asr-model)", file=sys.stderr)
            return 2
        if w > args.target_wer:
            print(f"[evaluate] GATE FAILED: WER {w:.4f} > target {args.target_wer}",
                  file=sys.stderr)
            return 3
        print(f"[evaluate] gate passed: WER {w:.4f} <= {args.target_wer}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
