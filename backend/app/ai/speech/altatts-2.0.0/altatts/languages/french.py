"""French (fr): number verbalization (with the 70/80/90 rules) and detection
data."""
from __future__ import annotations

from typing import List

_ONES = ["zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept",
         "huit", "neuf", "dix", "onze", "douze", "treize", "quatorze",
         "quinze", "seize", "dix-sept", "dix-huit", "dix-neuf"]
_TENS = {20: "vingt", 30: "trente", 40: "quarante", 50: "cinquante",
         60: "soixante"}


def _under_100(n: int) -> str:
    if n < 20:
        return _ONES[n]
    if n < 70:
        t, u = (n // 10) * 10, n % 10
        if u == 0:
            return _TENS[t]
        if u == 1:
            return f"{_TENS[t]} et un"
        return f"{_TENS[t]}-{_ONES[u]}"
    if n < 80:                               # 70-79: soixante + 10..19
        u = n - 60
        return "soixante et onze" if n == 71 else f"soixante-{_ONES[u]}"
    if n == 80:
        return "quatre-vingts"
    u = n - 80                               # 81-99: quatre-vingt + 1..19
    return f"quatre-vingt-{_ONES[u]}"


def _under_1000(n: int) -> str:
    if n < 100:
        return _under_100(n)
    h, rest = divmod(n, 100)
    if h == 1:
        head = "cent"
    else:
        head = f"{_ONES[h]} cent" + ("s" if rest == 0 else "")
    return head if rest == 0 else f"{head} {_under_100(rest)}"


def verbalize_number(n: int) -> str:
    if n < 0:
        return "moins " + verbalize_number(-n)
    if n < 1000:
        return _under_1000(n)
    parts: List[str] = []
    billions, rest = divmod(n, 1_000_000_000)
    millions, rest = divmod(rest, 1_000_000)
    thousands, units = divmod(rest, 1000)
    if billions:
        parts.append(f"{_under_1000(billions)} milliard"
                     + ("s" if billions > 1 else ""))
    if millions:
        parts.append(f"{_under_1000(millions)} million"
                     + ("s" if millions > 1 else ""))
    if thousands:
        parts.append("mille" if thousands == 1
                     else f"{_under_1000(thousands)} mille")
    if units:
        parts.append(_under_1000(units))
    return " ".join(parts)


COMMON_WORDS = frozenset("""
le la les un une des du de et ou mais si alors donc car à au aux en dans
sur sous pour par avec sans chez vers entre est sont était étaient être
avoir a ont avait j'ai je tu il elle nous vous ils elles on me te se
mon ma mes ton ta tes son sa ses notre votre leur ce cet cette ces
qui que quoi dont où quand comment pourquoi combien oui non merci
bonjour bonsoir salut au revoir s'il vous plaît pardon bienvenue
aujourd'hui demain hier maintenant toujours jamais encore déjà
compte numéro téléphone appel client service banque argent paiement
solde carte prêt virement code message réunion bureau problème aide
temps jour semaine mois année heure minute très aussi seulement
nouveau nouvelle grand petit bon bonne première dernier prochain
un deux trois quatre cinq six sept huit neuf dix cent mille million
""".split())

from . import LanguageSpec as _LS   # noqa: E402
SPEC = _LS(
    code="fr",
    name="French",
    verbalize_number=verbalize_number,
    digit_words=_ONES[:10],
    decimal_word="virgule",
    percent_word="pour cent",
    currency={"frw": "francs rwandais", "rwf": "francs rwandais",
              "$": "dollars", "usd": "dollars", "€": "euros", "eur": "euros",
              "£": "livres"},
    common_words=COMMON_WORDS,
    letters="éèêëàâäôöûüùïîçœæ",
    suffix_hints=("tion", "ment", "eux", "eau", "aux", "ais", "ait", "ées",
                  "ique", "oir", "eur"),
    forbidden_letters="",
    minus_word="moins",
)
