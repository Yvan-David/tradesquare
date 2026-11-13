"""
Language registry for the ALTATTS text front end.

ALTATTS speaks code-switched text (Kinyarwanda, English, French, Swahili --
and anything registered later) from ONE model. This package holds, per
language, everything the front end needs that is language specific:

* number / currency / percent verbalization (``125 FRW`` is read differently
  in each language),
* a short list of very frequent words used for word-level language
  detection in code-switched sentences,
* orthographic hints (letters, accents) that make detection robust.

Adding a language is a data task, not a code change: create a module with a
:class:`LanguageSpec` and call :func:`register_language` (or drop a JSON
file next to the model, see ``docs/USAGE.md`` section "Adding a language").

Public helpers
--------------
``get_language(code)``            -> LanguageSpec (raises KeyError)
``available_languages()``         -> sorted codes
``detect_word_language(word, candidates, default)`` -> code
``expand_numbers(text, lang)``    -> text with digits verbalized in ``lang``
"""
from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from typing import Callable, Dict, FrozenSet, List, Optional, Sequence


@dataclass
class LanguageSpec:
    code: str                                   # ISO 639-1 ("rw", "en", ...)
    name: str
    verbalize_number: Callable[[int], str]      # 125 -> words
    digit_words: Sequence[str]                  # 0..9 read digit by digit
    decimal_word: str                           # "point" / "virgule" ...
    percent_word: str
    currency: Dict[str, str] = field(default_factory=dict)   # "frw" -> words
    common_words: FrozenSet[str] = frozenset()  # frequent words for detection
    letters: str = ""                           # letters beyond a-z (accents)
    # words ending patterns that are strong signals for this language
    suffix_hints: Sequence[str] = ()
    # characters that (almost) never occur in native words of this language
    forbidden_letters: str = ""
    minus_word: str = "minus"
    # optional orthography test: False when a word cannot be native (e.g. a
    # consonant-final word in Kinyarwanda). Used as negative evidence.
    is_native: Optional[Callable[[str], bool]] = None

    def verbalize_digits(self, s: str) -> str:
        return " ".join(self.digit_words[int(c)] for c in s if c.isdigit())


_REGISTRY: Dict[str, LanguageSpec] = {}


def register_language(spec: LanguageSpec) -> None:
    _REGISTRY[spec.code] = spec


def get_language(code: str) -> LanguageSpec:
    code = (code or "").strip().lower()
    if code in _REGISTRY:
        return _REGISTRY[code]
    # accept BCP-47 style tags ("en-US", "fr_FR", "rw-RW")
    short = re.split(r"[-_]", code)[0]
    if short in _REGISTRY:
        return _REGISTRY[short]
    raise KeyError(f"unknown language {code!r}; registered: "
                   f"{sorted(_REGISTRY)}")


def has_language(code: str) -> bool:
    try:
        get_language(code)
        return True
    except KeyError:
        return False


def available_languages() -> List[str]:
    return sorted(_REGISTRY)


#: values of a record's ``language`` field that mean "several languages in
#: one utterance" (code-switching). They are not a language: the record
#: takes the model's primary language and words are detected individually.
MIXED_CODES = frozenset({"mixed", "cs", "code-switch", "code-switching",
                         "code_switching", "codeswitch", "multi",
                         "multilingual", "mix"})

#: ISO 639-3 / long-name spellings accepted everywhere a code is expected
LANGUAGE_ALIASES = {"kinyarwanda": "rw", "kin": "rw", "rw-rw": "rw", "ikinyarwanda": "rw",
                    "english": "en", "eng": "en",
                    "french": "fr", "fra": "fr", "fre": "fr", "francais": "fr",
                    "français": "fr",
                    "swahili": "sw", "kiswahili": "sw", "swa": "sw"}


def is_mixed_code(code: Optional[str]) -> bool:
    return bool(code) and code.strip().lower() in MIXED_CODES


def canonical_code(code: Optional[str], default: str = "rw") -> str:
    """'en-US' / 'eng' / 'English' -> 'en', 'kin' -> 'rw', None -> default."""
    if not code:
        return default
    c = code.strip().lower()
    if c in MIXED_CODES:
        return default
    c = LANGUAGE_ALIASES.get(c, c)
    c = re.split(r"[-_]", c)[0]
    c = LANGUAGE_ALIASES.get(c, c)
    return c if c in _REGISTRY else default


# --------------------------------------------------------------------------- #
#  Number expansion (language dispatched)
# --------------------------------------------------------------------------- #
_NUM_RE = re.compile(r"\d[\d.,]*")
_SPACE_NUM_RE = re.compile(r"(?<=\d)[  ](?=\d{3}\b)")   # 2 500 -> 2500


