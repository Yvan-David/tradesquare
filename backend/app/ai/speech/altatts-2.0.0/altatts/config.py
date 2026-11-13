"""
All ALTATTS behaviour in one dataclass tree, saved/loaded as JSON.

Same philosophy as ALTASR: extending the model never requires touching code.
Copy a config file from ``configs/``, edit numbers, pass it with ``--config``.
Presets give ready-made starting points; ``preset("base")`` returns a full
Config.

Sections
--------
``audio``    signal parameters (one native rate, default 22 050 Hz; inference
             resamples to 8 k telephony / 16 k ASR / 44.1-48 k media).
``text``     normalization policy, the languages the model speaks, control
             tags (pauses, non-verbal sounds).
``model``    the VITS backbone: text encoder, posterior, flow, HiFi-GAN
             decoder, duration predictor. ``version`` = 1 (legacy VITS) or
             2 (ALTATTS 2: + style encoder, language ids, MeanFlow prior).
``style``    speaker identity (table + zero-shot reference encoder) and
             emotion/intensity conditioning.
``prior``    the latent prior: ``meanflow`` (one/few-step flow matching,
             Geng et al. 2025) or ``flow`` (the VITS normalizing flow).
``privacy``  anonymized default voices (3 female + 3 male, mixed ages).
``data``     where metadata/audio live and how records are filtered.
``train``    the adversarial training recipe.

Backwards compatibility: unknown JSON keys are ignored and missing keys take
the dataclass defaults. A config written by ALTATTS 0.1 (no ``model.version``)
is recognized as a legacy v1 model and keeps the exact v1 network.
"""
from __future__ import annotations

import dataclasses
import json
from dataclasses import dataclass, field
from typing import Dict, List

from .tags import DEFAULT_EMOTIONS

CONFIG_VERSION = 2


# --------------------------------------------------------------------------- #
@dataclass
class AudioConfig:
    sample_rate: int = 22_050
    n_fft: int = 1024             # 46 ms analysis window @ 22.05 kHz
    hop_length: int = 256         # 11.6 ms hop -> decoder upsamples x256
    win_length: int = 1024
    n_mels: int = 80              # mel loss / evaluation / reference encoder
    mel_fmin: float = 0.0
    mel_fmax: float = 0.0         # 0 = sample_rate / 2
    peak_norm: float = 0.95       # loudness target (training + output)


@dataclass
class TextConfig:
    keep_punctuation: bool = True
    punctuation: str = ".,?!;:'-"
    expand_numbers: bool = True
    # Transliterate words from languages the model was NOT trained on into
    # the primary language's orthography (so a Kinyarwanda-only model still
    # reads "meeting" as "mitingi"). Words from trained languages keep their
    # spelling and get their language id instead.
    transliterate_foreign: bool = True
    intersperse_blank: bool = True
    # ---- v2: languages & controls ------------------------------------------ #
    # Languages the model speaks, primary first. Each gets a learned language
    # embedding; words are tagged per language (auto-detected or forced with
    # <en>...</en>). Add codes here to train a multilingual / code-switching
    # model: ["rw", "en", "fr", "sw"].
    languages: List[str] = field(default_factory=lambda: ["rw"])
    language_detection: bool = True     # word-level detection in mixed text
    nonverbal_tokens: bool = True       # keep [laugh]/[breath]/... as tokens
    pause_token: bool = True            # keep [pause] as a learned token
    default_pause_s: float = 0.35       # [pause] length when not learned
    sentence_gap_s: float = 0.12        # silence inserted between sentences

    @property
    def primary_language(self) -> str:
        return (self.languages or ["rw"])[0]


