"""
The ALTA TTS data registry -- every source corpus, how to read it, and how
it enters the combined set. **Add new datasets here** (one DatasetSpec) and
re-run ``altatts combine-data`` or the notebook; nothing else changes.

Families (voice-plan groups): bantu = Kinyarwanda + Kiswahili + code-switching,
english, french. The data root is ``ALTA_TTS_DATA_ROOT`` or the default below.

Balancing: the English and French corpora are an order of magnitude larger
than the Bantu ones (Hi-Fi TTS ~290 h, CML-French ~300 h). Caps keep EVERY
speaker but limit hours per speaker and per dataset so one language cannot
dominate training; raise ``max_hours`` / ``max_hours_per_speaker`` (or set
them to None) in a copy of this registry when you want more.
"""
from __future__ import annotations

import os
from typing import Dict, List

from .spec import DatasetSpec

DEFAULT_ROOT = "/home/schadrack/Vault/YaliLabs/ALTA_DATA/Voice/TTS"
OUTPUT_FOLDER = "Combined_Version_two_TTS_training"

#: language-family groups (also the privacy voice plan's families)
FAMILIES: Dict[str, List[str]] = {"bantu": ["rw", "sw", "mixed"], "english": ["en"],
                                  "french": ["fr"]}


def data_root() -> str:
    return os.environ.get("ALTA_TTS_DATA_ROOT", DEFAULT_ROOT)