def expand_numbers(text: str, lang: str = "rw", max_digits_as_number: int = 9) -> str:
    """Verbalize digits/amounts in ``text`` with the rules of ``lang``.

    * currency codes/symbols become words (``FRW 2500`` -> ``amafaranga ...``),
    * ``%`` becomes the percent word,
    * long digit strings (phone/account numbers, > ``max_digits_as_number``
      digits) and numbers with a leading zero are read digit by digit,
    * decimals are read as integer part + decimal word + digits.
    """
    spec = get_language(lang)
    text = _SPACE_NUM_RE.sub("", text)
    # currency codes before/after the amount -> currency word AFTER number
    # (all four languages put the currency noun after the amount in speech:
    #  "amafaranga ..." is the exception and goes before -- handled per spec
    #  by the placement flag encoded in the mapping value prefix "<").
    for key, words in spec.currency.items():
        before = words.startswith("<")
        words_clean = words.lstrip("<").strip()
        num = r"(\d(?:[\d.,]*\d)?)"          # never swallow a trailing comma
        pat_before = re.compile(rf"(?i)(?<![A-Za-z]){re.escape(key)}(?![A-Za-z])\s*{num}")
        pat_after = re.compile(rf"(?i){num}\s*{re.escape(key)}(?![A-Za-z])")
        if before:
            text = pat_before.sub(lambda m: f"{words_clean} {m.group(1)}", text)
            text = pat_after.sub(lambda m: f"{words_clean} {m.group(1)}", text)
        else:
            text = pat_before.sub(lambda m: f"{m.group(1)} {words_clean}", text)
            text = pat_after.sub(lambda m: f"{m.group(1)} {words_clean}", text)
    text = text.replace("%", f" {spec.percent_word}")

    def _repl(m: "re.Match") -> str:
        raw = m.group(0).rstrip(".,")
        trailing = m.group(0)[len(raw):]
        digits_only = raw.replace(",", "").replace(".", "")
        if not digits_only:
            return m.group(0)
        if len(digits_only) > max_digits_as_number or (
                raw.startswith("0") and len(digits_only) > 1):
            return spec.verbalize_digits(digits_only) + trailing
        # thousands separators: "2,500" (en) or "2.500" (fr) -- a separator
        # followed by exactly three digits and no other separator is a
        # thousands separator; otherwise the LAST separator is the decimal
        # point.
        sep_count = raw.count(".") + raw.count(",")
        if sep_count == 1 and re.fullmatch(r"\d{1,3}[.,]\d{3}", raw):
            return spec.verbalize_number(int(digits_only)) + trailing
        if "." in raw or "," in raw:
            cut = max(raw.rfind("."), raw.rfind(","))
            ip, fp = raw[:cut].replace(",", "").replace(".", ""), raw[cut + 1:]
            ip_words = spec.verbalize_number(int(ip or 0))
            return f"{ip_words} {spec.decimal_word} {spec.verbalize_digits(fp)}" + trailing
        return spec.verbalize_number(int(digits_only)) + trailing

    return _NUM_RE.sub(_repl, text)


# --------------------------------------------------------------------------- #
#  Word-level language detection for code-switching
# --------------------------------------------------------------------------- #
def _strip_accents(w: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", w)
                   if unicodedata.category(c) != "Mn")


def is_currency_token(word: str) -> bool:
    w = word.strip().lower()
    return any(w in spec.currency for spec in _REGISTRY.values())


def detect_word_language(word: str, candidates: Sequence[str],
                         default: str, previous: Optional[str] = None) -> str:
    """Pick the most likely language of one word among ``candidates``.

    Evidence, in order: frequent-word lists (strongest), letters that only
    exist in one candidate language (accents), suffix hints, orthographic
    violations of the default language. Ties go to ``previous`` (words tend
    to come in same-language runs) and then to ``default``. Pure heuristics
    -- cheap, deterministic, and good enough because the model also sees the
    surrounding characters.
    """
    w = word.strip().lower().strip("'")
    if not w or not any(ch.isalpha() for ch in w) or is_currency_token(w):
        return previous or default
    cands = [c for c in candidates if c in _REGISTRY] or [default]
    if len(cands) == 1:
        return cands[0]
    scores = {c: 0.0 for c in cands}
    plain = _strip_accents(w)
    for c in cands:
        spec = _REGISTRY[c]
        if w in spec.common_words or plain in spec.common_words:
            scores[c] += 3.0
        if spec.letters and any(ch in spec.letters for ch in w):
            scores[c] += 1.5
        if any(w.endswith(s) for s in spec.suffix_hints):
            scores[c] += 1.0
        if spec.forbidden_letters and any(ch in spec.forbidden_letters
                                          for ch in plain):
            scores[c] -= 2.0
        if spec.is_native is not None and not spec.is_native(plain):
            scores[c] -= 2.0
    best = max(scores.values())
    winners = [c for c, s in scores.items() if s == best]
    if len(winners) == 1 and best > 0:
        return winners[0]
    if best <= 0:
        # nothing positive: default language unless it is orthographically
        # impossible there (then the previous word's language, else the
        # first other candidate)
        if default in cands and scores.get(default, 0) >= 0:
            return default
        if previous in cands and scores.get(previous, 0) >= best:
            return previous
        return winners[0]
    if previous in winners:
        return previous
    if default in winners:
        return default
    return winners[0]


# register the built-in languages ------------------------------------------- #
from . import kinyarwanda as _rw   # noqa: E402
from . import english as _en       # noqa: E402
from . import french as _fr        # noqa: E402
from . import swahili as _sw       # noqa: E402

register_language(_rw.SPEC)
register_language(_en.SPEC)
register_language(_fr.SPEC)
register_language(_sw.SPEC)

__all__ = ["LanguageSpec", "register_language", "get_language",
           "has_language", "available_languages", "canonical_code",
           "is_mixed_code", "MIXED_CODES", "LANGUAGE_ALIASES",
           "expand_numbers", "detect_word_language", "is_currency_token"]
