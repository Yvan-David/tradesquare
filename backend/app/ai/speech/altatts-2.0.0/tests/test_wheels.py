"""The torch-wheel cross-check behind `doctor --fix`, fully offline."""
import pytest

from altatts.env.wheels import (candidate_tags, cuda_of_tag, min_cuda_for_caps,
                                parse_index, resolve_wheel)

TABLE = {"source": "x", "last_verified": "2026-08-20",
         "min_driver_linux": {"11": "450.80.02", "12": "525.60.13", "13": "580.65.06"},
         "torch_wheel_tags": ["cu118", "cu121", "cu124", "cu126", "cu128", "cu129", "cu130"],
         "min_cuda_for_compute_cap": {"8": "11.1", "8.9": "11.8", "9": "11.8", "10": "12.8", "12": "12.8"}}


def _page(names):
    rows = [f'<a href="https://dl.example/whl/{n.replace("+", "%2B")}#sha256=abc" '
            f'data-core-metadata="sha256=def">{n.replace("+", "%2B")}</a><br/>' for n in names]
    return "<html><body><h1>Links</h1>" + "\n".join(rows) + "</body></html>"


def _wheels(pkg, versions, tag, py="cp312", arch="x86_64", plat="manylinux_2_28"):
    local = f"+{tag}" if tag else ""
    return [f"{pkg}-{v}{local}-{py}-{py}-{plat}_{arch}.whl" for v in versions]


PAGES = {
    "cu130/torch": _wheels("torch", ["2.14.1", "2.11.0", "2.15.0.dev20260901"], "cu130")
                   + _wheels("torch", ["2.14.1"], "cu130", py="cp311")
                   + ["torch-2.14.1+cu130-cp312-cp312-win_amd64.whl"],
    "cu130/torchaudio": _wheels("torchaudio", ["2.11.0"], "cu130"),
    "cu128/torch": _wheels("torch", ["2.11.0"], "cu128"),
    "cu128/torchaudio": _wheels("torchaudio", ["2.11.0"], "cu128"),
    "cu126/torch": _wheels("torch", ["2.14.1", "2.11.0"], "cu126") + _wheels("torch", ["2.14.1"], "cu126", arch="aarch64"),
    "cu126/torchaudio": _wheels("torchaudio", ["2.11.0"], "cu126"),
    "cu124/torch": _wheels("torch", ["2.6.0"], "cu124", plat="linux") + ["torch-2.5.1-cp312-cp312-linux_aarch64.whl"],
    "cu124/torchaudio": _wheels("torchaudio", ["2.6.0"], "cu124", plat="linux"),
    "cu121/torch": _wheels("torch", ["2.6.0", "2.5.1"], "cu121"),
    "cu121/torchaudio": _wheels("torchaudio", ["2.5.1"], "cu121"),
    "cpu/torch": _wheels("torch", ["2.14.1"], "cpu"),
    "cpu/torchaudio": _wheels("torchaudio", ["2.11.0"], "cpu"),
}
METADATA = {"torchaudio-2.5.1+cu121-cp312-cp312-manylinux_2_28_x86_64.whl":
            "Metadata-Version: 2.1\nName: torchaudio\nVersion: 2.5.1+cu121\nRequires-Dist: torch==2.5.1\n"}


class FakeFetch:
    def __init__(self):
        self.urls = []

    def __call__(self, url):
        self.urls.append(url)
        if url.endswith(".metadata"):
            name = url.rsplit("/", 1)[-1][:-len(".metadata")].replace("%2B", "+")
            if name in METADATA:
                return METADATA[name]
            return "Metadata-Version: 2.1\nName: torchaudio\n"
        key = "/".join(url.rstrip("/").split("/")[-2:])
        if key not in PAGES:
            raise OSError(f"HTTP 404 {url}")
        return _page(PAGES[key])


def test_parse_index_filters_python_arch_local_and_prereleases():
    page = _page(PAGES["cu130/torch"])
    got = parse_index(page, "torch", "cp312", "x86_64", "cu130")
    assert list(got) == ["2.14.1", "2.11.0"]
    assert got["2.14.1"].startswith("https://dl.example/whl/torch-2.14.1%2Bcu130")
    assert parse_index(page, "torch", "cp312", "aarch64", "cu130") == {}
    assert parse_index(page, "torch", "cp310", "x86_64", "cu130") == {}
    assert parse_index(_page(PAGES["cu124/torch"]), "torch", "cp312", "aarch64", "cu124") == {}
    assert list(parse_index(_page(PAGES["cu124/torch"]), "torch", "cp312", "x86_64", "cu124")) == ["2.6.0"]
    assert cuda_of_tag("cu118") == (11, 8) and cuda_of_tag("cu130") == (13, 0) and cuda_of_tag("cpu") is None


