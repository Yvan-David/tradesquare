"""
Code-switching and named-entity front end.

Real Kinyarwanda -- especially in call centers -- is code-switched: English
words, brand names, and person names appear mid-sentence ("ejo naje kureba
Dianne ariko she disappointed me"). A character TTS trained on Kinyarwanda
text will read English *spelling* with Kinyarwanda letter-to-sound rules and
mangle it ("she" read as "s-h-e").

This module makes mixed sentences readable by rewriting foreign material into
Kinyarwanda orthography -- which is phonemic, so whatever we write is exactly
what the model will say. That is also how Rwandan speakers naturally render
English loanwords ("meeting" -> "mitingi"), so the result sounds native rather
than broken.

Three layers, in priority order:

1. ``Lexicon`` -- user-supplied pronunciations (JSON). The business-critical
   layer: exact control over product names, company names, VIP customer
   names. Ships with every model folder as ``lexicon.json``.
2. ``EN_COMMON`` -- built-in pronunciations for frequent English words.
3. ``transliterate_english`` -- rule-based fallback that converts any other
   foreign-looking word into plausible Kinyarwanda orthography.

``tag_entities`` additionally reports what was detected (named entities,
foreign words) and how each will be pronounced, for logging/QA.
"""
from __future__ import annotations

import json
import os
import re
from typing import Dict, List, Optional

# ---------------------------------------------------------------------------- #
#  User lexicon
# ---------------------------------------------------------------------------- #


class Lexicon:
    """Case-insensitive word -> pronunciation map (Kinyarwanda orthography).

    Multi-word keys are supported ("MTN Rwanda" -> "emu ti eni u rwanda").
    """

    def __init__(self, entries: Optional[Dict[str, str]] = None):
        self.entries: Dict[str, str] = {}
        for k, v in (entries or {}).items():
            self.add(k, v)

    def add(self, word: str, pronunciation: str) -> None:
        self.entries[word.strip().lower()] = pronunciation.strip().lower()

    def lookup(self, word: str) -> Optional[str]:
        return self.entries.get(word.strip().lower())

    # ------------------------------------------------------------------ #
    @classmethod
    def load(cls, path: str) -> "Lexicon":
        with open(path, "r", encoding="utf-8") as f:
            return cls(json.load(f))

    def save(self, path: str) -> None:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self.entries, f, ensure_ascii=False, indent=2,
                      sort_keys=True)

    def __len__(self) -> int:
        return len(self.entries)


# ---------------------------------------------------------------------------- #
#  Built-in pronunciations for frequent English words
#  (rendered the way Rwandan speakers commonly say them)
# ---------------------------------------------------------------------------- #
EN_COMMON: Dict[str, str] = {
    "the": "ze", "she": "shi", "he": "hi", "we": "wi", "me": "mi",
    "be": "bi", "you": "yu", "your": "yuwa", "i": "ayi", "my": "mayi",
    "is": "izi", "was": "wazi", "are": "a", "it": "iti", "its": "itsi",
    "this": "zisi", "that": "zati", "these": "zizi", "those": "zozi",
    "and": "andi", "but": "bati", "or": "oro", "not": "noti", "no": "no",
    "yes": "yesi", "ok": "okeyi", "okay": "okeyi", "so": "so", "to": "tu",
    "too": "tu", "do": "du", "does": "dazi", "did": "didi",
    "don't": "donti", "can't": "kanti", "won't": "wonti",
    "have": "havu", "has": "hazi", "had": "hadi", "will": "wili",
    "would": "wudi", "should": "shudi", "could": "kudi",
    "good": "gudi", "bad": "badi", "very": "veri", "please": "purizi",
    "sorry": "sori", "thank": "sanki", "thanks": "sankisi",
    "hello": "helo", "hi": "hayi", "bye": "bayi",
    "love": "lavu", "like": "layiki", "time": "tayimu", "money": "mane",
    "phone": "fone", "call": "kolu", "message": "meseji",
    "meeting": "mitingi", "internet": "interineti", "email": "imeyili",
    "computer": "komputa", "network": "netiworiki", "service": "serivisi",
    "customer": "kasitoma", "account": "akawunti", "bank": "banki",
    "business": "bizinesi", "office": "ofisi", "manager": "maneja",
    "report": "ripoti", "project": "purojegiti", "problem": "puroblemu",
    "one": "wani", "two": "tu", "three": "siri", "four": "foro",
    "five": "fayivu", "six": "sikisi", "seven": "seveni", "eight": "eyiti",
    "nine": "nayini", "ten": "teni",
}

