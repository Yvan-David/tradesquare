"""High-level synthesis API.

    from altatts import Synthesizer

    tts = Synthesizer.from_pretrained("runs/kinyarwanda")
    wav, sr = tts.tts("Muraho! Amakuru yawe?", voice="female")
    tts.tts_to_file("Murakoze guhamagara.", "out.wav",
                    voice="male", sample_rate=8000)

Every ALTATTS 0.1 call keeps working unchanged. ALTATTS 2 adds optional,
keyword-only controls::

    tts.tts(text, voice="female_young", emotion="happy", intensity=0.7)
    tts.tts("Muraho [pause:0.6] murakoze. [laugh]", voice="male")
    tts.tts(text, reference_audio="agent.wav")            # zero-shot cloning
    tts.enroll_speaker("agent_claire", ["a.wav", "b.wav"])  # persisted
    tts.tts(text, voice="agent_claire", language="rw", steps=4, seed=7)

Voices
------
``voice`` accepts, in this order: an enrolled or default voice from
``voices.json`` (``"female"``, ``"male"``, ``"female_young"``,
``"male_senior"``, ``"agent_claire"``, ...), a training speaker name, the
legacy gender aliases on a v1 model, or a path to a reference audio file
(instant clone). Default voices are anonymized mixtures that match no
training speaker.

Sample rates
------------
The model synthesizes at its native rate (22 050 Hz by default) and the
output is resampled to whatever ``sample_rate`` you ask for: 8000 for
telephony/G.711, 16000 for ASR pipelines, 44100/48000 for media.
"""

from __future__ import annotations

import os
import warnings
from typing import Dict, List, Optional, Sequence, Tuple, Union

import numpy as np

from ..config import Config
from ..text import (CharTokenizer, Chunk, Silence, normalize_text,
                    plain_text, plan_chunks)
from ..tags import canonical_emotion
from ..audio import (resample, peak_normalize, save_wav, wav_bytes, to_pcm16,
                     to_mulaw, to_alaw)
from ..training.data import SpeakerRegistry, emotion_id_of
from .checkpoint import load_checkpoint_bundle
from .voices import VoiceBank

_AUDIO_EXT = (".wav", ".flac", ".mp3", ".ogg", ".opus", ".m4a", ".webm", ".aac")


