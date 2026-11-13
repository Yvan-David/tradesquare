"""Torch-free: languages, tags, normalization, tokenizer (v1 + v2)."""
import json

import pytest

from altatts.languages import (available_languages, canonical_code,
                               detect_word_language, expand_numbers,
                               get_language)
from altatts.tags import (canonicalize, insert_pauses, parse_duration,
                          parse_tags, strip_tags, PauseTag, NonverbalTag,
                          EmotionTag, TextSpan, SPECIAL_TOKENS)
from altatts.text import (CharTokenizer, annotate_languages, build_tokenizer,
                          normalize_text, plan_chunks, split_sentences,
                          Chunk, Silence, verbalize_number)

L = ["rw", "en", "fr", "sw"]


def test_languages_registered():
    assert available_languages() == ["en", "fr", "rw", "sw"]
    assert canonical_code("en-US") == "en" and canonical_code("Kinyarwanda") == "rw"
    assert canonical_code(None, "rw") == "rw" and canonical_code("xx", "rw") == "rw"


@pytest.mark.parametrize("lang,n,words", [
    ("rw", 125, "ijana na makumyabiri na gatanu"),
    ("rw", 2500, "ibihumbi bibiri na magana atanu"),
    ("en", 1234567, "one million two hundred and thirty four thousand five hundred and sixty seven"),
    ("fr", 71, "soixante et onze"), ("fr", 80, "quatre-vingts"), ("fr", 81, "quatre-vingt-un"),
    ("fr", 200, "deux cents"), ("fr", 201, "deux cent un"), ("fr", 1999, "mille neuf cent quatre-vingt-dix-neuf"),
    ("sw", 105, "mia moja na tano"), ("sw", 2500, "elfu mbili mia tano"),
    ("sw", 250000, "laki mbili elfu hamsini"),
])
def test_number_words(lang, n, words):
    assert get_language(lang).verbalize_number(n) == words
    assert verbalize_number(n, lang) == words


def test_expand_numbers_currency_percent_ids():
    assert expand_numbers("FRW 2500", "rw").startswith("amafaranga ibihumbi bibiri")
    assert "two thousand five hundred Rwandan francs" in expand_numbers("FRW 2,500", "en")
    assert "virgule" in expand_numbers("3,5%", "fr") and "pour cent" in expand_numbers("3,5%", "fr")
    # long digit strings / leading zero -> digit by digit
    out = expand_numbers("0788123456", "rw")
    assert out.startswith("zeru karindwi umunani umunani")
    # trailing comma never swallowed
    assert expand_numbers("Una FRW 2500, sawa", "sw") == "Una elfu mbili mia tano faranga za Rwanda, sawa"


def test_word_language_detection_runs():
    prev = None
    out = []
    for w in "ejo naje kureba ariko she disappointed me bonjour merci habari asante".split():
        prev = detect_word_language(w, L, "rw", prev)
        out.append(prev)
    assert out[:4] == ["rw"] * 4
    assert out[4:7] == ["en"] * 3
    assert out[7:9] == ["fr"] * 2
    assert out[9:] == ["sw"] * 2


def test_tag_grammar():
    t = 'A [pause] b. <break time="500ms"/> [happy:0.8] c <en>hi there</en> [laugh] d [emotion:calm] <sil> e [pause:1.5s] [sic] f [um]'
    segs = parse_tags(t, L).segments
    kinds = [type(s).__name__ for s in segs]
    assert kinds.count("PauseTag") == 4 and kinds.count("NonverbalTag") == 2
    assert kinds.count("EmotionTag") == 2
    assert any(isinstance(s, TextSpan) and s.language == "en" for s in segs)
    assert "[sic]" in strip_tags(t, L)            # unknown bracket text kept
    assert canonicalize(t, L) == ("A [pause] b. [pause:0.5] [happy:0.8] c <en>hi there</en> "
                                  "[laugh] d [calm] [pause] e [pause:1.5] [sic] f [hesitation]")
    assert parse_duration("500ms") == 0.5 and parse_duration("700") == 0.7
    assert parse_duration("1,5s") == 1.5 and parse_duration("abc") is None