DATASETS: List[DatasetSpec] = [
    # ------------------------------------------------------------ Bantu ---- #
    DatasetSpec(
        name="c4ir_agri", path="Kinyarwanda_TTS/C4IR-RW/kinya-ag-tts", adapter="tsv_id_text_voices",
        language="rw", family="bantu", license="CC-BY-4.0",
        description="C4IR / KiNLP Kinyarwanda agricultural TTS corpus: 4 studio voices reading an agricultural knowledge base (24 kHz).",
        options={"voices": {"rw_ag_tts_male": {"speaker": "male1", "gender": "male"},
                            "rw_ag_tts_female": {"speaker": "female1", "gender": "female"},
                            "rw_ag_tts_male2": {"speaker": "male2", "gender": "male"},
                            "rw_ag_tts_female2": {"speaker": "female2", "gender": "female"}},
                 "domain": "agriculture"},
        notes="male2/female2 may be second recording batches of the same actors; kept as separate speakers until verified."),
    DatasetSpec(
        name="du_afrispeak", path="Kinyarwanda_TTS/DigitalUmuganda", adapter="afrispeak_manifest",
        language="rw", family="bantu", license="see Digital Umuganda terms",
        description="Digital Umuganda afrispeak Kinyarwanda TTS: one actress + one actor, 16 kHz studio reads.",
        options={"voices": {"afrispeak_kinyarwanda_female_tts_dataset": {"speaker": "actress", "gender": "female"},
                            "afrispeak_kinyarwanda_male_tts_dataset": {"speaker": "actor", "gender": "male"}}}),
    DatasetSpec(
        name="mbanlp", path="Kinyarwanda_TTS/MbaNLP/kinyarwanda-tts-dataset", adapter="mbanlp_csv",
        language="rw", family="bantu", license="CC-BY-4.0",
        description="Mbaza / Digital Umuganda Kinyarwanda TTS corpus: 3 992 studio clips, one voice actress (44.1 kHz).",
        options={"speaker": "actress", "gender": "female"}),
    DatasetSpec(
        name="professor_hf", path="Kinyarwanda_TTS/Professor/kinyarwanda-tts-dataset-kin", adapter="hf_parquet_audio",
        language="rw", family="bantu", enabled=False,
        description="Hugging Face parquet re-packaging of the SAME Mbaza corpus as `mbanlp` (3 919 / 3 992 identical texts and audio files).",
        options={"speaker": "actress", "gender": "female"},
        notes="Disabled: duplicate of mbanlp. Enable only if mbanlp is removed."),
    DatasetSpec(
        name="efiche_benchmark", path="Kinyarwanda_TTS/E-Fiche/Benchmarking dataset", adapter="efiche_xlsx",
        language="rw", family="bantu", role="test", max_duration_s=130.0, max_text_chars=2000,
        description="E-Fiche health-dialogue benchmark: 74 two-speaker dialogues (30-120 s), pure Kinyarwanda and mixed with English/French.",
        notes="Held-out TEST only: multi-speaker dialogues are not single-voice TTS training material. Useful for WER / robustness evaluation."),
    DatasetSpec(
        name="kiswahili", path="Kiswahili_TTS", adapter="kiswahili_xlsx",
        language="sw", family="bantu",
        description="Kiswahili single-speaker TTS corpus (22.05 kHz), transcripts with a normalized column; 591 clips have a re-recorded take.",
        options={"speaker": "reader1", "file": "Text/metadata.xlsx", "audio_dir": "audio", "prefer_take": "newest"},
        notes="Gender detected from pitch. Only ONE speaker: the Bantu voice plan backs Swahili with the Kinyarwanda speakers."),
    DatasetSpec(
        name="code_switching", path="Code_switching", adapter="foundry_sessions",
        language="mixed", family="bantu",
        description="KEF / Irembo / KinyaVoice code-switching recordings (Kinyarwanda with English terms): 3 speakers, finance/health/agriculture/education/governance domains (48 kHz opus).",
        options={"glob": "foundry_*"}, max_duration_s=35.0,
        notes="Records are tagged `mixed` when English words are detected, else `rw`; all speakers are cross-lingual. "
              "Takes are multi-sentence (median 12 s, up to ~35 s), so the duration limit is raised to 35 s; "
              "run `altatts-segment --split-mode punct` on the sessions if you prefer sentence clips."),
    # ---------------------------------------------------------- English ---- #
    DatasetSpec(
        name="ljspeech", path="English_TTS/LJ_TTS", adapter="ljspeech",
        language="en", family="english", license="public domain",
        description="LJ Speech: one female speaker, 13 100 clips, 24 h, 22.05 kHz.",
        options={"speaker": "lj", "gender": "female", "audio_dir": "audio"}),
    DatasetSpec(
        name="emns", path="English_TTS/EMNS", adapter="emns",
        language="en", family="english",
        description="EMNS emotive narrative corpus: one female speaker, 8 emotions with 0-10 intensity (48 kHz opus).",
        options={"complete_only": True},
        notes="Emotion labels: angry, disgust, excited, happy, neutral, sad, sarcastic, surprised. Intensity = level/10."),
    DatasetSpec(
        name="hifi_tts", path="English_TTS/hi_fi_tts_v0", adapter="hifi_tts",
        language="en", family="english", license="CC-BY-4.0",
        description="Hi-Fi TTS (NVIDIA): 10 LibriVox readers, ~292 h, 44.1 kHz; clean + other subsets.",
        options={"subsets": ["clean", "other"]},
        max_hours=50.0, max_hours_per_speaker=6.0,
        speaker_genders={"reader92": "female", "reader6097": "male", "reader9017": "male",
                         "reader6670": "male", "reader6671": "male", "reader8051": "female",
                         "reader9136": "female", "reader11614": "female", "reader11697": "female",
                         "reader12787": "female"},
        notes="Capped to 50 h (<= 6 h per reader) to balance languages; gender hints are verified by pitch."),
    # ----------------------------------------------------------- French ---- #
    DatasetSpec(
        name="cml_french", path="French_TTS/cml_tts_dataset_french_v0.1", adapter="cml_tts",
        language="fr", family="french", license="CC-BY-4.0",
        description="CML-TTS French: 45 LibriVox speakers, ~316 h, 24 kHz, with a transcript-quality score.",
        options={"min_levenshtein": 0.9, "splits": ["train", "dev", "test"]},
        max_hours=60.0, max_hours_per_speaker=5.0,
        notes="Clips whose wav2vec transcript agrees < 0.9 with the label are dropped; capped to 60 h (<= 5 h per speaker) for balance."),
]


def get_spec(name: str) -> DatasetSpec:
    for s in DATASETS:
        if s.name == name:
            return s
    raise KeyError(f"unknown dataset {name!r}; registered: {[s.name for s in DATASETS]}")