@dataclass
class ModelConfig:
    # 1 = legacy ALTATTS 0.1 VITS (exact old network, loads old weights);
    # 2 = ALTATTS 2 (style encoder, language ids, MeanFlow prior).
    version: int = CONFIG_VERSION
    # ---- text encoder (transformer over characters) ------------------------ #
    hidden_channels: int = 192
    filter_channels: int = 768
    n_heads: int = 2
    n_layers: int = 6
    kernel_size: int = 3
    p_dropout: float = 0.1
    rel_window: int = 4
    # ---- posterior encoder / flow ------------------------------------------ #
    posterior_layers: int = 16
    flow_layers: int = 4
    flow_kernel: int = 5
    wn_kernel: int = 5
    # ---- HiFi-GAN decoder --------------------------------------------------- #
    resblock_kernel_sizes: List[int] = field(default_factory=lambda: [3, 7, 11])
    resblock_dilation_sizes: List[List[int]] = field(
        default_factory=lambda: [[1, 3, 5], [1, 3, 5], [1, 3, 5]])
    upsample_rates: List[int] = field(default_factory=lambda: [8, 8, 2, 2])
    upsample_initial_channel: int = 512
    upsample_kernel_sizes: List[int] = field(default_factory=lambda: [16, 16, 4, 4])
    # ---- speakers ----------------------------------------------------------- #
    n_speakers: int = 2           # trained-speaker table size (prepare sets it)
    gin_channels: int = 256       # style vector size (global conditioning)
    # ---- duration predictor -------------------------------------------------- #
    dp_filter_channels: int = 256
    dp_kernel_size: int = 3
    dp_dropout: float = 0.5

    def __post_init__(self) -> None:
        if self.hidden_channels % self.n_heads:
            raise ValueError("hidden_channels must be divisible by n_heads.")
        if len(self.upsample_rates) != len(self.upsample_kernel_sizes):
            raise ValueError("upsample_rates and upsample_kernel_sizes must "
                             "have the same length.")
        if len(self.resblock_kernel_sizes) != len(self.resblock_dilation_sizes):
            raise ValueError("resblock kernel/dilation lists must match.")

    def upsample_factor(self) -> int:
        f = 1
        for r in self.upsample_rates:
            f *= r
        return f


@dataclass
class StyleConfig:
    """Who speaks and how: speaker identity + emotion."""
    # Speaker encoder for zero-shot voice cloning: "builtin" trains a
    # reference encoder jointly (mel -> gin_channels vector, regressed onto
    # the speaker table so enrolled voices live in the same space as trained
    # ones); "none" disables cloning (v1 behaviour).
    speaker_encoder: str = "builtin"
    ref_channels: List[int] = field(default_factory=lambda: [32, 32, 64, 64, 128, 128])
    ref_frames: int = 256             # reference mel crop (~3 s at hop 256)
    ref_min_frames: int = 64
    p_ref: float = 0.5                # prob. of conditioning on the reference
                                      # embedding (vs the table) in training
    ref_other_clip_prob: float = 0.7  # reference = a DIFFERENT clip of the
                                      # same speaker (limits content leakage)
    c_spk: float = 1.0                # reference-embedding regression weight
    # Emotion conditioning: a learned embedding per category scaled by an
    # intensity in [0, 1]. Datasets without labels use the "unlabeled" slot.
    emotion_conditioning: bool = True
    emotions: List[str] = field(default_factory=lambda: list(DEFAULT_EMOTIONS))
    intensity_default: float = 1.0
    # Style dropout (replace the style vector by a learned null vector) so
    # classifier-free guidance is possible at inference (cfg_scale > 1).
    cond_dropout: float = 0.1
    # Hide training-speaker names from voices(); only anonymized default
    # voices and enrolled voices are exposed (privacy).
    expose_training_speakers: bool = False


