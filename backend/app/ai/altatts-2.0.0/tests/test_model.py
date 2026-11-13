"""Model layer (needs torch): MAS, v2 forward/backward, MeanFlow modes,
inference paths, state-dict compatibility, voice bank, launcher parsing."""
import json

import numpy as np
import pytest

torch = pytest.importorskip("torch")

from altatts.config import preset                                  # noqa: E402
from altatts.model import build_model                              # noqa: E402
from altatts.model.meanflow import LatentPrior, meanflow_loss, sample_latent  # noqa: E402
from altatts.model.monotonic_align import _mas_numpy, maximum_path  # noqa: E402
from altatts.audio import spectrogram_torch, spec_to_mel_torch     # noqa: E402
from altatts.inference.voices import VoiceBank                     # noqa: E402
from altatts.training.launch import parse_gpus, strip_launch_flags  # noqa: E402


def tiny_cfg(version=2):
    cfg = preset("small")
    cfg.model.hidden_channels = 32
    cfg.model.filter_channels = 64
    cfg.model.n_layers = 1
    cfg.model.n_heads = 2
    cfg.model.posterior_layers = 2
    cfg.model.flow_layers = 1
    cfg.model.upsample_initial_channel = 64
    cfg.model.n_speakers = 3
    cfg.prior.hidden = 32
    cfg.prior.n_layers = 1
    cfg.prior.n_heads = 2
    cfg.text.languages = ["rw", "en"]
    cfg.train.segment_size = 8
    if version == 1:
        cfg.model.version = 1
        cfg.prior.type = "flow"
        cfg.style.speaker_encoder = "none"
        cfg.style.emotion_conditioning = False
    cfg.validate()
    return cfg


def _batch(cfg, B=2):
    a = cfg.audio
    T, X = [60, 45], [12, 9]
    x = torch.zeros(B, max(X), dtype=torch.long)
    for i, n in enumerate(X):
        x[i, :n] = torch.randint(1, 20, (n,))
    wav = torch.randn(B, 1, max(T) * a.hop_length) * 0.1
    spec = spectrogram_torch(wav.squeeze(1), a.n_fft, a.hop_length, a.win_length)[:, :, :max(T)]
    ref = spec_to_mel_torch(spec[:, :, :40], a.sample_rate, a.n_fft, a.n_mels, a.mel_fmin, a.mel_fmax)
    return dict(x=x, x_lengths=torch.LongTensor(X), spec=spec, spec_lengths=torch.LongTensor(T),
                sid=torch.LongTensor([0, 2]), lang=torch.zeros_like(x), ref_mel=ref,
                ref_lengths=torch.LongTensor([40, 30]), emotion=torch.LongTensor([0, 3]),
                intensity=torch.tensor([1.0, 0.5]), use_ref=torch.tensor([True, False]),
                style_drop=torch.tensor([False, True]))


def test_mas_matches_reference_dp():
    rng = np.random.default_rng(0)

    def ref(ll):
        t_x, t_y = ll.shape
        q = np.full((t_x, t_y), -np.inf)
        back = np.zeros((t_x, t_y), dtype=np.int8)
        q[0, 0] = ll[0, 0]
        for t in range(1, t_y):
            for j in range(max(0, t_x - (t_y - t)), min(t_x - 1, t) + 1):
                stay = q[j, t - 1]
                diag = q[j - 1, t - 1] if j > 0 else -np.inf
                if diag > stay:
                    q[j, t], back[j, t] = ll[j, t] + diag, 1
                else:
                    q[j, t] = ll[j, t] + stay
        path, j = np.zeros((t_x, t_y), dtype=np.float32), t_x - 1
        for t in range(t_y - 1, -1, -1):
            path[j, t] = 1.0
            if back[j, t] == 1:
                j -= 1
        return path

    for tx, ty in [(5, 9), (37, 120), (1, 10), (3, 3)]:
        ll = rng.standard_normal((tx, ty))
        assert np.array_equal(_mas_numpy(ll), ref(ll))
    neg = torch.randn(2, 20, 6)
    mask = torch.ones(2, 20, 6)
    mask[1, 15:, :] = 0
    mask[1, :, 4:] = 0
    path = maximum_path(neg, mask)
    assert path.shape == neg.shape and path[1, 15:].sum() == 0 and path[1].sum() == 15


