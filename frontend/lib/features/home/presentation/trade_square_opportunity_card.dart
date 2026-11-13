import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/trade_square_home_feed.dart';

class TradeSquareOpportunityCard extends StatefulWidget {
  const TradeSquareOpportunityCard({
    required this.opportunity,
    required this.isSaved,
    this.onOpen,
    this.onContact,
    this.onConnect,
    this.onRespond,
    this.onSave,
    this.onFeedback,
    this.onWhySeeing,
    super.key,
  });

  final TradeSquareFeedOpportunity opportunity;
  final bool isSaved;
  final ValueChanged<TradeSquareFeedOpportunity>? onOpen;
  final ValueChanged<TradeSquareFeedOpportunity>? onContact;
  final ValueChanged<TradeSquareFeedOpportunity>? onConnect;
  final ValueChanged<TradeSquareFeedOpportunity>? onRespond;
  final ValueChanged<TradeSquareFeedOpportunity>? onSave;
  final void Function(
    TradeSquareFeedOpportunity opportunity,
    TradeSquareRecommendationFeedback feedback,
  )? onFeedback;
  final ValueChanged<TradeSquareFeedOpportunity>? onWhySeeing;

  @override
  State<TradeSquareOpportunityCard> createState() =>
      _TradeSquareOpportunityCardState();
}

class _TradeSquareOpportunityCardState
    extends State<TradeSquareOpportunityCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final opportunity = widget.opportunity;
    final typeLabel = switch (opportunity.type) {
      TradeSquareOpportunityType.productListing => 'Supplier offer',
      TradeSquareOpportunityType.business => 'Business',
      TradeSquareOpportunityType.buyerRequest => 'Buying request',
      TradeSquareOpportunityType.supplier => 'Supplier',
      TradeSquareOpportunityType.tradeOpportunity => 'Partnership',
      TradeSquareOpportunityType.marketInsight => 'Insight',
    };

    String? primaryLabel;
    VoidCallback? primaryOnPressed;
    if (opportunity.type == TradeSquareOpportunityType.buyerRequest &&
        widget.onRespond != null) {
      primaryLabel = localizations.homeRespond;
      primaryOnPressed = () => widget.onRespond!(opportunity);
    } else if (opportunity.type == TradeSquareOpportunityType.business &&
        widget.onConnect != null) {
      primaryLabel = localizations.homeConnect;
      primaryOnPressed = () => widget.onConnect!(opportunity);
    } else if ((opportunity.type == TradeSquareOpportunityType.supplier ||
            opportunity.type == TradeSquareOpportunityType.productListing) &&
        widget.onContact != null) {
      primaryLabel = localizations.homeContact;
      primaryOnPressed = () => widget.onContact!(opportunity);
    } else if (widget.onOpen != null) {
      primaryLabel = localizations.homeViewDetails;
      primaryOnPressed = () => widget.onOpen!(opportunity);
    }

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: primaryOnPressed,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepBlue.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TypeBadge(label: typeLabel, type: opportunity.type),
                    const Spacer(),
                    if (widget.onSave != null)
                      IconButton(
                        tooltip: widget.isSaved
                            ? localizations.homeSaved
                            : localizations.homeSave,
                        onPressed: () {
                          widget.onSave!(opportunity);
                          widget.onFeedback?.call(
                            opportunity,
                            TradeSquareRecommendationFeedback.save,
                          );
                        },
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          widget.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: widget.isSaved
                              ? AppColors.primary
                              : AppColors.secondaryText,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (opportunity.imageUrl != null &&
                        opportunity.imageUrl!.trim().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          opportunity.imageUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _ImageFallback(type: opportunity.type),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ] else ...[
                      _ImageFallback(type: opportunity.type),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opportunity.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              height: 1.25,
                            ),
                          ),
                          if (opportunity.businessName != null &&
                              opportunity.businessName!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    opportunity.businessName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.deepBlue,
                                    ),
                                  ),
                                ),
                                if (opportunity.isVerified) ...[
                                  const SizedBox(width: 5),
                                  Tooltip(
                                    message: localizations.homeVerifiedBusiness,
                                    child: Icon(
                                      Icons.verified_rounded,
                                      size: 15,
                                      color: theme.colorScheme.primary,
                                      semanticLabel:
                                          localizations.homeVerifiedBusiness,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (opportunity.category != null ||
                    opportunity.industry != null ||
                    opportunity.location != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (opportunity.category != null &&
                          opportunity.category!.isNotEmpty)
                        _MetadataChip(label: opportunity.category!),
                      if (opportunity.industry != null &&
                          opportunity.industry!.isNotEmpty)
                        _MetadataChip(label: opportunity.industry!),
                      if (opportunity.location != null &&
                          opportunity.location!.isNotEmpty)
                        _MetadataChip(
                          label: opportunity.location!,
                          icon: Icons.location_on_outlined,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  opportunity.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryText,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (primaryLabel != null && primaryOnPressed != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: primaryOnPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        primaryLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
                if (widget.onFeedback != null || widget.onWhySeeing != null) ...[
                  const SizedBox(height: 4),
                  _RecommendationActions(
                    opportunity: opportunity,
                    onFeedback: widget.onFeedback,
                    onWhySeeing: widget.onWhySeeing,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.type});

  final String label;
  final TradeSquareOpportunityType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.deepBlue,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.secondaryText),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.type});

  final TradeSquareOpportunityType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      TradeSquareOpportunityType.productListing => Icons.inventory_2_outlined,
      TradeSquareOpportunityType.business => Icons.business_outlined,
      TradeSquareOpportunityType.buyerRequest => Icons.assignment_outlined,
      TradeSquareOpportunityType.supplier => Icons.local_shipping_outlined,
      TradeSquareOpportunityType.tradeOpportunity => Icons.handshake_outlined,
      TradeSquareOpportunityType.marketInsight => Icons.query_stats_outlined,
    };
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.lightBlue.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Icon(icon, color: AppColors.primary),
    );
  }
}