def test_insert_pauses_from_list():
    assert insert_pauses("muraho neza amakuru yawe", [{"offset": 7, "duration": 0.4}, {"word": 2}]) \
        == "muraho [pause:0.4] neza amakuru [pause] yawe"
    assert insert_pauses("a b c", [[2, 0.3]]) == "a [pause:0.3] b c"


def test_normalize_v1_signature_unchanged():
    out = normalize_text("Ufite FRW 2,500 kuri konti 0788123456. Meeting ni ejo!", True,
                         ".,?!;:'-", True, transliterate_foreign=True)
    assert out.startswith("ufite amafaranga ibihumbi bibiri na magana atanu kuri konti zeru")
    assert out.endswith("mitingi ni ejo!")       # English transliterated on a rw-only model
    assert normalize_text("a/b c") == "a b c"     # dropped symbols never glue words


def test_normalize_multilingual_keeps_trained_languages():
    t = "Vous avez 2500 FRW. Habari, una FRW 2500. she disappointed me. Nkunda 25% by'ibyo."
    n = normalize_text(t, transliterate_foreign=True, languages=L)
    assert "deux mille cinq cents francs rwandais" in n
    assert "elfu mbili mia tano faranga za rwanda" in n
    assert "she disappointed me" in n             # NOT transliterated: English is trained
    assert "makumyabiri na gatanu ku ijana" in n
    langs = {}
    cur, lid = "", 0
    for sym, l in annotate_languages(n, L):
        if sym == " ":
            if cur:
                langs[cur] = L[lid]
            cur = ""
        else:
            cur += sym
            lid = l
    assert langs["vous"] == "fr" and langs["habari,"] == "sw" and langs["disappointed"] == "en"
    assert langs["nkunda"] == "rw"


def test_tags_survive_normalization_and_splitting():
    n = normalize_text("Muraho [pause] neza. [happy:0.8] Twishimiye <en>your call</en> [laugh] "
                       "murakoze! [pause:1.5]", languages=L)
    assert n == "muraho [pause] neza. [happy:0.8] twishimiye <en>your call</en> [laugh] murakoze! [pause:1.5]"
    assert split_sentences(n, L) == ["muraho [pause] neza.",
                                     "[happy:0.8] twishimiye <en>your call</en> [laugh] murakoze!",
                                     "[pause:1.5]"]
    plan = plan_chunks(n, languages=L, pause_token_known=True, nonverbals_known=["laugh"])
    assert isinstance(plan[-1], Silence) and plan[-1].seconds == 1.5
    assert plan[1].emotion == "happy" and plan[1].intensity == 0.8
    assert "[pause]" in plan[0].text and "[laugh]" in plan[1].text
    # model without the pause token: [pause] becomes an exact default silence
    plan2 = plan_chunks(n, languages=L, pause_token_known=False, default_pause_s=0.35)
    assert any(isinstance(p, Silence) and abs(p.seconds - 0.35) < 1e-9 for p in plan2)
    assert not any("[laugh]" in p.text for p in plan2 if isinstance(p, Chunk))


def test_tokenizer_v2_roundtrip_and_v1_load(tmp_path):
    texts = ["muraho [pause] neza.", "<en>hello</en> [laugh] bonjour"]
    tok = build_tokenizer(texts, languages=L)
    assert tok.pause_id is not None and "laugh" in tok.known_nonverbals()
    ids, lids = tok.encode_full(texts[1])
    assert len(ids) == len(lids) and ids[0] == 0 and ids[1::2].count(0) == 0
    assert tok.decode(ids) == "hello [laugh] bonjour"
    tok.save(str(tmp_path / "tok.json"))
    tok2 = CharTokenizer.load(str(tmp_path / "tok.json"))
    assert tok2.symbols == tok.symbols and tok2.languages == L
    # v1 file: characters only, no version
    (tmp_path / "v1.json").write_text(json.dumps({"type": "char", "symbols": ["_", " ", "a", "m", "u", "h", "o", "r"]}))
    old = CharTokenizer.load(str(tmp_path / "v1.json"))
    assert old.specials == [] and old.languages == ["rw"] and old.pause_id is None
    assert old.encode("muraho [pause]", True)[1::2] == [old.sym2id[c] for c in "muraho"]
    assert set(SPECIAL_TOKENS) <= set(tok.symbols)