# ---------------------------------------------------------------------------- #
#  Foreign-word detection
# ---------------------------------------------------------------------------- #
_VOWELS = set("aeiou")
# Kinyarwanda has no geminate consonants and (officially) no letter "l",
# "q", or "x"; native words are vowel-final; these digraphs never occur.
_FOREIGN_DIGRAPHS = ("th", "ph", "wh", "ck", "gh", "ee", "oo",
                     "ll", "tt", "ss", "pp", "dd", "ff", "bb", "gg",
                     "mm", "nn", "rr", "cc", "kk")


def is_foreign_word(word: str) -> bool:
    """Heuristic: does this word violate Kinyarwanda orthography?"""
    w = word.strip().lower()
    if not w or not w.replace("'", "").isalpha():
        return False
    if w in EN_COMMON:
        return True
    if "q" in w or "x" in w or "l" in w:
        return True
    if any(d in w for d in _FOREIGN_DIGRAPHS):
        return True
    if len(w) > 1 and w[-1] not in _VOWELS:      # native words end in vowels
        return True
    return False


# ---------------------------------------------------------------------------- #
#  Rule-based English -> Kinyarwanda-orthography transliteration
# ---------------------------------------------------------------------------- #
# Replacement outputs are UPPERCASE sentinels so that later rules (which
# match lowercase only) can never re-transform an earlier rule's output --
# e.g. "night" -> "nAYIt" stays put instead of "ayi" being re-parsed as "ai".
# Everything is lowercased at the end.
_RULES = [
    # multi-letter patterns first
    (re.compile(r"tion"), "SHENI"),
    (re.compile(r"sion"), "SHENI"),
    (re.compile(r"ough"), "O"),
    (re.compile(r"igh"), "AYI"),
    (re.compile(r"ch"), "C"),          # Kinyarwanda "c" is the /ch/ sound
    (re.compile(r"th"), "Z"),
    (re.compile(r"ph"), "F"),
    (re.compile(r"wh"), "W"),
    (re.compile(r"ck"), "K"),
    (re.compile(r"qu"), "KW"),
    (re.compile(r"q"), "K"),
    (re.compile(r"x"), "KS"),
    # magic-e vowels: like -> lAYIk-, name -> nEYIm-, note -> nOt-
    (re.compile(r"i([bcdfghjklmnprstvwz])e$"), r"AYI\1"),
    (re.compile(r"y([bcdfghjklmnprstvwz])e$"), r"AYI\1"),
    (re.compile(r"a([bcdfghjklmnprstvwz])e$"), r"EYI\1"),
    (re.compile(r"o([bcdfghjklmnprstvwz])e$"), r"O\1"),
    (re.compile(r"u([bcdfghjklmnprstvwz])e$"), r"U\1"),
    # vowel teams
    (re.compile(r"ee"), "I"),
    (re.compile(r"ea"), "I"),
    (re.compile(r"oo"), "U"),
    (re.compile(r"ou"), "AWU"),
    (re.compile(r"ow$"), "O"),
    (re.compile(r"ow"), "AWU"),
    (re.compile(r"ai"), "EYI"),
    (re.compile(r"ay"), "EYI"),
    (re.compile(r"oa"), "O"),
    (re.compile(r"oi"), "OYI"),
    (re.compile(r"oy"), "OYI"),
    (re.compile(r"aw"), "O"),
    # soft/hard c
    (re.compile(r"c(?=[eiy])"), "S"),
    (re.compile(r"c"), "K"),
    # unstressed endings
    (re.compile(r"er$"), "A"),
    (re.compile(r"le$"), "OLO"),
    # y sandwiched between consonants is a vowel ("system" -> "sistem")
    (re.compile(r"(?<=[bcdfghjkmnprstvwz])y(?=[bcdfghjkmnprstvwz])"), "I"),
    # collapse double consonants (no geminates in Kinyarwanda)
    (re.compile(r"([bcdfghjklmnprstvwz])\1"), r"\1"),
]
_CONS = "bcdfghjklmnprstvwz"          # consonants for cluster breaking
# Consonant pairs that ARE valid Kinyarwanda onsets and must not be broken.
_VALID_PAIRS = {"mb", "mp", "mf", "mv", "mw", "my", "nd", "nt", "nk", "ng",
                "nj", "nz", "ns", "nc", "ny", "sh", "cy", "jy", "ry", "rw",
                "tw", "kw", "gw", "sw", "zw", "bw", "dw", "pw", "by", "vy",
                "pf", "ts", "shy"}