class Synthesizer:
    """Text -> waveform for a trained ALTATTS checkpoint folder."""

    def __init__(self, model, cfg: Config, tokenizer: CharTokenizer,
                 speakers: SpeakerRegistry, device: str = "auto",
                 voices: Optional[VoiceBank] = None):
        import torch
        from ..utils import resolve_device

        self.cfg = cfg
        self.tokenizer = tokenizer
        self.speakers = speakers
        self.device = torch.device(resolve_device(device))
        if self.device.type == "cpu":
            from ..utils import ensure_cpu_conv_sanity
            ensure_cpu_conv_sanity(verbose=False)
        self.model = model.to(self.device).eval()
        self.native_sr = cfg.audio.sample_rate
        self.lexicon = None            # optional custom pronunciations
        self.voice_bank = voices if voices is not None else VoiceBank()
        self.folder: Optional[str] = None
        self._folder = None            # 0.1 attribute name
        self._warned: set = set()
        self._emotion_counts: Optional[Dict[str, int]] = None

    # ------------------------------------------------------------------ #
    @classmethod
    def from_pretrained(cls, folder: str, device: str = "auto") -> "Synthesizer":
        """Load a checkpoint folder written by ``altatts-train``."""
        b = load_checkpoint_bundle(folder, device)
        synth = cls(b.model, b.cfg, b.tokenizer, b.speakers, device, voices=b.voices)
        from ..lexicon import load_lexicon_if_exists
        synth.lexicon = load_lexicon_if_exists(b.folder)
        synth.folder = synth._folder = b.folder
        summary = os.path.join(b.folder, "training_summary.json")
        if os.path.isfile(summary):
            try:
                import json
                synth._emotion_counts = json.load(open(summary, encoding="utf-8")).get("emotion_counts")
            except Exception:                                # noqa: BLE001
                pass
        return synth

    # ------------------------------------------------------------------ #
    #  Introspection
    # ------------------------------------------------------------------ #
    def capabilities(self) -> Dict:
        """What this checkpoint can do."""
        tok = self.tokenizer
        return {
            "generation": self.cfg.generation,
            "model_version": self.cfg.model.version,
            "voice_cloning": bool(getattr(self.model, "has_cloning", False)),
            "emotions": (list(self.cfg.style.emotions)
                         if getattr(self.model, "has_emotions", False) else []),
            "emotions_seen_in_training": (
                [e for e, n in (self._emotion_counts or {}).items() if n and e != "unlabeled"]
                if self._emotion_counts else None),
            "languages": list(tok.languages),
            "pause_token": tok.pause_id is not None,
            "nonverbal_tokens": tok.known_nonverbals(),
            "prior": self.cfg.prior.type if not self.cfg.is_legacy else "flow",
            "default_voices": [n for n, e in self.voice_bank.voices.items()
                               if e.get("kind") == "anonymized"],
            "voice_groups": sorted({e.get("group") for e in self.voice_bank.voices.values()
                                    if e.get("kind") == "anonymized" and e.get("group")}),
            "enrolled_voices": [n for n, e in self.voice_bank.voices.items()
                                if e.get("kind") == "enrolled"],
            "sample_rate": self.native_sr,
        }

    def voices(self) -> Dict[str, Dict]:
        """Available voice names with their metadata.

        v2 folders list the anonymized default voices, the enrolled voices
        and the ``female`` / ``male`` aliases; training speakers are hidden
        unless ``style.expose_training_speakers`` is set. v1 folders list
        their training speakers (unchanged behaviour)."""
        out: Dict[str, Dict] = {}
        if len(self.voice_bank):
            out.update(self.voice_bank.public())
        if self.cfg.style.expose_training_speakers or not len(self.voice_bank):
            for name, info in self.speakers.voices().items():
                out.setdefault(name, dict(info, kind="training_speaker"))
        return out

    # ------------------------------------------------------------------ #
    #  Pronunciation / analysis (0.1 API)
    # ------------------------------------------------------------------ #
    def add_pronunciation(self, word: str, pronunciation: str,
                          save: bool = False) -> None:
        from ..lexicon import Lexicon
        if self.lexicon is None:
            self.lexicon = Lexicon()
        self.lexicon.add(word, pronunciation)
        if save and self.folder:
            self.lexicon.save(os.path.join(self.folder, "lexicon.json"))

    def _normalize(self, text: str, language: Optional[str] = None) -> str:
        t = self.cfg.text
        return normalize_text(
            text, t.keep_punctuation, t.punctuation, t.expand_numbers,
            transliterate_foreign=getattr(t, "transliterate_foreign", True),
            lexicon=self.lexicon, language=language,
            languages=self.tokenizer.languages or t.languages,
            detect_languages=t.language_detection)

    def analyze(self, text: str, language: Optional[str] = None) -> Dict:
        """Explain how text will be read: entities/foreign words and their
        pronunciations, the normalized string, the synthesis plan (chunks,
        exact silences, emotion state) and per-word languages."""
        from ..lexicon import tag_entities
        from ..text import annotate_languages
        norm = self._normalize(text, language)
        langs = self.tokenizer.languages
        words, cur, lid = [], "", 0
        for sym, l in annotate_languages(norm, langs, language):
            if sym == " ":
                if cur:
                    words.append((cur, langs[lid] if lid < len(langs) else langs[0]))
                    cur = ""
            else:
                cur += sym
                lid = l
        if cur:
            words.append((cur, langs[lid] if lid < len(langs) else langs[0]))
        plan = self._plan(text, language, None, None)
        return {
            "entities": tag_entities(plain_text(text), self.lexicon),
            "normalized": norm,
            "plain": plain_text(norm),
            "word_languages": words,
            "plan": [(f"silence {p.seconds:.2f}s" if isinstance(p, Silence)
                      else {"text": p.text, "emotion": p.emotion,
                            "intensity": p.intensity}) for p in plan],
        }

    # ------------------------------------------------------------------ #
    #  Voice resolution
    # ------------------------------------------------------------------ #
    def _warn_once(self, key: str, msg: str) -> None:
        if key not in self._warned:
            self._warned.add(key)
            warnings.warn(msg, RuntimeWarning, stacklevel=3)

    def embed_speaker(self, audio: Union[str, np.ndarray, Sequence],
                      sample_rate: Optional[int] = None) -> np.ndarray:
        """Reference audio (path, array, (array, sr) or a list of them) ->
        style vector (gin_channels,) -- averaged over clips and windows."""
        from ..speaker.enroll import embed_speaker_audio
        items = (list(audio) if isinstance(audio, (list, tuple))
                 and not (len(audio) == 2 and isinstance(audio[1], int)) else [audio])
        emb, _ = embed_speaker_audio(self.model, self.cfg, items, self.device,
                                     sample_rate=sample_rate)
        return emb

    def enroll_speaker(self, name: str, audio: Union[str, np.ndarray, Sequence],
                       gender: Optional[str] = None, save: bool = True,
                       adapt_steps: int = 0, texts: Optional[Sequence[str]] = None,
                       sample_rate: Optional[int] = None, **meta) -> Dict:
        """Add a voice from a few seconds of audio (no training). Persisted
        to the model folder's voices.json when ``save``."""
        from ..speaker.enroll import enroll_speaker
        items = (list(audio) if isinstance(audio, (list, tuple))
                 and not (len(audio) == 2 and isinstance(audio[1], int)) else [audio])
        return enroll_speaker(self, name, items, gender=gender, save=save,
                              adapt_steps=adapt_steps, texts=texts,
                              sample_rate=sample_rate, **meta)

    def remove_speaker(self, name: str, save: bool = True) -> bool:
        ok = self.voice_bank.remove(name)
        if ok and save and self.folder:
            self.voice_bank.save(self.folder)
        return ok

    def _resolve_style(self, voice: Optional[str], reference_audio, speaker_embedding,
                       reference_sr: Optional[int]):
        """-> (sid tensor | None, g tensor (1, gin) | None, label)"""
        import torch
        if speaker_embedding is not None:
            g = torch.as_tensor(np.asarray(speaker_embedding, dtype=np.float32)).reshape(1, -1)
            return None, g.to(self.device), "embedding"
        if reference_audio is not None:
            emb = self.embed_speaker(reference_audio, reference_sr)
            return None, torch.from_numpy(emb).unsqueeze(0).to(self.device), "reference"
        v = (voice or "female").strip()
        emb = self.voice_bank.embedding(v) if len(self.voice_bank) else None
        if emb is not None:
            return None, torch.from_numpy(emb).unsqueeze(0).to(self.device), v
        if v in self.speakers.table:
            return torch.LongTensor([self.speakers.table[v]["id"]]).to(self.device), None, v
        if v.lower().endswith(_AUDIO_EXT) and os.path.isfile(v):
            emb = self.embed_speaker(v)
            return None, torch.from_numpy(emb).unsqueeze(0).to(self.device), f"clone:{v}"
        try:
            sid = self.speakers.resolve_voice(v)     # legacy gender aliases
        except KeyError:
            names = sorted(self.voices())
            raise KeyError(f"unknown voice {voice!r}; available: {names}. "
                           f"Enroll a new one with enroll_speaker(name, audio) "
                           f"or pass reference_audio=...") from None
        if len(self.voice_bank) and v.lower() in ("male", "female"):
            self._warn_once("alias-" + v, f"voice {v!r}: no anonymized default voice "
                            f"for this gender in voices.json; using the training "
                            f"speaker with most data")
        return torch.LongTensor([sid]).to(self.device), None, v

    def _emotion_tensors(self, emotion: Optional[str], intensity: Optional[float]):
        import torch
        if not getattr(self.model, "has_emotions", False):
            if emotion and emotion != "neutral":
                self._warn_once("emo", "this model has no emotion conditioning; "
                                "emotion/intensity are ignored")
            return None, None
        if emotion is None:
            return None, None
        name = canonical_emotion(emotion, self.cfg.style.emotions)
        if name is None:
            raise ValueError(f"unknown emotion {emotion!r}; choose from "
                             f"{list(self.cfg.style.emotions)}")
        if (self._emotion_counts is not None and name != "neutral"
                and not self._emotion_counts.get(name)):
            self._warn_once("emo-" + name,
                            f"emotion {name!r} was never seen in training; the "
                            f"model will speak neutrally")
        eid = emotion_id_of(name, self.cfg.style.emotions)
        inten = self.cfg.style.intensity_default if intensity is None else float(intensity)
        return (torch.LongTensor([eid]).to(self.device),
                torch.tensor([max(0.0, min(1.0, inten))]).to(self.device))

    # ------------------------------------------------------------------ #
    #  Planning & encoding
    # ------------------------------------------------------------------ #
    def _plan(self, text: str, language: Optional[str], emotion: Optional[str],
              intensity: Optional[float]) -> List[Union[Chunk, Silence]]:
        tok = self.tokenizer
        return plan_chunks(
            text, languages=tok.languages or self.cfg.text.languages,
            sentence_split=True,
            pause_token_known=tok.pause_id is not None,
            nonverbals_known=tok.known_nonverbals(),
            default_pause_s=self.cfg.text.default_pause_s,
            emotion=emotion, intensity=intensity)

    def _encode(self, text: str, language: Optional[str] = None):
        import torch
        norm = self._normalize(text, language)
        ids, lids = self.tokenizer.encode_full(
            norm, self.cfg.text.intersperse_blank, default_language=language,
            detect_languages=self.cfg.text.language_detection)
        if not ids:
            raise ValueError(f"Text produced no synthesizable symbols: {text!r}")
        x = torch.LongTensor(ids).unsqueeze(0).to(self.device)
        x_lengths = torch.LongTensor([x.size(1)]).to(self.device)
        lang = torch.LongTensor(lids).unsqueeze(0).to(self.device)
        return x, x_lengths, lang

    # ------------------------------------------------------------------ #
    def tts(
        self,
        text: str,
        voice: str = "female",
        sample_rate: Optional[int] = None,
        speed: float = 1.0,
        noise_scale: float = 0.667,
        *,
        emotion: Optional[str] = None,
        intensity: Optional[float] = None,
        reference_audio=None,
        reference_sr: Optional[int] = None,
        speaker_embedding=None,
        language: Optional[str] = None,
        steps: Optional[int] = None,
        cfg_scale: Optional[float] = None,
        seed: Optional[int] = None,
        pause_scale: float = 1.0,
        prior: Optional[str] = None,
    ) -> Tuple[np.ndarray, int]:
        """Synthesize ``text`` -> (float32 waveform in [-1, 1], sample_rate).

        voice            voice name (see ``voices()``), training speaker,
                         "male"/"female", or a reference audio path
        sample_rate      output rate (default: model native, 22050)
        speed            speaking rate; >1 faster, <1 slower
        noise_scale      prosody variability (0.667 standard)
        emotion          one of ``capabilities()["emotions"]`` (v2 models);
                         inline tags like [happy:0.8] override per segment
        intensity        0..1 emotion strength (default 1.0)
        reference_audio  path / array / list of clips -> clone this speaker
        speaker_embedding a vector from ``embed_speaker`` (fastest cloning)
        language         record language for normalization & language ids
                         (default: primary language; words are detected
                         individually in mixed text)
        steps            MeanFlow sampling steps (default cfg.prior.steps;
                         1 = fastest, 4 = default quality)
        cfg_scale        style guidance strength (1 = off)
        seed             deterministic output for a given text/voice
        pause_scale      multiplies every [pause:x] duration
        prior            "meanflow" | "flow" (override the checkpoint default)
        """
        import torch

        sr = sample_rate or self.native_sr
        sid, g, _label = self._resolve_style(voice, reference_audio,
                                             speaker_embedding, reference_sr)
        emo_default, inten_default = emotion, intensity
        plan = self._plan(text, language, emo_default, inten_default)
        if not any(isinstance(p, Chunk) for p in plan):
            raise ValueError(f"Text produced no synthesizable content: {text!r}")
        gen = None
        if seed is not None:
            gen = torch.Generator(device=self.device)
            gen.manual_seed(int(seed))

        pieces: List[np.ndarray] = []
        gap = np.zeros(int(self.cfg.text.sentence_gap_s * self.native_sr), dtype=np.float32)
        prev_was_chunk = False
        with torch.inference_mode():
            for item in plan:
                if isinstance(item, Silence):
                    n = int(max(0.0, item.seconds * pause_scale) * self.native_sr)
                    pieces.append(np.zeros(n, dtype=np.float32))
                    prev_was_chunk = False
                    continue
                if prev_was_chunk and len(gap):
                    pieces.append(gap)
                x, x_lengths, lang = self._encode(item.text, language)
                emo_t, inten_t = self._emotion_tensors(item.emotion, item.intensity)
                kw = {}
                if not self.cfg.is_legacy:
                    kw = dict(lang=lang, emotion=emo_t, intensity=inten_t,
                              prior=prior, steps=steps, cfg_scale=cfg_scale)
                y, _, _ = self.model.infer(
                    x, x_lengths, sid=sid, g=g,
                    noise_scale=noise_scale,
                    length_scale=1.0 / max(0.25, speed),
                    generator=gen, **kw)
                pieces.append(y.squeeze().float().cpu().numpy())
                prev_was_chunk = True
        wav = np.concatenate(pieces) if len(pieces) > 1 else pieces[0]
        if len(wav) == 0:
            wav = np.zeros(1, dtype=np.float32)
        wav = peak_normalize(wav, self.cfg.audio.peak_norm)
        if sr != self.native_sr:
            wav = resample(wav, self.native_sr, sr)
        return wav.astype(np.float32), sr

    def clone(self, text: str, reference_audio, **kwargs) -> Tuple[np.ndarray, int]:
        """Synthesize ``text`` in the voice of ``reference_audio``."""
        return self.tts(text, reference_audio=reference_audio, **kwargs)

    # ------------------------------------------------------------------ #
    def tts_to_file(self, text: str, path: str, **kwargs) -> str:
        """Synthesize and write a 16-bit PCM WAV file. Returns the path."""
        wav, sr = self.tts(text, **kwargs)
        parent = os.path.dirname(os.path.abspath(path))
        os.makedirs(parent, exist_ok=True)
        save_wav(path, wav, sr)
        return path

    def tts_wav_bytes(self, text: str, **kwargs) -> bytes:
        wav, sr = self.tts(text, **kwargs)
        return wav_bytes(wav, sr)

    # -- telephony / call-center wire formats --------------------------- #
    def pcm16_bytes(self, text: str, sample_rate: int = 16000, **kwargs) -> bytes:
        wav, _ = self.tts(text, sample_rate=sample_rate, **kwargs)
        return to_pcm16(wav)

    def mulaw_bytes(self, text: str, **kwargs) -> bytes:
        wav, _ = self.tts(text, sample_rate=8000, **kwargs)
        return to_mulaw(wav)

    def alaw_bytes(self, text: str, **kwargs) -> bytes:
        wav, _ = self.tts(text, sample_rate=8000, **kwargs)
        return to_alaw(wav)
