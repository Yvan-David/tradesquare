"""
Training losses.

Generator total (ALTATTS 2):
    L_G = L_adv(G) + c_fm * L_fm + c_mel * L1(mel) + c_dur * L_dur + c_kl * L_kl
          + c_mf * L_meanflow + c_spk * L_spk

* LSGAN adversarial losses (least-squares -- stabler than BCE for audio GANs);
* feature matching: L1 between discriminator feature maps of real and fake;
* KL between the posterior q(z|y,s) and the aligned, flow-mapped prior
  p(z_p|text,s), masked and normalised by the number of valid latent elements;
* MeanFlow regression (see ``meanflow.py``) -- the joint latent prior;
* speaker-embedding regression (see ``vits.py``) -- the cloning encoder.
"""
from __future__ import annotations

from typing import List, Tuple

import torch


def discriminator_loss(disc_real: List[torch.Tensor],
                       disc_fake: List[torch.Tensor]
                       ) -> Tuple[torch.Tensor, List[float], List[float]]:
    loss = 0.0
    r_losses, g_losses = [], []
    for dr, dg in zip(disc_real, disc_fake):
        dr, dg = dr.float(), dg.float()
        r_l = torch.mean((1.0 - dr) ** 2)
        g_l = torch.mean(dg ** 2)
        loss = loss + r_l + g_l
        r_losses.append(float(r_l.detach()))
        g_losses.append(float(g_l.detach()))
    return loss, r_losses, g_losses


def generator_adv_loss(disc_fake: List[torch.Tensor]) -> torch.Tensor:
    loss = 0.0
    for dg in disc_fake:
        loss = loss + torch.mean((1.0 - dg.float()) ** 2)
    return loss


def feature_matching_loss(fmap_real: List[List[torch.Tensor]],
                          fmap_fake: List[List[torch.Tensor]]) -> torch.Tensor:
    loss = 0.0
    for fr, fg in zip(fmap_real, fmap_fake):
        for r, g in zip(fr, fg):
            loss = loss + torch.mean(torch.abs(r.detach().float() - g.float()))
    return loss


def kl_loss(z_p: torch.Tensor, logs_q: torch.Tensor, m_p: torch.Tensor,
            logs_p: torch.Tensor, z_mask: torch.Tensor) -> torch.Tensor:
    """KL( q(z) || p(z_p) ) evaluated on the flow-mapped posterior sample."""
    z_p = z_p.float()
    logs_q = logs_q.float()
    m_p = m_p.float()
    logs_p = logs_p.float()
    z_mask = z_mask.float()
    kl = logs_p - logs_q - 0.5
    kl = kl + 0.5 * ((z_p - m_p) ** 2) * torch.exp(-2.0 * logs_p)
    kl = torch.sum(kl * z_mask)
    return kl / torch.sum(z_mask)
