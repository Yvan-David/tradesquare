import 'package:flutter/material.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/trade_square_discover_models.dart';
import 'discover_icons.dart';

class DiscoverJourneyPanel extends StatelessWidget {
  const DiscoverJourneyPanel({
    required this.result,
    required this.onClear,
    required this.onRemoveMarket,
    required this.onClearIndustry,
    required this.onClearActivity,
    super.key,
  });

  final TradeSquareDiscoverSearchResult result;
  final VoidCallback onClear;
  final ValueChanged<String> onRemoveMarket;
  final VoidCallback onClearIndustry;
  final VoidCallback onClearActivity;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final criteria = result.criteria;
    final loading = result.stage == TradeSquareDiscoverSearchStage.understanding ||
        result.stage == TradeSquareDiscoverSearchStage.identifying ||
        result.stage == TradeSquareDiscoverSearchStage.searching ||
        result.stage == TradeSquareDiscoverSearchStage.ranking;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(DiscoverIcons.spark, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localizations.discoverJourneyTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: Text(localizations.discoverClearSearch),
              ),
            ],
          ),
          if (criteria.rawQuery.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '“${criteria.rawQuery}”',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (loading) _LoadingStages(stage: result.stage),
          if (criteria.hasInterpretedSignals) ...[
            const SizedBox(height: 8),
            Text(
              localizations.discoverInterpreted,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (criteria.activity != null)
                  _CriteriaChip(
                    label: criteria.activity!,
                    onDeleted: onClearActivity,
                  ),
                for (final product in criteria.products)
                  _CriteriaChip(label: product),
                if (criteria.originMarket != null)
                  _CriteriaChip(label: 'From ${criteria.originMarket}'),
                for (final market in criteria.targetMarkets)
                  _CriteriaChip(
                    label: market,
                    onDeleted: () => onRemoveMarket(market),
                  ),
                if (criteria.industry != null)
                  _CriteriaChip(
                    label: criteria.industry!,
                    onDeleted: onClearIndustry,
                  ),
              ],
            ),
          ],
          if (result.serviceNote != null) ...[
            const SizedBox(height: 12),
            Text(
              result.serviceNote!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingStages extends StatelessWidget {
  const _LoadingStages({required this.stage});

  final TradeSquareDiscoverSearchStage stage;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final stages = [
      (
        TradeSquareDiscoverSearchStage.understanding,
        localizations.discoverStageUnderstanding
      ),
      (
        TradeSquareDiscoverSearchStage.identifying,
        localizations.discoverStageIdentifying
      ),
      (
        TradeSquareDiscoverSearchStage.searching,
        localizations.discoverStageSearching
      ),
      (
        TradeSquareDiscoverSearchStage.ranking,
        localizations.discoverStageRanking
      ),
    ];

    final activeIndex = stages.indexWhere((item) => item.$1 == stage);

    return Column(
      children: [
        for (var i = 0; i < stages.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= activeIndex
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stages[i].$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          i == activeIndex ? FontWeight.w700 : FontWeight.w500,
                      color: i <= activeIndex
                          ? AppColors.text
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
                if (i == activeIndex)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CriteriaChip extends StatelessWidget {
  const _CriteriaChip({required this.label, this.onDeleted});

  final String label;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: AppColors.deepBlue,
        ),
      ),
      onDeleted: onDeleted,
      deleteIconColor: AppColors.secondaryText,
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class DiscoverEmptyState extends StatelessWidget {
  const DiscoverEmptyState({
    required this.onBroaden,
    super.key,
  });

  final VoidCallback onBroaden;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(DiscoverIcons.empty, size: 36, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            localizations.discoverEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.discoverEmptyBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onBroaden,
            style: FilledButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: Text(localizations.discoverBroadenSearch),
          ),
        ],
      ),
    );
  }
}
