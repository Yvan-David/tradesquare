import 'package:flutter/material.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/trade_square_home_feed.dart';

class TradeSquareHomeWelcomeSection extends StatelessWidget {
  const TradeSquareHomeWelcomeSection({
    required this.profile,
    this.interests = const [],
    this.onManageInterests,
    super.key,
  });

  final TradeSquareHomeProfile profile;
  final List<String> interests;
  final VoidCallback? onManageInterests;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final name = profile.displayName?.trim();
    final greeting = name != null && name.isNotEmpty
        ? localizations.homeGreeting(name)
        : localizations.homeDiscoverTitle;
    final subtitle = profile.industry != null && profile.industry!.isNotEmpty
        ? localizations.homePersonalizedFor(profile.industry!)
        : switch (profile.intent) {
            TradeSquareBusinessIntent.buy => localizations.homeFeedIntroBuyer,
            TradeSquareBusinessIntent.sell =>
              localizations.homeFeedIntroSupplier,
            TradeSquareBusinessIntent.both => localizations.homeFeedIntro,
          };
    final businessLabel =
        profile.businessName?.trim().isNotEmpty == true
            ? profile.businessName!
            : profile.location ?? 'TradeSquare';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepBlue, AppColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  _initials(name ?? businessLabel),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      greeting,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        height: 1.2,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.88),
              fontSize: 14.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (interests.isNotEmpty || onManageInterests != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    localizations.homeInterests,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (onManageInterests != null)
                  TextButton(
                    onPressed: onManageInterests,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(localizations.homeManageInterests),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (interests.isEmpty)
              Text(
                localizations.homeInterestsEmpty,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final interest in interests.take(6))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        interest,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts =
        value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return 'TS';
    if (list.length == 1) {
      final text = list.first;
      return text.substring(0, text.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
  }
}
