"""
Text front end: normalization, multilingual number verbalization, control
tags, language annotation, and the character tokenizer.

Why characters, not phonemes
----------------------------
Kinyarwanda, Swahili and (largely) French orthographies map letters to
sounds regularly; English is the odd one out, and the transformer text
encoder learns its spelling-to-sound patterns from data like every modern
character-level TTS. A character front end never fails on unseen words,
needs no G2P dictionary per language, and -- crucially for code-switching --
lets one model read ``"ejo naje kureba Dianne ariko she disappointed me"``
without deciding where one language ends. Each character additionally
carries a *language id* (detected per word, or forced with ``<en>...</en>``)
that the text encoder embeds, so the same letters can sound English in an
English word and Kinyarwanda in a Kinyarwanda one.

Pipeline (identical at training and inference)
----------------------------------------------
1. ``parse_tags``       -- split inline controls ([pause], [laugh], [happy:0.8],
                           <en>...</en>) from text (``altatts.tags``).
2. ``normalize_text``   -- per span: NFC, quotes, numbers/currency/percent
                           verbalized in the span's language, lexicon
                           pronunciations, transliteration of words from
                           languages the model was NOT trained on,
                           lowercasing, punctuation policy. Tags survive in
                           canonical form.
3. ``annotate``         -- word-level language ids.
4. ``CharTokenizer``    -- characters + special tokens -> ids (+ lang ids),
                           with the VITS blank interspersed.

Backwards compatibility: every v1 function keeps its signature
(``normalize_text(text, keep_punctuation, punctuation, do_expand_numbers,
...)``, ``CharTokenizer.encode(text, intersperse_blank)``), and a v1
``tokenizer.json`` loads unchanged.
"""
from __future__ import annotations

import json
import re
import unicodedata
from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional, Sequence, Tuple, Union

from . import tags as _tags
from .languages import (canonical_code, detect_word_language,
                        expand_numbers as _expand_numbers_lang,
                        get_language, has_language)
from .tags import (EmotionTag, NonverbalTag, PauseTag, TextSpan,
                   SPECIAL_TOKENS, parse_tags)

DEFAULT_PUNCTUATION = ".,?!;:'-"
_WS_RE = re.compile(r"\s+")
# words = runs of letters (any script in the Latin ranges) + apostrophes
_TOKEN_RE = re.compile(r"[A-Za-zÀ-ɏḀ-ỿ']+|[^A-Za-zÀ-ɏḀ-ỿ']+")
_WORD_RE = re.compile(r"^[A-Za-zÀ-ɏḀ-ỿ']+$")


# ---------------------------------------------------------------------------- #
#  v1-compatible Kinyarwanda helpers
# ---------------------------------------------------------------------------- #
def verbalize_number(n: int, lang: str = "rw") -> str:
    """Integer -> words in ``lang`` (default Kinyarwanda)."""
    return get_language(lang).verbalize_number(n)


def verbalize_digits(s: str, lang: str = "rw") -> str:
    """Digit-by-digit reading -- phone numbers, account numbers, codes."""
    return get_language(lang).verbalize_digits(s)


def expand_numbers(text: str, lang: str = "rw") -> str:
    """Verbalize digits, currency and percent in ``lang`` (default rw)."""
    return _expand_numbers_lang(text, lang)


# ---------------------------------------------------------------------------- #
#  Normalization
# ---------------------------------------------------------------------------- #
def _clean_unicode(text: str) -> str:
    text = unicodedata.normalize("NFC", text)
    text = (text.replace("’", "'").replace("‘", "'")
                .replace("“", " ").replace("”", " ")
                .replace("«", " ").replace("»", " ")
                .replace("…", "...").replace("–", "-")
                .replace("—", " - ").replace(" ", " "))
    return text


def _dominant_language(words: Sequence[str], languages: Sequence[str],
                       default: str, detect: bool) -> str:
    if not detect or len(languages) <= 1:
        return default
    counts: Dict[str, int] = {}
    prev = None
    for w in words:
        prev = detect_word_language(w, languages, default, prev)
        counts[prev] = counts.get(prev, 0) + 1
    if not counts:
        return default
    return max(counts.items(), key=lambda kv: (kv[1], kv[0] == default))[0]