def test_v2_forward_backward_and_infer():
    torch.manual_seed(0)
    cfg = tiny_cfg()
    m = build_model(cfg, 24)
    out = m(**_batch(cfg))
    y_hat, l_len, attn, ids, xm, ym, latents, extras = out
    assert y_hat.shape[-1] == cfg.train.segment_size * cfg.audio.hop_length
    assert {"l_mf", "l_spk", "spk_cos"} <= set(extras)
    loss = l_len + extras["l_mf"] + extras["l_spk"] + y_hat.abs().mean() + sum(t.mean() for t in latents[:4])
    loss.backward()
    assert all(p.grad is not None for p in m.parameters()), "DDP needs every parameter used"
    m.eval()
    x = torch.randint(1, 20, (1, 10))
    xl = torch.LongTensor([10])
    with torch.inference_mode():
        for prior, steps in (("meanflow", 1), ("meanflow", 3), ("flow", None)):
            o, _, _ = m.infer(x, xl, sid=torch.LongTensor([1]), lang=torch.zeros_like(x),
                              emotion=torch.LongTensor([2]), intensity=torch.tensor([0.7]),
                              prior=prior, steps=steps)
            assert o.dim() == 3 and torch.isfinite(o).all()
        g = m.embed_reference(_batch(cfg)["ref_mel"][:1])
        assert g.shape == (1, cfg.model.gin_channels)
        o, _, _ = m.infer(x, xl, g=g, cfg_scale=1.3)
        assert torch.isfinite(o).all()
        gen = torch.Generator().manual_seed(3)
        o1, _, _ = m.infer(x, xl, sid=torch.LongTensor([0]), generator=gen)
        gen = torch.Generator().manual_seed(3)
        o2, _, _ = m.infer(x, xl, sid=torch.LongTensor([0]), generator=gen)
        assert torch.allclose(o1, o2)
    sd = m.inference_state_dict()
    assert not any(k.startswith("enc_q.") for k in sd)
    m2 = build_model(cfg, 24)
    missing, unexpected = m2.load_state_dict(sd, strict=False)
    assert all(k.startswith("enc_q.") for k in missing) and not unexpected


def test_v1_network_has_no_v2_modules():
    cfg = tiny_cfg(version=1)
    m = build_model(cfg, 24)
    assert not m.has_cloning and not m.has_emotions and not m.has_meanflow
    keys = set(m.state_dict())
    assert not any(k.startswith(("prior.", "ref_enc.", "emb_emo.")) for k in keys)
    assert "enc_p.emb_lang.weight" not in keys
    b = _batch(cfg)
    out = m(b["x"], b["x_lengths"], b["spec"], b["spec_lengths"], b["sid"])
    assert len(out) == 8 and out[7] == {}


def test_meanflow_jvp_and_fd_agree():
    torch.manual_seed(0)
    prior = LatentPrior(16, 32, 8, hidden=32, n_layers=1, n_heads=2)
    x = torch.randn(2, 16, 30)
    cond = torch.randn(2, 32, 30)
    mask = torch.ones(2, 1, 30)
    mask[1, :, 20:] = 0
    g = torch.randn(2, 8)
    torch.manual_seed(1)
    l1, st = meanflow_loss(prior, x, cond, mask, g, ratio=1.0, jvp_mode="jvp", adaptive_p=0)
    torch.manual_seed(1)
    l2, _ = meanflow_loss(prior, x, cond, mask, g, ratio=1.0, jvp_mode="fd", adaptive_p=0)
    assert st["mf_frac_interval"] == 1.0 and abs(float(l1) - float(l2)) < 1e-2
    l1.backward()
    z = sample_latent(prior, cond, mask, g, steps=1)
    assert z.shape == x.shape and (z[1, :, 20:] == 0).all()


def test_voice_bank(tmp_path):
    bank = VoiceBank()
    bank.add("female_adult", np.ones(4), kind="anonymized", gender="female")
    bank.add("agent", np.zeros(4), gender="male", source=["a.wav"])
    bank.set_alias("female", "female_adult")
    bank.save(str(tmp_path))
    back = VoiceBank.load(str(tmp_path))
    assert back.embedding("female").tolist() == [1.0] * 4
    assert "female" in back and back.resolve("agent")["gender"] == "male"
    pub = back.public()
    assert "embedding" not in pub["agent"] and pub["female"]["alias_of"] == "female_adult"
    assert back.remove("female_adult") and "female" not in back.aliases


def test_launcher_helpers():
    assert strip_launch_flags(["--gpus", "all", "--epochs", "3", "--nodes=2", "--x"]) == ["--epochs", "3", "--x"]
    ids, nproc, n = parse_gpus(None)
    assert nproc == 1
