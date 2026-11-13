"""Swahili (sw): number verbalization and detection data."""
from __future__ import annotations

from typing import List

_ONES = ["sifuri", "moja", "mbili", "tatu", "nne", "tano", "sita", "saba",
         "nane", "tisa"]
_TENS = {10: "kumi", 20: "ishirini", 30: "thelathini", 40: "arobaini",
         50: "hamsini", 60: "sitini", 70: "sabini", 80: "themanini",
         90: "tisini"}


def _under_100(n: int) -> str:
    if n < 10:
        return _ONES[n]
    t, u = (n // 10) * 10, n % 10
    return _TENS[t] if u == 0 else f"{_TENS[t]} na {_ONES[u]}"


def _under_1000(n: int) -> str:
    if n < 100:
        return _under_100(n)
    h, rest = divmod(n, 100)
    head = f"mia {_ONES[h]}"
    if rest == 0:
        return head
    if rest < 10:
        return f"{head} na {_ONES[rest]}"
    return f"{head} {_under_100(rest)}"


def verbalize_number(n: int) -> str:
    if n < 0:
        return "kasoro " + verbalize_number(-n)
    if n < 1000:
        return _under_1000(n)
    parts: List[str] = []
    billions, rest = divmod(n, 1_000_000_000)
    millions, rest = divmod(rest, 1_000_000)
    lakhs, rest = divmod(rest, 100_000)          # laki = 100 000
    thousands, units = divmod(rest, 1000)
    if billions:
        parts.append(f"bilioni {_under_1000(billions)}")
    if millions:
        parts.append(f"milioni {_under_1000(millions)}")
    if lakhs:
        parts.append(f"laki {_under_100(lakhs)}")
    if thousands:
        parts.append(f"elfu {_under_100(thousands)}")
    if units:
        parts.append(("na " if parts and units < 100 else "") + _under_1000(units))
    return " ".join(parts)


COMMON_WORDS = frozenset("""
habari asante sana karibu tafadhali samahani ndiyo ndio hapana sawa
mimi wewe yeye sisi nyinyi wao yangu yako yake yetu yenu yao
hii hiyo ile hizi hizo zile huu huo ule hawa hao wale
na ya wa za la cha vya kwa katika ni si kuwa kama lakini au ama kwamba
leo kesho jana sasa baadaye tena daima kamwe bado
akaunti nambari namba simu pesa fedha malipo salio kadi mkopo huduma
mteja wateja benki ujumbe shida msaada tatizo mkutano ofisi meneja
muda siku wiki mwezi mwaka saa dakika sekunde asubuhi mchana jioni usiku
nzuri mbaya kubwa ndogo mpya mzee kwanza mwisho ijayo
moja mbili tatu nne tano sita saba nane tisa kumi ishirini mia elfu milioni
nataka nahitaji naomba ninaweza unaweza tunaweza itakuwa ilikuwa una ana nina tuna wana hana sina huna kuna hakuna
bwana bibi mama baba mtoto watoto mtu watu rafiki
""".split())

from . import LanguageSpec as _LS   # noqa: E402
SPEC = _LS(
    code="sw",
    name="Swahili",
    verbalize_number=verbalize_number,
    digit_words=_ONES,
    decimal_word="nukta",
    percent_word="asilimia",
    currency={"frw": "faranga za Rwanda", "rwf": "faranga za Rwanda",
              "$": "dola", "usd": "dola", "€": "yuro", "eur": "yuro",
              "ksh": "shilingi", "tsh": "shilingi", "shilingi": "shilingi"},
    common_words=COMMON_WORDS,
    letters="",
    suffix_hints=("ini", "eni", "isha", "esha", "iwa", "ewa", "ana", "ika"),
    forbidden_letters="qx",
    minus_word="kasoro",
)