def _render_span(text: str, span_lang: Optional[str], *, languages: Sequence[str],
                 default: str, detect: bool, do_expand_numbers: bool,
                 transliterate_foreign: bool, lexicon) -> str:
    """Normalize ONE text span (no tags inside): numbers, lexicon,
    transliteration. Works sentence by sentence so that numbers are read in
    the language of their own sentence in code-switched text."""
    text = _clean_unicode(text)
    # whole-phrase lexicon entries first (multi-word names, brands)
    if lexicon is not None and getattr(lexicon, "entries", None):
        for k in sorted(lexicon.entries, key=len, reverse=True):
            if " " in k or "-" in k:
                text = re.sub(re.escape(k), lexicon.entries[k], text,
                              flags=re.IGNORECASE)
    pieces = re.split(r"((?<=[.?!;])\s+)", text)      # keep the separators
    out: List[str] = []
    for piece in pieces:
        if not piece or piece.isspace():
            out.append(piece)
            continue
        out.append(_render_sentence(
            piece, span_lang, languages=languages, default=default,
            detect=detect, do_expand_numbers=do_expand_numbers,
            transliterate_foreign=transliterate_foreign, lexicon=lexicon))
    return "".join(out)


def _render_sentence(text: str, span_lang: Optional[str], *, languages: Sequence[str],
                     default: str, detect: bool, do_expand_numbers: bool,
                     transliterate_foreign: bool, lexicon) -> str:
    from .lexicon import EN_COMMON, is_foreign_word, transliterate_english
    toks = _TOKEN_RE.findall(text)
    words = [t for t in toks if _WORD_RE.match(t)]
    num_lang = span_lang or _dominant_language(words, languages, default, detect)
    if do_expand_numbers and any(ch.isdigit() for ch in text):
        text = _expand_numbers_lang(text, num_lang if has_language(num_lang)
                                    else default)
        toks = _TOKEN_RE.findall(text)
    out: List[str] = []
    prev_lang: Optional[str] = None
    multilingual = detect and len(languages) > 1
    for tok in toks:
        if not _WORD_RE.match(tok):
            out.append(tok)
            continue
        hit = lexicon.lookup(tok) if lexicon is not None else None
        if hit is not None:
            out.append(hit)
            continue
        if span_lang is not None:
            out.append(tok)                      # forced span: keep as is
            continue
        if multilingual:
            # every detected language is a TRAINED language: keep spelling
            prev_lang = detect_word_language(tok, languages, default, prev_lang)
            out.append(tok)
            continue
        low = tok.lower()
        # single-language model: words that violate the primary language's
        # orthography come from an untrained language -> transliterate them
        # into the primary orthography (Kinyarwanda rules) so the model reads
        # them the way native speakers pronounce loanwords.
        if (transliterate_foreign and default == "rw"
                and (low in EN_COMMON or is_foreign_word(low))):
            out.append(transliterate_english(low))
        else:
            out.append(tok)
    return "".join(out)


def _police(text: str, keep_punctuation: bool, punctuation: str,
            extra_letters: str = "") -> str:
    kept = set(punctuation) if keep_punctuation else set()
    out = []
    for ch in text:
        if ch.isalpha() or ch == " " or ch in kept:
            out.append(ch)
        elif ch in extra_letters:
            out.append(ch)
        else:
            out.append(" ")          # dropped symbols never glue two words
    return _WS_RE.sub(" ", "".join(out)).strip()


def normalize_text(text: str, keep_punctuation: bool = True,
                   punctuation: str = DEFAULT_PUNCTUATION,
                   do_expand_numbers: bool = True, *,
                   transliterate_foreign: bool = False,
                   lexicon=None,
                   language: Optional[str] = None,
                   languages: Sequence[str] = ("rw",),
                   detect_languages: bool = True,
                   keep_tags: bool = True) -> str:
    """Lowercase NFC text with numbers verbalized, punctuation policed, and
    control tags preserved in canonical form.

    ``language``   the utterance's language (record-level). ``None`` = the
                   first entry of ``languages`` (the model's primary).
    ``languages``  languages the model was trained on; words detected in one
                   of them keep their orthography and get that language's
                   id, words from untrained languages are transliterated
                   into the primary language's orthography when
                   ``transliterate_foreign`` is set.
    ``keep_tags``  False strips all control tags (for ASR scoring).
    """
    languages = [canonical_code(c, c) for c in (languages or ("rw",))]
    default = canonical_code(language, languages[0]) if language else languages[0]
    if default not in languages:
        default = languages[0]
    parsed = parse_tags(text, languages)
    parts: List[str] = []
    for seg in parsed.segments:
        if isinstance(seg, TextSpan):
            span_lang = canonical_code(seg.language, default) if seg.language else None
            rendered = _render_span(
                seg.text, span_lang, languages=languages, default=default,
                detect=detect_languages, do_expand_numbers=do_expand_numbers,
                transliterate_foreign=transliterate_foreign, lexicon=lexicon)
            rendered = _police(rendered.lower(), keep_punctuation, punctuation)
            if not rendered:
                continue
            if keep_tags and span_lang and span_lang != default:
                parts.append(f"<{span_lang}>{rendered}</{span_lang}>")
            else:
                parts.append(rendered)
        elif not keep_tags:
            continue
        elif isinstance(seg, PauseTag):
            parts.append(f"[pause:{seg.seconds:g}]" if seg.seconds is not None
                         else "[pause]")
        elif isinstance(seg, NonverbalTag):
            parts.append(f"[{seg.kind}]")
        elif isinstance(seg, EmotionTag):
            parts.append(f"[{seg.emotion}:{seg.intensity:g}]"
                         if seg.intensity is not None else f"[{seg.emotion}]")
    return _WS_RE.sub(" ", " ".join(parts)).strip()


