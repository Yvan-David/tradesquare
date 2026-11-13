import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/call_models.dart';

class TradeSquareCallControlBar extends StatelessWidget {
  const TradeSquareCallControlBar({
    required this.session,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onToggleCamera,
    required this.onToggleCaptions,
    required this.onToggleTranslation,
    required this.onLanguage,
    required this.onEnd,
    super.key,
  });

  final TradeSquareCallSession session;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleCaptions;
  final VoidCallback onToggleTranslation;
  final VoidCallback onLanguage;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: [
          TradeSquareCallControlButton(
            icon: session.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: session.isMuted ? 'Unmute' : 'Mute',
            active: session.isMuted,
            onTap: onToggleMute,
          ),
          TradeSquareCallControlButton(
            icon: session.isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: 'Speaker',
            active: session.isSpeakerOn,
            onTap: onToggleSpeaker,
          ),
          TradeSquareCallControlButton(
            icon: session.isCameraOn
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: 'Camera',
            active: session.isCameraOn,
            enabled: session.isVideo,
            onTap: session.isVideo ? onToggleCamera : null,
          ),
          TradeSquareCallControlButton(
            icon: session.areCaptionsOn
                ? Icons.closed_caption_rounded
                : Icons.closed_caption_disabled_rounded,
            label: 'Captions',
            active: session.areCaptionsOn,
            onTap: onToggleCaptions,
          ),
          TradeSquareCallControlButton(
            icon: Icons.translate_rounded,
            label: 'Language',
            onTap: onLanguage,
          ),
          TradeSquareCallControlButton(
            icon: Icons.call_end_rounded,
            label: 'End',
            danger: true,
            onTap: onEnd,
          ),
        ],
      ),
    );
  }
}

class TradeSquareCallControlButton extends StatefulWidget {
  const TradeSquareCallControlButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.danger = false,
    this.enabled = true,
    this.showLabel = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool danger;
  final bool enabled;
  final bool showLabel;

  @override
  State<TradeSquareCallControlButton> createState() =>
      _TradeSquareCallControlButtonState();
}

class _TradeSquareCallControlButtonState
    extends State<TradeSquareCallControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    final background = widget.danger
        ? const Color(0xFFE11D48)
        : widget.active
            ? AppColors.white
            : AppColors.white.withValues(alpha: 0.14);
    final foreground = widget.danger
        ? AppColors.white
        : widget.active
            ? AppColors.deepBlue
            : AppColors.white;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _pressed ? 0.92 : 1,
            duration: const Duration(milliseconds: 110),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? widget.onTap : null,
                onHighlightChanged: (value) =>
                    setState(() => _pressed = value),
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: background,
                    boxShadow: widget.danger
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE11D48)
                                  .withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(widget.icon, color: foreground, size: 24),
                ),
              ),
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.9),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TradeSquareTranslationStatusChip extends StatelessWidget {
  const TradeSquareTranslationStatusChip({
    required this.session,
    super.key,
  });

  final TradeSquareCallSession session;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (session.translationState) {
      TradeSquareCallTranslationState.bypassed => (
          Icons.check_circle_outline_rounded,
          'Same language · translation off',
          AppColors.lightBlue,
        ),
      TradeSquareCallTranslationState.active => (
          Icons.translate_rounded,
          'Live translation · ${tradeSquareLanguageLabel(session.remoteLanguageCode)} → ${tradeSquareLanguageLabel(session.localLanguageCode)}'
              '${session.connectionLabel == null ? '' : ' · ${session.connectionLabel}'}',
          const Color(0xFF34D399),
        ),
      TradeSquareCallTranslationState.paused => (
          Icons.pause_circle_outline_rounded,
          'Translation paused',
          const Color(0xFFFBBF24),
        ),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.95),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TradeSquareCaptionPanel extends StatelessWidget {
  const TradeSquareCaptionPanel({
    required this.session,
    super.key,
  });

  final TradeSquareCallSession session;

  @override
  Widget build(BuildContext context) {
    if (!session.areCaptionsOn ||
        session.phase != TradeSquareCallPhase.active) {
      return const SizedBox.shrink();
    }

    final remoteLine = session.translationState ==
            TradeSquareCallTranslationState.bypassed
        ? 'We can finalize the delivery window this afternoon.'
        : 'Tunaweza kukamilisha dirisha la uwasilishaji alasiri.';
    final localLine = session.translationState ==
            TradeSquareCallTranslationState.bypassed
        ? null
        : 'We can finalize the delivery window this afternoon.';

    final original = session.captionOriginal?.trim();
    final translated = session.captionTranslated?.trim();
    if ((original == null || original.isEmpty) &&
        (translated == null || translated.isEmpty)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          session.translationState == TradeSquareCallTranslationState.bypassed
              ? 'Captions idle · same-language audio uses LiveKit directly.'
              : 'Captions appear when ALTA returns a real transcript/translation.',
          style: TextStyle(
            color: AppColors.white.withValues(alpha: 0.75),
            fontSize: 13.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (original != null && original.isNotEmpty)
            Text(
              original,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (translated != null && translated.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              translated,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.78),
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
