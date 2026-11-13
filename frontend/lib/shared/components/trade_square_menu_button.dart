import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// X-inspired hamburger ↔ close morph used by the TradeSquare top bar.
class TradeSquareMenuButton extends StatefulWidget {
  const TradeSquareMenuButton({
    required this.isOpen,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    super.key,
  });

  final bool isOpen;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  State<TradeSquareMenuButton> createState() => _TradeSquareMenuButtonState();
}

class _TradeSquareMenuButtonState extends State<TradeSquareMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.isOpen ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant TradeSquareMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen == widget.isOpen) return;
    if (widget.isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
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
    final button = Semantics(
      button: true,
      label: widget.tooltip ?? (widget.isOpen ? 'Close menu' : 'Open menu'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = reduceMotion
                      ? (widget.isOpen ? 1.0 : 0.0)
                      : Curves.easeInOutCubic.transform(_controller.value);
                  return CustomPaint(
                    size: const Size(20, 14),
                    painter: _MenuIconPainter(
                      progress: t,
                      color: AppColors.text,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

class _MenuIconPainter extends CustomPainter {
  const _MenuIconPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final t = progress;

    // Top line rotates toward the first X stroke.
    final topY = lerpDouble(0, h / 2, t)!;
    canvas.save();
    canvas.translate(w / 2, topY);
    canvas.rotate(t * 0.785398163);
    canvas.drawLine(Offset(-w / 2, 0), Offset(w / 2, 0), paint);
    canvas.restore();

    // Middle line fades out.
    final midPaint = Paint()
      ..color = color.withValues(alpha: 1 - t)
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round;
    if (t < 0.999) {
      canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), midPaint);
    }

    // Bottom line rotates toward the second X stroke.
    final bottomY = lerpDouble(h, h / 2, t)!;
    canvas.save();
    canvas.translate(w / 2, bottomY);
    canvas.rotate(-t * 0.785398163);
    canvas.drawLine(Offset(-w / 2, 0), Offset(w / 2, 0), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MenuIconPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