def strip_punctuation(text: str,
                      punctuation: str = DEFAULT_PUNCTUATION) -> str:
    text = "".join(" " if c in set(punctuation) else c for c in text)
    return _WS_RE.sub(" ", text).strip()


def plain_text(text: str, languages: Sequence[str] = ("rw", "en", "fr", "sw")) -> str:
    """Remove every control tag / span marker (what a listener hears)."""
    return _tags.strip_tags(text, languages)


# ---------------------------------------------------------------------------- #
#  Sentence splitting & synthesis planning
# ---------------------------------------------------------------------------- #
_SENT_END = re.compile(r"(?<=[.?!;])\s+")


def split_sentences(text: str, languages: Sequence[str] = ("rw", "en", "fr", "sw")
                    ) -> List[str]:
    """Split text into synthesizable phrases at sentence-final punctuation,
    keeping the punctuation (it drives terminal prosody) and keeping control
    tags with the phrase they belong to. Language spans are re-closed in
    every phrase so each piece is self-contained."""
    parsed = parse_tags(text, languages)
    phrases: List[str] = []
    cur: List[str] = []

    def emit() -> None:
        s = _WS_RE.sub(" ", " ".join(cur)).strip()
        cur.clear()
        if s:
            phrases.append(s)

    for seg in parsed.segments:
        if isinstance(seg, TextSpan):
            pieces = [p for p in _SENT_END.split(seg.text.strip()) if p.strip()]
            for i, p in enumerate(pieces):
                p = p.strip()
                if seg.language:
                    p = f"<{seg.language}>{p}</{seg.language}>"
                cur.append(p)
                if i != len(pieces) - 1:
                    emit()
            # if the span ended with sentence punctuation, close the phrase
            if seg.text.rstrip()[-1:] in ".?!;":
                emit()
        elif isinstance(seg, PauseTag):
            cur.append(f"[pause:{seg.seconds:g}]" if seg.seconds is not None
                       else "[pause]")
        elif isinstance(seg, NonverbalTag):
            cur.append(f"[{seg.kind}]")
        elif isinstance(seg, EmotionTag):
            cur.append(f"[{seg.emotion}:{seg.intensity:g}]"
                       if seg.intensity is not None else f"[{seg.emotion}]")
    emit()
    return phrases


@dataclass
class Chunk:
    """One model call: canonical text (with inline tokens), style state."""
    text: str
    emotion: Optional[str] = None
    intensity: Optional[float] = None


@dataclass
class Silence:
    seconds: float


