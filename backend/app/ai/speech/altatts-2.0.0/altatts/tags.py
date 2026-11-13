"""
Control tags: pauses, non-verbal sounds, emotions, and language spans.

ALTATTS text may carry inline controls, the way modern expressive TTS systems
(audio tags) and the SSML standard do. One grammar is accepted everywhere --
in training transcripts, in ``Synthesizer.tts`` input, and in the CLI -- and
is normalized to canonical ``[tag]`` form here.

Pauses (exact silence at inference; a learned PAUSE token in training)
    [pause]            [pause:0.5]        [pause:500ms]       ...
    <break/>           <break time="500ms"/>   <break time="0.5s"/>
    <sil>  <silence>   [silence:0.3]      [sil]

Non-verbal vocalizations (learned tokens when the training data marks them)
    [laugh] [laughs] [laughter] [chuckle]   -> laugh
    [breath] [inhale] [exhale]              -> breath
    [sigh] [cough] [sniff] [gasp] [throat]  -> as named
    [um] [uh] [hmm] [er] [hesitate]         -> hesitation

Emotion (applies to the text that follows, until the next emotion tag)
    [happy]  [sad:0.8]  [emotion:angry]  [emotion:calm:0.4]
    <emotion name="happy" intensity="0.7">...</emotion>   (name only)

Language spans (override word-level language detection)
    <en>hello there</en>   <fr>bonjour</fr>   [lang:sw]habari[/lang]

Anything inside ``[...]`` that is not understood is left for the lexicon /
normalizer to deal with (it is almost always real text such as "[sic]").
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import List, Optional, Sequence, Union

# canonical names ----------------------------------------------------------- #
PAUSE = "pause"
NONVERBAL_ALIASES = {
    "laugh": "laugh", "laughs": "laugh", "laughter": "laugh",
    "chuckle": "laugh", "chuckles": "laugh", "giggle": "laugh",
    "breath": "breath", "breathe": "breath", "breathes": "breath",
    "inhale": "breath", "inhales": "breath", "exhale": "breath",
    "exhales": "breath",
    "sigh": "sigh", "sighs": "sigh",
    "cough": "cough", "coughs": "cough",
    "sniff": "sniff", "sniffs": "sniff",
    "gasp": "gasp", "gasps": "gasp",
    "throat": "throat", "clears-throat": "throat", "clear-throat": "throat",
    "um": "hesitation", "uh": "hesitation", "hmm": "hesitation",
    "hm": "hesitation", "er": "hesitation", "erm": "hesitation",
    "hesitate": "hesitation", "hesitation": "hesitation",
}
NONVERBALS: Sequence[str] = ("laugh", "breath", "sigh", "cough", "sniff",
                             "gasp", "throat", "hesitation")

DEFAULT_EMOTIONS: Sequence[str] = ("neutral", "happy", "sad", "angry",
                                   "fearful", "surprised", "disgusted",
                                   "calm", "excited")
EMOTION_ALIASES = {
    "neutral": "neutral", "normal": "neutral", "none": "neutral",
    "happy": "happy", "happiness": "happy", "joy": "happy", "joyful": "happy",
    "cheerful": "happy", "glad": "happy",
    "sad": "sad", "sadness": "sad", "unhappy": "sad", "sorrow": "sad",
    "angry": "angry", "anger": "angry", "mad": "angry", "furious": "angry",
    "fearful": "fearful", "fear": "fearful", "afraid": "fearful",
    "scared": "fearful", "anxious": "fearful",
    "surprised": "surprised", "surprise": "surprised", "amazed": "surprised",
    "disgusted": "disgusted", "disgust": "disgusted",
    "calm": "calm", "relaxed": "calm", "serene": "calm", "gentle": "calm",
    "excited": "excited", "excitement": "excited", "enthusiastic": "excited",
    "energetic": "excited",
    # extra labels found in public corpora map to the closest basic emotion
    "friendly": "happy", "warm": "calm", "serious": "neutral",
    "whisper": "calm", "shouting": "angry", "frustrated": "angry",
    "bored": "sad", "sleepy": "calm", "confused": "surprised",
    "empathetic": "calm", "apologetic": "sad", "professional": "neutral",
}

# tokens the tokenizer reserves (order matters: ids are assigned in order) --- #
SPECIAL_TOKENS: Sequence[str] = ("[pause]",) + tuple(f"[{n}]" for n in NONVERBALS)


def special_token(kind: str) -> str:
    return f"[{kind}]"


# segments ------------------------------------------------------------------ #
@dataclass
class TextSpan:
    text: str
    language: Optional[str] = None          # explicit span language or None


@dataclass
class PauseTag:
    seconds: Optional[float] = None         # None = unspecified ("natural")


@dataclass
class NonverbalTag:
    kind: str                               # one of NONVERBALS


@dataclass
class EmotionTag:
    emotion: str
    intensity: Optional[float] = None


Segment = Union[TextSpan, PauseTag, NonverbalTag, EmotionTag]


@dataclass
class ParsedText:
    segments: List[Segment] = field(default_factory=list)

    def plain_text(self) -> str:
        """Text with all tags removed (for ASR scoring / display)."""
        return re.sub(r"\s+", " ", " ".join(
            s.text for s in self.segments if isinstance(s, TextSpan))).strip()

    def has_tags(self) -> bool:
        return any(not isinstance(s, TextSpan) for s in self.segments)


# parsing ------------------------------------------------------------------- #
_TAG_RE = re.compile(
    r"\[(?P<br>[^\[\]]{1,40})\]"                                 # [ ... ]
    r"|<break(?P<brk>[^>]*)/?>"                                   # <break .../>
    r"|<(?P<sil>sil|silence)\s*/?>"                               # <sil>
    r"|<emotion\s+name=\"(?P<emo>[a-zA-Z_-]+)\"(?:\s+intensity=\"(?P<emoi>[0-9.]+)\")?\s*>"
    r"|</emotion\s*>"
    r"|<(?P<lo>[a-zA-Z]{2,3})(?:-[a-zA-Z]{2})?>"                  # <en>
    r"|</(?P<lc>[a-zA-Z]{2,3})(?:-[a-zA-Z]{2})?>"                 # </en>
    r"|\[/lang\]"
    , re.IGNORECASE)


def parse_duration(s: str) -> Optional[float]:
    """'0.5' / '500ms' / '0.5s' / '1,5' -> seconds; None if not a duration."""
    s = s.strip().lower().replace(",", ".")
    m = re.fullmatch(r"(\d+(?:\.\d+)?)\s*(ms|s|sec|seconds?)?", s)
    if not m:
        return None
    val = float(m.group(1))
    unit = m.group(2) or "s"
    if unit == "ms":
        val /= 1000.0
    # a bare number > 20 is almost certainly milliseconds
    elif unit == "s" and m.group(2) is None and val > 20:
        val /= 1000.0
    return max(0.0, min(val, 30.0))


def canonical_emotion(name: str, allowed: Sequence[str] = DEFAULT_EMOTIONS
                      ) -> Optional[str]:
    n = (name or "").strip().lower()
    if not n:
        return None
    if n in allowed:
        return n
    c = EMOTION_ALIASES.get(n)
    return c if c in allowed else None


def _bracket_tag(body: str, language_codes: Sequence[str]) -> Optional[Segment]:
    """Interpret the inside of [ ... ]; None if it is not a control tag."""
    b = body.strip().lower()
    parts = [p.strip() for p in re.split(r"[:=|]", b) if p.strip()]
    if not parts:
        return None
    head = parts[0]
    if head in ("pause", "sil", "silence", "break", "wait"):
        dur = parse_duration(parts[1]) if len(parts) > 1 else None
        return PauseTag(dur)
    if head in NONVERBAL_ALIASES:
        return NonverbalTag(NONVERBAL_ALIASES[head])
    if head == "emotion" and len(parts) >= 2:
        emo = canonical_emotion(parts[1])
        if emo:
            inten = _float_or_none(parts[2]) if len(parts) > 2 else None
            return EmotionTag(emo, inten)
        return None
    emo = canonical_emotion(head)
    if emo and (len(parts) == 1 or _float_or_none(parts[1]) is not None):
        return EmotionTag(emo, _float_or_none(parts[1]) if len(parts) > 1 else None)
    if head == "lang" and len(parts) >= 2 and parts[1] in language_codes:
        return TextSpan("", language=parts[1])        # span opener marker
    return None


def _float_or_none(s: str) -> Optional[float]:
    try:
        v = float(s)
    except (TypeError, ValueError):
        return None
    return max(0.0, min(v, 1.0))


def parse_tags(text: str, language_codes: Sequence[str] = ("rw", "en", "fr", "sw")
               ) -> ParsedText:
    """Split ``text`` into text spans and control tags (see module doc)."""
    out = ParsedText()
    lang_stack: List[str] = []
    pos = 0
    buf: List[str] = []

    def flush() -> None:
        s = "".join(buf)
        buf.clear()
        if s.strip():
            out.segments.append(TextSpan(s, lang_stack[-1] if lang_stack else None))
        elif s and out.segments and isinstance(out.segments[-1], TextSpan):
            out.segments[-1].text += s

    codes = [c.lower() for c in language_codes]
    for m in _TAG_RE.finditer(text):
        buf.append(text[pos:m.start()])
        pos = m.end()
        seg: Optional[Segment] = None
        if m.group("br") is not None:
            seg = _bracket_tag(m.group("br"), codes)
            if seg is None:                         # not a tag: keep as text
                buf.append(m.group(0))
                continue
            if isinstance(seg, TextSpan):           # [lang:xx] opener
                flush()
                lang_stack.append(seg.language)
                continue
        elif m.group("brk") is not None:
            attrs = m.group("brk")
            tm = re.search(r"time\s*=\s*\"?([0-9.,]+\s*(?:ms|s)?)\"?", attrs or "")
            seg = PauseTag(parse_duration(tm.group(1)) if tm else None)
        elif m.group("sil") is not None:
            seg = PauseTag(None)
        elif m.group("emo") is not None:
            emo = canonical_emotion(m.group("emo"))
            if emo is None:
                continue
            seg = EmotionTag(emo, _float_or_none(m.group("emoi")) if m.group("emoi") else None)
        elif m.group(0).lower().startswith("</emotion"):
            continue
        elif m.group("lo") is not None:
            code = m.group("lo").lower()
            if code in codes:
                flush()
                lang_stack.append(code)
            else:
                buf.append(m.group(0))              # "<br>"-like junk: keep
            continue
        elif m.group("lc") is not None or m.group(0).lower() == "[/lang]":
            flush()
            if lang_stack:
                lang_stack.pop()
            continue
        if seg is not None:
            flush()
            out.segments.append(seg)
    buf.append(text[pos:])
    flush()
    # merge adjacent text spans with identical language
    merged: List[Segment] = []
    for s in out.segments:
        if (merged and isinstance(s, TextSpan) and isinstance(merged[-1], TextSpan)
                and merged[-1].language == s.language):
            merged[-1].text += s.text
        else:
            merged.append(s)
    out.segments = merged
    return out


def canonicalize(text: str, language_codes: Sequence[str] = ("rw", "en", "fr", "sw")
                 ) -> str:
    """Rewrite every tag in canonical ``[...]`` form (storage format)."""
    parts: List[str] = []
    for s in parse_tags(text, language_codes).segments:
        if isinstance(s, TextSpan):
            t = s.text
            parts.append(f"<{s.language}>{t.strip()}</{s.language}>" if s.language else t)
        elif isinstance(s, PauseTag):
            parts.append(f" [pause:{s.seconds:g}] " if s.seconds is not None else " [pause] ")
        elif isinstance(s, NonverbalTag):
            parts.append(f" [{s.kind}] ")
        elif isinstance(s, EmotionTag):
            parts.append(f" [{s.emotion}:{s.intensity:g}] " if s.intensity is not None
                         else f" [{s.emotion}] ")
    return re.sub(r"\s+", " ", "".join(parts)).strip()


def strip_tags(text: str, language_codes: Sequence[str] = ("rw", "en", "fr", "sw")) -> str:
    return parse_tags(text, language_codes).plain_text()


def insert_pauses(text: str, pauses: Sequence) -> str:
    """Merge a dataset's separate pause list into the text as [pause:x] tags.

    ``pauses`` items may be ``{"offset"/"char"/"position": int,
    "duration"/"seconds": float}`` dicts or ``[offset, duration]`` pairs;
    offsets are character positions in ``text`` (a pause is inserted at the
    nearest word boundary at or after the offset). Items with
    ``"word": int`` are word indices (pause after that word).
    """
    if not pauses:
        return text
    words = text.split(" ")
    # map char offset -> word index
    starts, acc = [], 0
    for w in words:
        starts.append(acc)
        acc += len(w) + 1
    inserts: List[tuple] = []
    for p in pauses:
        if isinstance(p, dict):
            dur = p.get("duration", p.get("seconds", p.get("length")))
            if "word" in p:
                wi = int(p["word"])
            else:
                off = p.get("offset", p.get("char", p.get("position", 0)))
                wi = max(i for i, s in enumerate(starts) if s <= int(off)) if starts else 0
                if int(off) > starts[wi] + len(words[wi]) // 2 and wi + 1 < len(words):
                    wi += 1
                wi = wi - 1 if wi > 0 else 0
        else:
            off, dur = p[0], (p[1] if len(p) > 1 else None)
            wi = max(i for i, s in enumerate(starts) if s <= int(off)) if starts else 0
            wi = wi - 1 if wi > 0 else 0
        inserts.append((wi, dur))
    by_word: dict = {}
    for wi, dur in inserts:
        by_word.setdefault(wi, dur)
    out: List[str] = []
    for i, w in enumerate(words):
        out.append(w)
        if i in by_word:
            d = by_word[i]
            out.append(f"[pause:{float(d):g}]" if d is not None else "[pause]")
    return " ".join(out)
