"""English (en): number verbalization and detection data."""
from __future__ import annotations

from typing import List

_ONES = ["zero", "one", "two", "three", "four", "five", "six", "seven",
         "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen",
         "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
_TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
         "eighty", "ninety"]
_SCALES = [(1_000_000_000_000, "trillion"), (1_000_000_000, "billion"),
           (1_000_000, "million"), (1000, "thousand")]


def _under_1000(n: int) -> str:
    parts: List[str] = []
    if n >= 100:
        parts.append(f"{_ONES[n // 100]} hundred")
        n %= 100
        if n:
            parts.append("and")
    if n >= 20:
        t = _TENS[n // 10]
        parts.append(f"{t} {_ONES[n % 10]}" if n % 10 else t)
    elif n:
        parts.append(_ONES[n])
    return " ".join(parts)


def verbalize_number(n: int) -> str:
    if n < 0:
        return "minus " + verbalize_number(-n)
    if n < 1000:
        return _under_1000(n) if n else "zero"
    parts: List[str] = []
    for value, word in _SCALES:
        if n >= value:
            parts.append(f"{_under_1000(n // value)} {word}")
            n %= value
    if n:
        parts.append(_under_1000(n))
    return " ".join(parts)


COMMON_WORDS = frozenset("""
the a an and or but if then so of to in on at by for with from about as
is are was were be been being am do does did done have has had will would
shall should can could may might must not no yes ok okay please thank
thanks sorry hello hi hey bye goodbye welcome good morning afternoon evening
night today tomorrow yesterday now later soon again always never sometimes
i you he she it we they me him her us them my your his its our their this
that these those who what when where why how which here there
one two three four five six seven eight nine ten hundred thousand million
account number phone call customer service bank money payment balance card
loan transfer pin password code message meeting office manager report
problem help support time day week month year hour minute second
very really just also only more most less much many some any all every
new old big small long short high low right left first last next
""".split())

from . import LanguageSpec as _LS   # noqa: E402
SPEC = _LS(
    code="en",
    name="English",
    verbalize_number=verbalize_number,
    digit_words=_ONES[:10],
    decimal_word="point",
    percent_word="percent",
    currency={"frw": "Rwandan francs", "rwf": "Rwandan francs",
              "$": "dollars", "usd": "dollars", "€": "euros", "eur": "euros",
              "£": "pounds", "gbp": "pounds", "ksh": "shillings",
              "tsh": "shillings"},
    common_words=COMMON_WORDS,
    letters="",
    suffix_hints=("ing", "tion", "ness", "ment", "ly", "ed", "ght", "ck",
                  "th", "sh"),
    forbidden_letters="",
    minus_word="minus",
)
