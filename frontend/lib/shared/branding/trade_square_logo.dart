import 'package:flutter/material.dart';

import 'trade_square_assets.dart';

/// Renders the official TradeSquare mark from [TradeSquareAssets.logo].
class TradeSquareLogo extends StatelessWidget {
  const TradeSquareLogo({
    this.size = 36,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
    super.key,
  });

  final double size;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        TradeSquareAssets.logo,
        width: size,
        height: size,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return SizedBox(
            width: size,
            height: size,
            child: const ColoredBox(
              color: Color(0xFFE8EEF7),
              child: Icon(Icons.storefront_outlined, size: 20),
            ),
          );
        },
      ),
    );
  }
}