@dataclass
class PriorConfig:
    """Latent prior p(z | text, style).

    ``meanflow`` -- a transformer trained with the MeanFlow objective (average
    velocity field; Geng, Deng, Bai, Kolter & He, 2025), giving natural
    prosody with 1-4 sampling steps. ``flow`` -- the VITS normalizing flow
    + Gaussian prior (legacy / fallback). Both are always trained when
    version >= 2; ``type`` selects what inference uses by default.
    """
    type: str = "meanflow"            # meanflow | flow
    hidden: int = 256
    n_layers: int = 6
    n_heads: int = 4
    ffn_mult: int = 4
    conv_kernel: int = 5              # depthwise conv in each block (local
                                      # context, length-agnostic)
    meanflow_ratio: float = 0.25      # fraction of samples with r != t
                                      # (0 = plain conditional flow matching)
    time_sampler: str = "logit_normal"   # logit_normal | uniform
    time_mu: float = -0.4
    time_sigma: float = 1.0
    adaptive_weight_p: float = 1.0    # adaptive L2 power (0 disables)
    c_mf: float = 1.0                 # loss weight
    jvp_mode: str = "auto"            # auto | jvp | fd  (finite differences)
    # Training window for the prior loss (latent frames, ~11.6 ms each):
    # longer utterances are cropped at random so attention memory stays
    # bounded (the network is length-agnostic; inference runs full length).
    max_frames: int = 1024            # ~12 s; 0 = whole utterance
    steps: int = 4                    # default sampling steps at inference
    cfg_scale: float = 1.0            # classifier-free guidance (1 = off)
    warmup_steps: int = 2000          # prior-only steps before the trainer
                                      # trusts it for samples (logging only)


@dataclass
class PrivacyConfig:
    """Anonymized default (production) voices built at the end of training.

    The *voice plan* decides how many default voices exist and what they
    are made of. ``plan="auto"`` creates one group per **language family**
    present in ``text.languages`` -- ``french`` (fr), ``english`` (en),
    ``bantu`` (rw, sw and the code-switching speakers) -- with ``n_female``
    + ``n_male`` voices each. A model trained on rw+en+fr+sw therefore
    ships 12 production voices (4 per family, 2 F / 2 M). A single-language
    model gets one group with ``single_family_per_gender`` voices per
    gender spread over the age groups. ``groups`` overrides everything.
    """
    default_voices: bool = True
    plan: str = "auto"                 # auto | custom (use ``groups``)
    # language families used by the auto plan (name -> language codes);
    # the family containing the model's PRIMARY language also receives the
    # cross-lingual (code-switching) speakers
    families: Dict[str, List[str]] = field(default_factory=lambda: {
        "french": ["fr"], "english": ["en"], "bantu": ["rw", "sw"]})
    n_female: int = 2                  # per family when several families exist
    n_male: int = 2
    single_family_per_gender: int = 3  # single-language model: voices per gender
    # custom plan, e.g. [{"name": "bantu", "languages": ["rw", "sw"],
    #                     "n_female": 2, "n_male": 2, "cross_lingual": true}]
    groups: List[Dict] = field(default_factory=list)
    age_groups: List[str] = field(default_factory=lambda: ["25-45", "16-25", "45+"])
    # cosine-similarity ceiling between a default voice and ANY training
    # speaker (speaker-encoder space). 0 = adaptive (midpoint between the
    # intra- and inter-speaker similarity measured on the training data).
    max_similarity: float = 0.0
    max_iterations: int = 12
    seed: int = 7
    test_sentence: str = ""           # "" = picked from the training set
    # kept for 2.0.0 configs: equivalent to single_family_per_gender
    n_per_gender: int = 0


@dataclass
class DataConfig:
    audio_root: str = ""
    train_metadata: List[str] = field(default_factory=list)
    val_metadata: List[str] = field(default_factory=list)
    min_duration_s: float = 1.0
    max_duration_s: float = 30.0
    max_text_len: int = 1000
    trim_silence: bool = True
    trim_db: float = 35.0
    # Record-level language when metadata has none (primary language).
    default_language: str = ""
    # Insert [pause] tokens from the audio when the transcripts have none:
    # off | punct (only where a punctuation mark meets a detected silence)
    auto_pauses: str = "off"
    auto_pause_min_s: float = 0.18