class _RecommendationActions extends StatelessWidget {
  const _RecommendationActions({
    required this.opportunity,
    required this.onFeedback,
    required this.onWhySeeing,
  });

  final TradeSquareFeedOpportunity opportunity;
  final void Function(
    TradeSquareFeedOpportunity opportunity,
    TradeSquareRecommendationFeedback feedback,
  )? onFeedback;
  final ValueChanged<TradeSquareFeedOpportunity>? onWhySeeing;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (onFeedback != null)
          TextButton.icon(
            onPressed: () => onFeedback!.call(
              opportunity,
              TradeSquareRecommendationFeedback.moreLikeThis,
            ),
            icon: const Icon(Icons.tune, size: 17),
            label: Text(localizations.homeMoreLikeThis),
          ),
        if (onFeedback != null)
          TextButton.icon(
            onPressed: () => onFeedback!.call(
              opportunity,
              TradeSquareRecommendationFeedback.notInterested,
            ),
            icon: const Icon(Icons.thumb_down_outlined, size: 17),
            label: Text(localizations.homeNotInterested),
          ),
        if (onWhySeeing != null)
          TextButton.icon(
            onPressed: () {
              onWhySeeing!(opportunity);
              _showReasons(context, localizations);
            },
            icon: const Icon(Icons.info_outline, size: 17),
            label: Text(localizations.homeWhySeeing),
          ),
      ],
    );
  }

  Future<void> _showReasons(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    final reasonLabels = opportunity.recommendationReasons
        .map((reason) => _reasonLabel(localizations, reason))
        .toList();
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.homeWhyTitle),
        content: reasonLabels.isEmpty
            ? Text(localizations.homeWhyGeneric)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: reasonLabels
                    .map(
                      (label) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(label)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.homeCancel),
          ),
        ],
      ),
    );
  }

  String _reasonLabel(
    AppLocalizations localizations,
    TradeSquareRecommendationReason reason,
  ) {
    return switch (reason) {
      TradeSquareRecommendationReason.industryMatch =>
        localizations.homeWhyIndustry,
      TradeSquareRecommendationReason.categoryMatch =>
        localizations.homeWhyCategory,
      TradeSquareRecommendationReason.interestMatch =>
        localizations.homeWhyInterest,
      TradeSquareRecommendationReason.productMatch =>
        localizations.homeWhyProduct,
      TradeSquareRecommendationReason.locationMatch =>
        localizations.homeWhyLocation,
      TradeSquareRecommendationReason.commercialIntentMatch =>
        localizations.homeWhyIntent,
      TradeSquareRecommendationReason.recent => localizations.homeWhyRecent,
    };
  }
}
