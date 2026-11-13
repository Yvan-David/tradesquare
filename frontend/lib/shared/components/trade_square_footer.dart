import 'package:flutter/material.dart';

import '../../app/localization/generated/app_localizations.dart';
import '../../app/theme/app_colors.dart';

class TradeSquareFooter extends StatelessWidget {
  const TradeSquareFooter({
    this.version,
    this.maxContentWidth = 1200,
    super.key,
  });

  final String? version;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.brightness == Brightness.dark
          ? theme.colorScheme.onSurfaceVariant
          : AppColors.secondaryText,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.outlineVariant
                : AppColors.border,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: version == null
                  ? const SizedBox.shrink()
                  : Text(
                      localizations.footerVersion(version!),
                      style: textStyle,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
