import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

bool get discoverIsFlutterTestBinding => WidgetsBinding.instance.runtimeType
    .toString()
    .contains('TestWidgetsFlutterBinding');

class DiscoverNetworkImage extends StatelessWidget {
  const DiscoverNetworkImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
    super.key,
  });

  final String url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final fallback = ColoredBox(
      color: AppColors.deepBlue.withValues(alpha: 0.12),
      child: Center(
        child: Icon(fallbackIcon, color: AppColors.primary.withValues(alpha: 0.7)),
      ),
    );

    if (discoverIsFlutterTestBinding || !url.startsWith('http')) {
      return ClipRRect(borderRadius: radius, child: fallback);
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: AppColors.background,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
