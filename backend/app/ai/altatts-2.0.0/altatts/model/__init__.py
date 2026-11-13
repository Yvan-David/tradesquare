"""
``altatts.model`` -- the network, one file per concern:

``modules.py``          shared blocks: masks, slicing, WN, HiFi-GAN resblock
``text_encoder.py``     character transformer (relative attention, language ids)
``latent.py``           posterior encoder, normalizing flow, duration predictor
``style.py``            reference (speaker) encoder + style composition
``meanflow.py``         MeanFlow latent prior (training loss + sampler)
``waveform.py``         HiFi-GAN generator + multi-period discriminators
``monotonic_align.py``  MAS (self-learned alignment)
``losses.py``           adversarial / feature-matching / KL losses
``vits.py``             SynthesizerTrn assembly (train forward + infer)
"""
from .losses import (discriminator_loss, feature_matching_loss,  # noqa: F401
                     generator_adv_loss, kl_loss)
from .meanflow import LatentPrior, meanflow_loss, sample_latent  # noqa: F401
from .style import ReferenceEncoder                              # noqa: F401
from .vits import SynthesizerTrn, build_model                    # noqa: F401
from .waveform import Generator, MultiPeriodDiscriminator        # noqa: F401