@dataclass
class TrainConfig:
    epochs: int = 10
    batch_size: int = 16
    lr: float = 2e-4
    betas: List[float] = field(default_factory=lambda: [0.8, 0.99])
    eps: float = 1e-9
    lr_decay: float = 0.999875
    grad_clip: float = 500.0
    amp: bool = True
    num_workers: int = 8
    seed: int = 1234
    out_dir: str = "runs/altatts"
    device: str = "auto"          # auto | cpu | cuda | cuda:N
    segment_size: int = 32
    c_mel: float = 45.0
    c_kl: float = 1.0
    c_fm: float = 2.0
    c_dur: float = 1.0
    bucket_batches: bool = True
    max_batch_seconds: float = 320.0
    checkpoint_every: int = 1
    step_checkpoint_every: int = 15000
    n_val_samples: int = 4
    eval_batches: int = 0         # validation batches per epoch (0 = whole dev set)
    log_every: int = 50
    resume: str = ""
    init_from: str = ""
    init_speaker_mode: str = "mean"
    freeze: str = ""
    ddp_timeout_min: int = 30
    build_default_voices: bool = True   # run the privacy builder at the end
    # ---- schedule, early stopping, logging ---------------------------------- #
    lr_warmup_steps: int = 500          # linear LR warmup (0 = off)
    early_stop_patience: int = 0        # stop after N epochs without improvement (0 = off)
    early_stop_min_delta: float = 0.002 # improvement smaller than this does not count
    early_stop_metric: str = "val_mel_l1"   # val_mel_l1 | val_mf
    max_hours: float = 0.0              # wall-clock budget (0 = none)
    max_nonfinite_steps: int = 50       # abort after this many consecutive NaN steps
    tensorboard: bool = True            # write logs/tensorboard when the package exists
    wandb_project: str = ""             # Weights & Biases project (empty = off)


@dataclass
class Config:
    audio: AudioConfig = field(default_factory=AudioConfig)
    text: TextConfig = field(default_factory=TextConfig)
    model: ModelConfig = field(default_factory=ModelConfig)
    style: StyleConfig = field(default_factory=StyleConfig)
    prior: PriorConfig = field(default_factory=PriorConfig)
    privacy: PrivacyConfig = field(default_factory=PrivacyConfig)
    data: DataConfig = field(default_factory=DataConfig)
    train: TrainConfig = field(default_factory=TrainConfig)

    # -- json persistence ----------------------------------------------------- #
    def to_dict(self) -> Dict:
        return dataclasses.asdict(self)

    def save(self, path: str) -> None:
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(self.to_dict(), fh, indent=2, ensure_ascii=False)

    @classmethod
    def from_dict(cls, d: Dict) -> "Config":
        sections = {"audio": AudioConfig, "text": TextConfig,
                    "model": ModelConfig, "style": StyleConfig,
                    "prior": PriorConfig, "privacy": PrivacyConfig,
                    "data": DataConfig, "train": TrainConfig}
        kwargs = {}
        for name, klass in sections.items():
            payload = dict(d.get(name, {}) or {})
            valid = {f.name for f in dataclasses.fields(klass)}
            kwargs[name] = klass(**{k: v for k, v in payload.items() if k in valid})
        cfg = cls(**kwargs)
        model_payload = d.get("model", {}) or {}
        if "version" not in model_payload:
            # written by ALTATTS 0.1: the exact legacy network
            cfg.model.version = 1
            cfg.prior.type = "flow"
            cfg.style.speaker_encoder = "none"
            cfg.style.emotion_conditioning = False
            cfg.style.expose_training_speakers = True
        return cfg

    # -- derived -------------------------------------------------------------- #
    @property
    def is_legacy(self) -> bool:
        """True for an ALTATTS 0.1 checkpoint (plain VITS, no style encoder /
        emotions / MeanFlow prior). ``model.version`` is just the generation
        number written into config.json: 1 = ALTATTS 0.1, 2 = ALTATTS 2."""
        return self.model.version < 2

    @property
    def generation(self) -> str:
        return "ALTATTS 0.1 (legacy VITS)" if self.is_legacy else "ALTATTS 2"

    def n_languages(self) -> int:
        return max(1, len(self.text.languages))

    def n_emotions(self) -> int:
        """Emotion table size: index 0 = unlabeled, then the categories."""
        return 1 + len(self.style.emotions)

    def summary(self) -> str:
        m, t, a, s, p = self.model, self.train, self.audio, self.style, self.prior
        return (f"ALTATTS v{m.version}  sr={a.sample_rate}  hop={a.hop_length}  "
                f"hidden={m.hidden_channels}  enc_layers={m.n_layers}  "
                f"flows={m.flow_layers}  prior={p.type}"
                f"{'' if self.is_legacy else f'({p.n_layers}x{p.hidden}, {p.steps} steps)'}  "
                f"speakers={m.n_speakers}  cloning={s.speaker_encoder}  "
                f"emotions={'on' if s.emotion_conditioning and not self.is_legacy else 'off'}  "
                f"languages={self.text.languages}  epochs={t.epochs}  "
                f"batch={t.batch_size}  lr={t.lr}")

    def validate(self) -> None:
        if self.model.upsample_factor() != self.audio.hop_length:
            raise ValueError(
                f"product(upsample_rates)={self.model.upsample_factor()} must "
                f"equal audio.hop_length={self.audio.hop_length} -- the decoder "
                f"turns one latent frame into exactly one hop of samples.")
        if not self.text.languages:
            raise ValueError("text.languages must list at least one language")
        from .languages import has_language
        for code in self.text.languages:
            if not has_language(code):
                raise ValueError(f"text.languages: unknown language {code!r} "
                                 f"(register it in altatts.languages)")
        if self.prior.type not in ("meanflow", "flow"):
            raise ValueError("prior.type must be 'meanflow' or 'flow'")
        if self.prior.hidden % self.prior.n_heads:
            raise ValueError("prior.hidden must be divisible by prior.n_heads")
        if self.style.speaker_encoder not in ("builtin", "none"):
            raise ValueError("style.speaker_encoder must be 'builtin' or 'none'")
        if "neutral" not in self.style.emotions:
            self.style.emotions.insert(0, "neutral")
        if not 0.0 <= self.prior.meanflow_ratio <= 1.0:
            raise ValueError("prior.meanflow_ratio must be in [0, 1]")
        if self.is_legacy and self.prior.type != "flow":
            raise ValueError("a version-1 (legacy) model has no MeanFlow prior; "
                             "set prior.type='flow' or model.version=2")
        if self.privacy.plan not in ("auto", "custom"):
            raise ValueError("privacy.plan must be 'auto' or 'custom'")
        if self.privacy.n_per_gender:
            self.privacy.single_family_per_gender = self.privacy.n_per_gender
            self.privacy.n_per_gender = 0
        for g in self.privacy.groups:
            if "name" not in g or "languages" not in g:
                raise ValueError("each privacy.groups entry needs 'name' and "
                                 "'languages'")


