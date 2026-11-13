"""
ALTATTS -- Accurate Lifelike TTS: natural, expressive, multilingual
text-to-speech with zero-shot voice cloning, built for Kinyarwanda and
reusable for any language.
======================================================================

The speaking half of the ALTA stack (ALTASR listens, ALTATTS talks).

``altatts.model``        the network: a multi-speaker VITS backbone + ALTATTS 2
                         additions -- zero-shot style (speaker) encoder,
                         emotion/intensity conditioning, per-character language
                         ids, and a MeanFlow latent prior (one/few-step
                         generative prior for natural prosody).
``altatts.text``         multilingual front end: code-switched Kinyarwanda /
``altatts.languages``    English / French / Swahili normalization, number
``altatts.tags``         verbalization per language, control tags for pauses,
                         non-verbal sounds and emotions, character tokenizer.
``altatts.training``     data preparation (any corpus shape), the GAN trainer
                         (CPU / multi-GPU / multi-node), fine-tuning, and the
                         privacy-preserving default-voice builder.
``altatts.speaker``      voice enrollment from a few seconds of audio.
``altatts.inference``    :class:`Synthesizer`, :class:`StreamingSynthesizer`,
                         evaluation with a WER gate.
``altatts.integrations`` call-center glue (G.711 framing, Twilio, VoiceAgent).
``altatts.env``          ``altatts doctor`` -- environment diagnosis & repair.

Quick use::

    from altatts import Synthesizer
    tts = Synthesizer.from_pretrained("runs/kinyarwanda")
    wav, sr = tts.tts("Muraho! Amakuru yawe?", voice="female")
    wav, sr = tts.tts("Twishimiye [pause:0.4] kubafasha!", voice="male_young",
                      emotion="happy", intensity=0.7)
    tts.enroll_speaker("agent_claire", ["claire1.wav", "claire2.wav"])
    wav, sr = tts.tts("Murakoze guhamagara.", voice="agent_claire")

Heavy dependencies (torch) are imported lazily: ``import altatts`` plus the
config/text/metrics layers work on any machine.
"""
from __future__ import annotations

__version__ = "2.0.0"

# Torch-free foundations -- always importable.
from .config import Config, PRESETS, PRESET_NAMES, load_config, preset   # noqa: F401
from .lexicon import Lexicon, tag_entities, transliterate_english, is_foreign_word  # noqa: E501
from .text import (CharTokenizer, normalize_text, strip_punctuation,  # noqa: F401
                   expand_numbers, verbalize_number, split_sentences,  # noqa: F401
                   plan_chunks, plain_text,                             # noqa: F401
                   build_tokenizer, load_tokenizer)                     # noqa: F401
from .tags import parse_tags, canonicalize, SPECIAL_TOKENS, DEFAULT_EMOTIONS  # noqa: F401
from .languages import (available_languages, register_language,         # noqa: F401
                        LanguageSpec, detect_word_language)             # noqa: F401
from .metrics import (mcd, f0_metrics, median_f0, gender_from_f0,  # noqa: F401
                      wer, cer, corpus_wer_cer, corpus_tts_metrics, rtf)  # noqa: F401

# Torch-backed public API, resolved lazily (PEP 562).
_LAZY = {
    "Synthesizer": "altatts.inference.synthesizer",
    "StreamingSynthesizer": "altatts.inference.streaming",
    "stream_to_wav": "altatts.inference.streaming",
    "load_checkpoint_folder": "altatts.inference.checkpoint",
    "load_checkpoint_bundle": "altatts.inference.checkpoint",
    "VoiceBank": "altatts.inference.voices",
    "build_model": "altatts.model.vits",
    "SynthesizerTrn": "altatts.model.vits",
    "Trainer": "altatts.training.trainer",
    "TTSDataset": "altatts.training.data",
    "load_records": "altatts.training.data",
    "SpeakerRegistry": "altatts.training.data",
    "prepare_metadata": "altatts.training.prepare",
    "build_default_voices": "altatts.training.anonymize",
    "embed_speaker_audio": "altatts.speaker.enroll",
    "AudioDecodeError": "altatts.audio",
    "VoiceAgent": "altatts.integrations.callcenter",
    "telephony_frames": "altatts.integrations.callcenter",
    "streaming_telephony_frames": "altatts.integrations.callcenter",
    "twilio_media_messages": "altatts.integrations.callcenter",
    "prerender_prompts": "altatts.integrations.callcenter",
    "enroll_agent": "altatts.integrations.callcenter",
    "export_onnx": "altatts.export",
    "TTSClient": "altatts.client",
    "serve": "altatts.serving",
    "package": "altatts.deploy",
}


def __getattr__(name):
    target = _LAZY.get(name)
    if target is None:
        raise AttributeError(f"module 'altatts' has no attribute {name!r}")
    import importlib
    try:
        module = importlib.import_module(target)
    except ImportError as exc:
        raise ImportError(
            f"altatts.{name} requires PyTorch. Install the backend with "
            f"`pip install torch torchaudio` -- or run `altatts doctor --fix` "
            f"({exc})") from exc
    value = getattr(module, name)
    globals()[name] = value
    return value


def __dir__():
    return sorted(list(globals()) + list(_LAZY))
