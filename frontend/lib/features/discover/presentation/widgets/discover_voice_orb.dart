import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/trade_square_discover_assistant.dart';

class DiscoverVoiceOrb extends StatefulWidget {
  const DiscoverVoiceOrb({
    required this.state,
    this.size = 88,
    super.key,
  });

  final DiscoverVoiceUiState state;
  final double size;

  @override
  State<DiscoverVoiceOrb> createState() => _DiscoverVoiceOrbState();
}

class _DiscoverVoiceOrbState extends State<DiscoverVoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant DiscoverVoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _sync();
  }

  void _sync() {
    final animate = widget.state == DiscoverVoiceUiState.listening ||
        widget.state == DiscoverVoiceUiState.speaking ||
        widget.state == DiscoverVoiceUiState.thinking ||
        widget.state == DiscoverVoiceUiState.transcribing;
    if (animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = switch (widget.state) {
      DiscoverVoiceUiState.listening => AppColors.primary,
      DiscoverVoiceUiState.transcribing => AppColors.lightBlue,
      DiscoverVoiceUiState.thinking => AppColors.deepBlue,
      DiscoverVoiceUiState.speaking => AppColors.primary,
      DiscoverVoiceUiState.error => const Color(0xFFC53030),
      DiscoverVoiceUiState.interrupted => AppColors.secondaryText,
      DiscoverVoiceUiState.idle => AppColors.deepBlue,
    };

    return Semantics(
      label: 'Voice status ${widget.state.name}',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = reduceMotion ? 0.0 : _controller.value;
            return CustomPaint(
              painter: _OrbPainter(
                progress: t,
                color: color,
                state: widget.state,
              ),
              child: child,
            );
          },
          child: Center(
            child: Icon(
              switch (widget.state) {
                DiscoverVoiceUiState.listening => Icons.graphic_eq_rounded,
                DiscoverVoiceUiState.speaking => Icons.volume_up_rounded,
                DiscoverVoiceUiState.thinking => Icons.auto_awesome_rounded,
                DiscoverVoiceUiState.transcribing => Icons.hearing_rounded,
                DiscoverVoiceUiState.error => Icons.error_outline_rounded,
                _ => Icons.mic_none_rounded,
              },
              color: AppColors.white,
              size: widget.size * 0.34,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.progress,
    required this.color,
    required this.state,
  });

  final double progress;
  final Color color;
  final DiscoverVoiceUiState state;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.32;

    final glow = Paint()
      ..color = color.withValues(alpha: 0.18 + 0.1 * math.sin(progress * math.pi * 2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius * (1.45 + 0.08 * math.sin(progress * math.pi * 2)), glow);

    final fill = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          AppColors.deepBlue,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, fill);

    if (state == DiscoverVoiceUiState.listening ||
        state == DiscoverVoiceUiState.speaking) {
      final wave = Paint()
        ..color = AppColors.white.withValues(alpha: 0.85)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path();
      final bars = 7;
      final startX = center.dx - 18;
      for (var i = 0; i < bars; i++) {
        final x = startX + i * 6;
        final amp = 4 +
            10 *
                (0.35 +
                    0.65 *
                        (0.5 +
                            0.5 *
                                math.sin(progress * math.pi * 2 + i * 0.7)));
        path.moveTo(x, center.dy - amp);
        path.lineTo(x, center.dy + amp);
      }
      canvas.drawPath(path, wave);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.state != state;
  }
}