def plan_chunks(text: str, *, languages: Sequence[str] = ("rw",),
                sentence_split: bool = True, pause_token_known: bool = False,
                nonverbals_known: Iterable[str] = (),
                default_pause_s: float = 0.35,
                emotion: Optional[str] = None,
                intensity: Optional[float] = None
                ) -> List[Union[Chunk, Silence]]:
    """Turn user text into an ordered plan of model calls and exact silences.

    * ``[pause:x]`` always becomes an exact :class:`Silence` (call centers
      need deterministic timing);
    * ``[pause]`` stays an inline token when the model learned one, else it
      becomes ``default_pause_s`` of silence;
    * non-verbal tags unknown to the model are dropped (a warning is the
      caller's job); known ones stay inline;
    * emotion tags update the running emotion state for following chunks;
    * sentences are split so streaming can start after the first phrase.
    """
    nonverbals_known = set(nonverbals_known)
    plan: List[Union[Chunk, Silence]] = []
    cur_emotion, cur_intensity = emotion, intensity
    buf: List[str] = []

    def flush() -> None:
        s = _WS_RE.sub(" ", " ".join(buf)).strip()
        buf.clear()
        if not s:
            return
        if _tags.strip_tags(s, languages).strip() == "" and "[" in s:
            # only tokens (e.g. a lone [laugh]) -- still a valid chunk if the
            # model knows the tokens, otherwise nothing to say
            if not any(f"[{k}]" in s for k in nonverbals_known) and "[pause]" not in s:
                return
        parts = split_sentences(s, languages) if sentence_split else [s]
        for p in parts:
            plan.append(Chunk(p, cur_emotion, cur_intensity))

    for seg in parse_tags(text, languages).segments:
        if isinstance(seg, TextSpan):
            buf.append(f"<{seg.language}>{seg.text.strip()}</{seg.language}>"
                       if seg.language else seg.text)
        elif isinstance(seg, PauseTag):
            if seg.seconds is not None:
                flush()
                plan.append(Silence(seg.seconds))
            elif pause_token_known:
                buf.append("[pause]")
            else:
                flush()
                plan.append(Silence(default_pause_s))
        elif isinstance(seg, NonverbalTag):
            if seg.kind in nonverbals_known:
                buf.append(f"[{seg.kind}]")
            # else: dropped
        elif isinstance(seg, EmotionTag):
            flush()
            cur_emotion = seg.emotion
            cur_intensity = seg.intensity if seg.intensity is not None else intensity
    flush()
    # merge consecutive silences
    merged: List[Union[Chunk, Silence]] = []
    for item in plan:
        if (merged and isinstance(item, Silence) and isinstance(merged[-1], Silence)):
            merged[-1] = Silence(merged[-1].seconds + item.seconds)
        else:
            merged.append(item)
    return merged


# ---------------------------------------------------------------------------- #
#  Language annotation (per character)
# ---------------------------------------------------------------------------- #
def annotate_languages(norm_text: str, languages: Sequence[str],
                       default: Optional[str] = None, detect: bool = True
                       ) -> List[Tuple[str, int]]:
    """Normalized text (may contain canonical tags) -> [(symbol, lang_id)].

    Symbols are single characters or whole special tokens ("[pause]").
    ``lang_id`` indexes ``languages``; the default language gets the id of
    its position (0 for the primary language)."""
    languages = list(languages) or ["rw"]
    default = default if default in languages else languages[0]
    d_id = languages.index(default)
    out: List[Tuple[str, int]] = []
    for seg in parse_tags(norm_text, languages).segments:
        if isinstance(seg, PauseTag):
            out.append(("[pause]", d_id))
        elif isinstance(seg, NonverbalTag):
            out.append((f"[{seg.kind}]", d_id))
        elif isinstance(seg, EmotionTag):
            continue
        else:
            span_lang = seg.language if seg.language in languages else None
            prev = span_lang
            for tok in _TOKEN_RE.findall(seg.text):
                if _WORD_RE.match(tok) and span_lang is None and detect and len(languages) > 1:
                    lang = detect_word_language(tok, languages, default, prev)
                    prev = lang
                else:
                    lang = span_lang or (prev if (prev and not _WORD_RE.match(tok)) else default)
                lid = languages.index(lang) if lang in languages else d_id
                out.extend((ch, lid) for ch in tok)
    # collapse runs of whitespace produced by span boundaries
    cleaned: List[Tuple[str, int]] = []
    for sym, lid in out:
        if sym == " " and cleaned and cleaned[-1][0] == " ":
            continue
        cleaned.append((sym, lid))
    while cleaned and cleaned[0][0] == " ":
        cleaned.pop(0)
    while cleaned and cleaned[-1][0] == " ":
        cleaned.pop()
    return cleaned