def test_candidate_tags_respect_driver_ceiling_and_gpu_floor():
    assert min_cuda_for_caps(["9.0"], TABLE) == "11.8"
    assert min_cuda_for_caps(["8.6", "12.1"], TABLE) == "12.8"
    assert min_cuda_for_caps(["7.5"], TABLE) is None
    tags, skipped = candidate_tags("12.8", "11.8", TABLE)
    assert tags == ["cu128", "cu126", "cu124", "cu121"]
    assert dict(skipped)["cu130"].startswith("needs a driver for CUDA 13.0")
    assert "not probed" in dict(skipped)["cu118"]
    tags, skipped = candidate_tags("12.8", "12.8", TABLE)
    assert tags == ["cu128"] and "floor" in dict(skipped)["cu126"]
    assert candidate_tags(None, None, TABLE)[0] == ["cpu"]
    assert candidate_tags("13.2", None, TABLE)[0][0] == "cu132"      # newer than the table


def test_resolve_picks_newest_torch_within_the_driver_ceiling():
    f = FakeFetch()
    c = resolve_wheel("12.8", ["9.0"], TABLE, python_version=(3, 12), machine="x86_64", fetch=f)
    assert c.ok and c.tag == "cu126" and c.torch_version == "2.14.1" and c.torchaudio_version == "2.11.0"
    assert c.pins() == ["torch==2.14.1+cu126", "torchaudio==2.11.0+cu126"]
    assert c.pins(with_torchvision=True)[-1] == "torchvision"
    text = c.describe()
    assert "cu130   skipped" in text and "<- chosen" in text and "cu126" in text
    assert not any("cu130/torch" in u for u in f.urls)                 # never probed


def test_resolve_honours_capability_floor_and_architecture():
    c = resolve_wheel("13.0", ["12.1"], TABLE, python_version=(3, 12), machine="x86_64", fetch=FakeFetch())
    assert c.tag == "cu130" and c.torch_version == "2.14.1"
    assert any(t == "cu126" and "floor" in why for t, why in c.skipped)
    assert any(cand.tag == "cu129" and "unreachable" in cand.reason for cand in c.candidates)
    c = resolve_wheel("12.8", ["9.0"], TABLE, python_version=(3, 12), machine="aarch64", fetch=FakeFetch())
    assert c.tag == "cu126"                                             # only cu126 ships aarch64 here
    assert any(cand.tag == "cu128" and "no torch wheel" in cand.reason for cand in c.candidates)


def test_resolve_cpu_pin_override_and_offline():
    c = resolve_wheel(None, [], TABLE, python_version=(3, 12), machine="x86_64", fetch=FakeFetch())
    assert c.tag == "cpu" and c.pins()[0] == "torch==2.14.1+cpu"
    c = resolve_wheel("12.1", ["8.0"], TABLE, python_version=(3, 12), machine="x86_64", fetch=FakeFetch())
    assert c.tag == "cu121" and c.torch_version == "2.5.1" and "held" in c.candidates[0].note
    c = resolve_wheel("13.0", ["12.1"], TABLE, python_version=(3, 12), machine="x86_64",
                      fetch=FakeFetch(), override="cu128")
    assert c.tag == "cu128" and [x.tag for x in c.candidates] == ["cu128"]
    c = resolve_wheel("13.0", ["12.1"], TABLE, python_version=(3, 12), machine="x86_64",
                      fetch=FakeFetch(), override="https://mirror.example/whl/cu126")
    assert c.tag == "cu126" and c.index_url == "https://mirror.example/whl/cu126"

    def offline(url):
        raise OSError("name resolution failed")
    c = resolve_wheel("12.8", ["9.0"], TABLE, python_version=(3, 12), machine="x86_64", fetch=offline)
    assert not c.ok and "unreachable" in c.describe() and c.pins() == ["torch", "torchaudio"]


@pytest.mark.parametrize("py", [(3, 9), (3, 13)])
def test_resolve_reports_missing_python_wheels(py):
    c = resolve_wheel("12.8", ["9.0"], TABLE, python_version=py, machine="x86_64", fetch=FakeFetch())
    assert not c.ok and all("no torch wheel" in x.reason for x in c.candidates)
