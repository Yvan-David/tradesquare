"""``altatts-export`` -- export a trained voice to ONNX.

    altatts-export --model runs/kinyarwanda --out kinyarwanda.onnx [--steps 4]

The exported graph maps (text ids, lengths, style vector, language ids,
scales) -> waveform, for CPU deployment with onnxruntime where PyTorch is
too heavy (e.g. inside telephony media servers). Requires
``pip install altatts[onnx]``.

Notes
-----
* MAS is training-only; the export wraps the deterministic ``infer`` path.
* v2 models: the MeanFlow sampler is unrolled for a FIXED number of steps
  (``--steps``), and the style vector is an INPUT (``g``), so default and
  enrolled voices from voices.json work unchanged (look the vector up in
  Python, pass it in). Emotion is folded into ``g`` beforehand.
* v1 models: ``sid`` (speaker id) is the input, exactly as in ALTATTS 0.1.
* Dynamic axes cover text length and output samples.
"""

from __future__ import annotations

import argparse
import os
from typing import List, Optional

from .utils import quiet_warnings, clear_terminal


def export_onnx(model_dir: str, out_path: str, opset: int = 17,
                device: str = "cpu", verbose: bool = True,
                steps: int = 4) -> str:
    import numpy as np
    import torch

    from .inference.checkpoint import load_checkpoint_bundle

    b = load_checkpoint_bundle(model_dir, "cpu")
    model, cfg, tokenizer = b.model.to("cpu").eval(), b.cfg, b.tokenizer
    legacy = cfg.is_legacy

    if legacy:
        class InferWrapper(torch.nn.Module):
            def __init__(self, net):
                super().__init__()
                self.net = net

            def forward(self, x, x_lengths, sid, noise_scale, length_scale):
                o, _, _ = self.net.infer(
                    x, x_lengths, sid=sid,
                    noise_scale=float(noise_scale),
                    length_scale=float(length_scale))
                return o
        input_names = ["x", "x_lengths", "sid", "noise_scale", "length_scale"]
    else:
        class InferWrapper(torch.nn.Module):          # type: ignore[no-redef]
            def __init__(self, net, steps):
                super().__init__()
                self.net = net
                self.steps = steps

            def forward(self, x, x_lengths, g, lang, noise_scale, length_scale):
                o, _, _ = self.net.infer(
                    x, x_lengths, g=g, lang=lang,
                    noise_scale=float(noise_scale),
                    length_scale=float(length_scale), steps=self.steps)
                return o
        input_names = ["x", "x_lengths", "g", "lang", "noise_scale", "length_scale"]

    ids, lids = tokenizer.encode_full("muraho neza", cfg.text.intersperse_blank)
    x = torch.LongTensor(ids).unsqueeze(0)
    x_lengths = torch.LongTensor([x.size(1)])
    noise = torch.tensor(0.667)
    length = torch.tensor(1.0)
    if legacy:
        wrapper = InferWrapper(model)
        inputs = (x, x_lengths, torch.LongTensor([0]), noise, length)
        dyn = {"x": {0: "batch", 1: "text"}, "x_lengths": {0: "batch"},
               "sid": {0: "batch"}, "wav": {0: "batch", 2: "samples"}}
    else:
        wrapper = InferWrapper(model, steps)
        g = model.emb_g.weight[:1].detach().clone()
        lang = torch.LongTensor(lids).unsqueeze(0)
        inputs = (x, x_lengths, g, lang, noise, length)
        dyn = {"x": {0: "batch", 1: "text"}, "x_lengths": {0: "batch"},
               "g": {0: "batch"}, "lang": {0: "batch", 1: "text"},
               "wav": {0: "batch", 2: "samples"}}

    os.makedirs(os.path.dirname(os.path.abspath(out_path)) or ".", exist_ok=True)
    kwargs = dict(opset_version=opset, input_names=input_names,
                  output_names=["wav"], dynamic_axes=dyn)
    import contextlib
    import io
    errors = []
    exported = False
    @contextlib.contextmanager
    def _quiet_fds():
        """The TorchScript exporter dumps the whole graph to fd 2 from C++ on
        failure; silence file descriptors 1/2 while trying."""
        import sys
        sys.stdout.flush(); sys.stderr.flush()
        saved = [os.dup(1), os.dup(2)]
        devnull = os.open(os.devnull, os.O_WRONLY)
        try:
            os.dup2(devnull, 1); os.dup2(devnull, 2)
            yield
        finally:
            os.dup2(saved[0], 1); os.dup2(saved[1], 2)
            for fd in saved + [devnull]:
                os.close(fd)

    for fn_name in ("disable_log",):            # C++ ONNX logger dumps graphs
        fn = getattr(torch.onnx, fn_name, None)
        if callable(fn):
            try:
                fn()
            except Exception:                   # noqa: BLE001
                pass
    try:
        torch._C._jit_set_onnx_log_enabled(False)
    except Exception:                           # noqa: BLE001
        pass
    for attempt in ("torchscript", "dynamo"):
        buf = io.StringIO()
        try:
            with _quiet_fds(), contextlib.redirect_stderr(buf), contextlib.redirect_stdout(buf):
                if attempt == "torchscript":
                    try:
                        torch.onnx.export(wrapper, inputs, out_path, dynamo=False, **kwargs)
                    except TypeError:               # older torch: no dynamo kw
                        torch.onnx.export(wrapper, inputs, out_path, **kwargs)
                else:
                    torch.onnx.export(wrapper, inputs, out_path, dynamo=True,
                                      input_names=input_names, output_names=["wav"])
            exported = True
            break
        except Exception as exc:                    # noqa: BLE001
            first = next((l for l in str(exc).splitlines() if l.strip()), str(exc))
            errors.append(f"{attempt}: {first[:160]}")
    if not exported:
        raise RuntimeError(
            "ONNX export failed with both exporters:\n  - " + "\n  - ".join(errors)
            + f"\n  torch {torch.__version__}: the TorchScript ONNX exporter is "
              "deprecated in torch >= 2.9 and rejects this graph; the dynamo "
              "exporter cannot yet trace the data-dependent output length of a "
              "duration-based TTS model. Export with torch <= 2.8 "
              "(pip install 'torch<2.9' in a separate env), or serve with "
              "PyTorch (Synthesizer; 1-step MeanFlow is fast on CPU).")
    if verbose:
        print(f"[export] wrote {out_path} "
              f"({'v1 sid input' if legacy else f'v2 style-vector input, {steps} MeanFlow steps'})")

    try:
        import onnxruntime as ort
        sess = ort.InferenceSession(out_path, providers=["CPUExecutionProvider"])
        with torch.inference_mode():
            torch.manual_seed(0)
            ref = wrapper(*inputs).numpy()
        feed = {n: t.numpy() for n, t in zip(input_names, inputs)}
        out = sess.run(None, feed)[0]
        if verbose:
            print(f"[export] parity: torch {ref.shape} vs onnx {out.shape} "
                  "(shapes only -- sampling noise differs by design)")
    except ImportError:
        if verbose:
            print("[export] onnxruntime not installed; skipped runtime check "
                  "(pip install altatts[onnx])")
    return out_path


def main(argv: Optional[List[str]] = None) -> None:
    quiet_warnings()
    clear_terminal()
    p = argparse.ArgumentParser(prog="altatts-export",
                                description="Export an ALTATTS voice to ONNX")
    p.add_argument("--model", required=True, help="Checkpoint folder")
    p.add_argument("--out", required=True, help="Output .onnx path")
    p.add_argument("--opset", type=int, default=17)
    p.add_argument("--steps", type=int, default=4,
                   help="MeanFlow steps unrolled into the graph (v2)")
    args = p.parse_args(argv)
    export_onnx(args.model, args.out, args.opset, steps=args.steps)


if __name__ == "__main__":
    main()