# ---------------------------------------------------------------------------- #
#  Tokenizer
# ---------------------------------------------------------------------------- #
class CharTokenizer:
    """Character + special-token vocabulary; id 0 = blank/pad ("_").

    v2 adds special tokens (``[pause]``, ``[laugh]``, ...) and a language
    list so ``encode_full`` can return per-token language ids. A v1
    ``tokenizer.json`` (characters only) loads unchanged.
    """

    BLANK = "_"

    def __init__(self, symbols: List[str], specials: Optional[Sequence[str]] = None,
                 languages: Optional[Sequence[str]] = None):
        if not symbols or symbols[0] != self.BLANK:
            symbols = [self.BLANK] + [s for s in symbols if s != self.BLANK]
        self.symbols = list(symbols)
        self.sym2id = {s: i for i, s in enumerate(self.symbols)}
        self.specials = [s for s in (specials or []) if s in self.sym2id]
        self.languages = list(languages or ["rw"])

    # -- construction --------------------------------------------------------- #
    @classmethod
    def build(cls, texts: Iterable[str], specials: Sequence[str] = SPECIAL_TOKENS,
              languages: Sequence[str] = ("rw",)) -> "CharTokenizer":
        """Vocabulary = every character of the (normalized) training texts
        + the special tokens. Special tokens are always included so a model
        can later be fine-tuned on tagged data without a vocabulary change."""
        chars = set()
        for t in texts:
            for seg in parse_tags(t, languages).segments:
                if isinstance(seg, TextSpan):
                    chars.update(seg.text)
        chars.discard(cls.BLANK)
        syms = [cls.BLANK] + sorted(chars) + [s for s in specials if s not in chars]
        return cls(syms, specials=specials, languages=languages)

    # -- persistence ----------------------------------------------------------- #
    def save(self, path: str) -> None:
        with open(path, "w", encoding="utf-8") as fh:
            json.dump({"type": "char", "version": 2, "symbols": self.symbols,
                       "specials": self.specials, "languages": self.languages},
                      fh, ensure_ascii=False, indent=2)

    @classmethod
    def load(cls, path: str) -> "CharTokenizer":
        with open(path, "r", encoding="utf-8") as fh:
            d = json.load(fh)
        return cls(d["symbols"], specials=d.get("specials"),
                   languages=d.get("languages") or ["rw"])

    # -- encode/decode ---------------------------------------------------------- #
    @property
    def pause_id(self) -> Optional[int]:
        return self.sym2id.get("[pause]")

    def known_nonverbals(self) -> List[str]:
        return [s[1:-1] for s in self.specials if s != "[pause]"]

    def has_special(self, token: str) -> bool:
        return token in self.sym2id and token in self.specials

    def _intersperse(self, ids: List[int], lang_ids: Optional[List[int]] = None):
        out = [0] * (len(ids) * 2 + 1)
        out[1::2] = ids
        if lang_ids is None:
            return out, None
        # the blank between two symbols takes the language of the symbol
        # on its left (the first blank takes the first symbol's language)
        lo = [0] * (len(ids) * 2 + 1)
        lo[1::2] = lang_ids
        for i in range(0, len(lo), 2):
            lo[i] = lo[i + 1] if i + 1 < len(lo) else (lo[i - 1] if i else 0)
        return out, lo

    def encode(self, text: str, intersperse_blank: bool = True) -> List[int]:
        """Normalized text -> ids (v1 signature). Tags become special-token
        ids when known, otherwise they are skipped."""
        ids, _ = self.encode_full(text, intersperse_blank, detect_languages=False)
        return ids

    def encode_full(self, text: str, intersperse_blank: bool = True,
                    default_language: Optional[str] = None,
                    detect_languages: bool = True
                    ) -> Tuple[List[int], List[int]]:
        """Normalized text -> (ids, lang_ids), both the same length."""
        pairs = annotate_languages(text, self.languages, default_language,
                                   detect=detect_languages)
        ids, lids = [], []
        space = self.sym2id.get(" ")
        for sym, lid in pairs:
            i = self.sym2id.get(sym)
            if i is None:
                continue
            if i == space and (not ids or ids[-1] == space):
                continue                      # no leading / doubled spaces
            ids.append(i)
            lids.append(lid)
        while ids and ids[-1] == space:       # no trailing space either
            ids.pop()
            lids.pop()
        if not intersperse_blank:
            return ids, lids
        out, lo = self._intersperse(ids, lids)
        return out, lo

    def decode(self, ids: List[int]) -> str:
        return "".join(self.symbols[i] for i in ids if 0 < i < len(self.symbols))

    def __len__(self) -> int:
        return len(self.symbols)


def build_tokenizer(texts: Iterable[str], specials: Sequence[str] = SPECIAL_TOKENS,
                    languages: Sequence[str] = ("rw",)) -> CharTokenizer:
    return CharTokenizer.build(texts, specials=specials, languages=languages)


def load_tokenizer(path: str) -> CharTokenizer:
    return CharTokenizer.load(path)
