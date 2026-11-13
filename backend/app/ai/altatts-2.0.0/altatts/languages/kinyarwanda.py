"""Kinyarwanda (rw): number verbalization and detection data."""
from __future__ import annotations

from typing import List

_DIGITS = {0: "zeru", 1: "rimwe", 2: "kabiri", 3: "gatatu", 4: "kane",
           5: "gatanu", 6: "gatandatu", 7: "karindwi", 8: "umunani",
           9: "icyenda"}
_TENS = {10: "icumi", 20: "makumyabiri", 30: "mirongo itatu",
         40: "mirongo ine", 50: "mirongo itanu", 60: "mirongo itandatu",
         70: "mirongo irindwi", 80: "mirongo inani", 90: "mirongo icyenda"}
_HUNDREDS = {100: "ijana", 200: "magana abiri", 300: "magana atatu",
             400: "magana ane", 500: "magana atanu", 600: "magana atandatu",
             700: "magana arindwi", 800: "magana inani", 900: "magana cyenda"}


def _under_1000(n: int) -> str:
    parts: List[str] = []
    if n >= 100:
        parts.append(_HUNDREDS[(n // 100) * 100])
        n %= 100
    if n >= 10:
        parts.append(_TENS[(n // 10) * 10])
        n %= 10
    if n:
        parts.append(_DIGITS[n])
    return " na ".join(parts) if parts else _DIGITS[0]


def _thousands(n: int) -> str:
    """1..999 thousands: igihumbi / ibihumbi <count>."""
    if n == 1:
        return "igihumbi"
    counts = {1: "kimwe", 2: "bibiri", 3: "bitatu", 4: "bine", 5: "bitanu",
              6: "bitandatu", 7: "birindwi", 8: "umunani", 9: "icyenda"}
    parts = []
    if n >= 100:
        parts.append(_HUNDREDS[(n // 100) * 100])
        n %= 100
    if n >= 10:
        parts.append(_TENS[(n // 10) * 10])
        n %= 10
    if n:
        parts.append(counts[n])
    return "ibihumbi " + " na ".join(parts)


def verbalize_number(n: int) -> str:
    """Integer -> Kinyarwanda words (counting forms), 0 .. 999,999,999,999."""
    if n < 0:
        return "minus " + verbalize_number(-n)
    if n < 1000:
        return _under_1000(n)
    parts: List[str] = []
    billions, rest = divmod(n, 1_000_000_000)
    millions, rest = divmod(rest, 1_000_000)
    thousands, units = divmod(rest, 1000)
    if billions:
        parts.append("miliyari " + ("imwe" if billions == 1
                                    else _under_1000(billions)))
    if millions:
        parts.append("miliyoni " + ("imwe" if millions == 1
                                    else _under_1000(millions)))
    if thousands:
        parts.append(_thousands(thousands))
    if units:
        parts.append(_under_1000(units))
    return " na ".join(parts)


COMMON_WORDS = frozenset("""
muraho murakoze amakuru yawe neza cyane mwiriwe mwaramutse ndabashimiye
umunsi mwiza ibyo iki iyo uyu uwo aba abo ibi ibyo bya cya rya wa ya za
kandi ariko cyangwa kuko kugira ngo nta ntabwo nti oya yego ni si na mu ku ya wa bya cya rya za ba ry'
turi muri ndi uri bari ari twe mwe bo wowe jye njye we yewe
umuntu abantu umwana abana umugabo umugore abagabo abagore
amafaranga ifaranga ibihumbi igihumbi ijana magana miliyoni
konti nimero telefoni ubutumwa serivisi ikibazo ibibazo igisubizo
kugura kugurisha kwishyura kwakira gukora gusaba gufasha kuvuga
ubufasha umukozi abakozi umukiriya abakiriya banki ivuriro ibitaro
umuganga ubuzima imiti leta komini akarere umurenge umudugudu
ejo none uyu munsi mu gitondo ku mugoroba icyumweru ukwezi umwaka
kanda kanda rimwe kabiri gatatu kane gatanu gatandatu karindwi umunani
icyenda icumi rimwe amahirwe ikaze murakaza mukomere nibyo byose
igihe aho hano hariya iki gihe ubu nyuma mbere hagati
nkunda nshaka ndashaka ndabizi sinzi tuzaza tuzabona
""".split())

SPEC_KW = dict(
    code="rw",
    name="Kinyarwanda",
    verbalize_number=verbalize_number,
    digit_words=[_DIGITS[i] for i in range(10)],
    decimal_word="n'ibice",
    percent_word="ku ijana",
    currency={"frw": "<amafaranga", "rwf": "<amafaranga",
              "faranga": "<amafaranga", "amafaranga": "<amafaranga",
              "$": "<amadolari", "usd": "<amadolari",
              "€": "<amayero", "eur": "<amayero"},
    common_words=COMMON_WORDS,
    letters="",
    suffix_hints=("ye", "we", "ze", "nga", "nza", "kora", "shaka", "mbwa"),
    # no l, q, x in native Kinyarwanda words
    forbidden_letters="lqx",
    minus_word="minus",
)

def _is_native(word: str) -> bool:
    from ..lexicon import is_foreign_word
    return not is_foreign_word(word)


from . import LanguageSpec as _LS   # noqa: E402  (registered by the package)
SPEC = _LS(is_native=_is_native, **SPEC_KW)