def transliterate_english(word: str) -> str:
    """Approximate a foreign word in Kinyarwanda orthography.

    Priority: user lexicon (handled by callers) > EN_COMMON > these rules.
    The goal is a rendering a Rwandan speaker would recognize, spoken with
    Kinyarwanda phonology -- which is how loanwords are said in practice.
    """
    w = word.strip().lower()
    if w in EN_COMMON:
        return EN_COMMON[w]
    w = w.replace("'", "")
    for rx, rep in _RULES:
        w = rx.sub(rep, w)
    w = w.lower()
    # break consonant clusters into open syllables ("str" -> "sitir"),
    # keeping pairs that are valid Kinyarwanda onsets (nd, sh, rw, ...)
    for _ in range(3):
        out, i = [], 0
        changed = False
        while i < len(w):
            out.append(w[i])
            if (w[i] in _CONS and i + 1 < len(w) and w[i + 1] in _CONS
                    and w[i:i + 3] not in _VALID_PAIRS
                    and w[i:i + 2] not in _VALID_PAIRS):
                out.append("i")
                changed = True
            i += 1
        w = "".join(out)
        if not changed:
            break
    # drop a now-silent trailing e, then enforce a vowel-final word
    if len(w) > 2 and w.endswith("e") and w[-2] not in _VOWELS:
        w = w[:-1]
    if w and w[-1] not in _VOWELS | {"y"}:
        w += "u" if w[-1] in "bpmfvw" else "i"
    return w


# ---------------------------------------------------------------------------- #
#  Mixed-text rendering + entity tagging
# ---------------------------------------------------------------------------- #
_TOKEN_RE = re.compile(r"[A-Za-z\u00C0-\u024F']+|[^A-Za-z\u00C0-\u024F']+")
_WORD_RE = re.compile(r"^[A-Za-z\u00C0-\u024F']+$")


def render_mixed(text: str, lexicon: Optional[Lexicon] = None,
                 transliterate: bool = True) -> str:
    """Rewrite foreign words / lexicon entries so the char model reads them.

    Kinyarwanda words pass through untouched. Applied by ``normalize_text``
    before lowercasing, in both training and inference, so the model always
    sees one consistent orthography.
    """
    # whole-phrase lexicon entries first (multi-word names, brands)
    if lexicon is not None and lexicon.entries:
        for k in sorted(lexicon.entries, key=len, reverse=True):
            if " " in k or "-" in k:
                text = re.sub(re.escape(k), lexicon.entries[k], text,
                              flags=re.IGNORECASE)
    out: List[str] = []
    for tok in _TOKEN_RE.findall(text):
        if not _WORD_RE.match(tok):
            out.append(tok)
            continue
        hit = lexicon.lookup(tok) if lexicon is not None else None
        if hit is not None:
            out.append(hit)
        elif transliterate and is_foreign_word(tok):
            out.append(transliterate_english(tok))
        else:
            out.append(tok)
    return "".join(out)


def tag_entities(text: str, lexicon: Optional[Lexicon] = None) -> List[dict]:
    """Report named entities and foreign words with their pronunciations.

    Entity type is a light heuristic:
      * ``name``    -- capitalized token that is not sentence-initial
      * ``foreign`` -- word that violates Kinyarwanda orthography
      * ``lexicon`` -- covered by a user-supplied pronunciation
    """
    ents: List[dict] = []
    sentence_start = True
    for tok in _TOKEN_RE.findall(text):
        if not _WORD_RE.match(tok):
            if any(c in tok for c in ".!?"):
                sentence_start = True
            elif tok.strip():
                sentence_start = False
            continue
        low = tok.lower()
        hit = lexicon.lookup(low) if lexicon is not None else None
        foreign = is_foreign_word(low)
        is_name = tok[:1].isupper() and not sentence_start
        if hit is not None:
            ents.append({"text": tok, "type": "lexicon", "read_as": hit})
        elif is_name:
            ents.append({"text": tok, "type": "name",
                         "read_as": transliterate_english(low)
                         if foreign else low})
        elif foreign:
            ents.append({"text": tok, "type": "foreign",
                         "read_as": transliterate_english(low)})
        sentence_start = False
    return ents


def load_lexicon_if_exists(folder: str) -> Optional[Lexicon]:
    path = os.path.join(folder, "lexicon.json")
    return Lexicon.load(path) if os.path.isfile(path) else None