# --------------------------------------------------------------------------- #
#  Presets
# --------------------------------------------------------------------------- #
def _small() -> Config:
    c = Config()
    c.model.upsample_initial_channel = 256
    c.model.resblock_kernel_sizes = [3, 5, 7]
    c.model.resblock_dilation_sizes = [[1, 2], [2, 6], [3, 12]]
    c.prior.hidden = 192
    c.prior.n_layers = 4
    c.prior.n_heads = 3
    c.train.batch_size = 24
    return c


def _base() -> Config:
    return Config()


def _large() -> Config:
    c = Config()
    c.model.hidden_channels = 256
    c.model.filter_channels = 1024
    c.model.n_heads = 4
    c.model.flow_layers = 6
    c.prior.hidden = 384
    c.prior.n_layers = 8
    c.prior.n_heads = 6
    c.train.batch_size = 12
    return c


PRESETS: Dict[str, "Config"] = {}
PRESET_NAMES = ("small", "base", "large")


def preset(name: str) -> Config:
    builders = {"small": _small, "base": _base, "large": _large}
    if name not in builders:
        raise KeyError(f"unknown preset {name!r}; choose from {sorted(builders)}")
    cfg = builders[name]()
    cfg.validate()
    return cfg


for _n in PRESET_NAMES:
    PRESETS[_n] = preset(_n)


def load_config(path: str) -> Config:
    with open(path, "r", encoding="utf-8") as fh:
        cfg = Config.from_dict(json.load(fh))
    cfg.validate()
    return cfg
