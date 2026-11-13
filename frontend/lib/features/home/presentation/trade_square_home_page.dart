import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/trade_square_home_feed.dart';
import '../domain/trade_square_home_partner.dart';
import 'trade_square_opportunity_card.dart';
import 'widgets/home_ai_search.dart';
import 'widgets/home_partners_section.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_welcome_section.dart';

enum TradeSquareHomeFeedState { loading, loaded, error, offline }

class TradeSquareHomePage extends StatelessWidget {
  const TradeSquareHomePage({
    required this.profile,
    this.sections = const [],
    this.partners = const [],
    this.feedState = TradeSquareHomeFeedState.loaded,
    this.interestOptions = const [],
    this.savedOpportunityIds = const {},
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onInterestsChanged,
    this.onRetry,
    this.onLoadMore,
    this.onOpenOpportunity,
    this.onContactBusiness,
    this.onConnect,
    this.onRespondToRequest,
    this.onSaveOpportunity,
    this.onRecommendationFeedback,
    this.onWhySeeing,
    this.onAskAssistant,
    this.onQuickAction,
    this.onOpenPartner,
    super.key,
  });

  final TradeSquareHomeProfile profile;
  final List<TradeSquareFeedSection> sections;
  final List<TradeSquareHomePartner> partners;
  final TradeSquareHomeFeedState feedState;
  final List<String> interestOptions;
  final Set<String> savedOpportunityIds;
  final bool hasMore;
  final bool isLoadingMore;
  final ValueChanged<List<String>>? onInterestsChanged;
  final VoidCallback? onRetry;
  final VoidCallback? onLoadMore;
  final ValueChanged<TradeSquareFeedOpportunity>? onOpenOpportunity;
  final ValueChanged<TradeSquareFeedOpportunity>? onContactBusiness;
  final ValueChanged<TradeSquareFeedOpportunity>? onConnect;
  final ValueChanged<TradeSquareFeedOpportunity>? onRespondToRequest;
  final ValueChanged<TradeSquareFeedOpportunity>? onSaveOpportunity;
  final void Function(
    TradeSquareFeedOpportunity opportunity,
    TradeSquareRecommendationFeedback feedback,
  )? onRecommendationFeedback;
  final ValueChanged<TradeSquareFeedOpportunity>? onWhySeeing;
  final ValueChanged<String>? onAskAssistant;
  final ValueChanged<TradeSquareHomeQuickAction>? onQuickAction;
  final ValueChanged<TradeSquareHomePartner>? onOpenPartner;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        sliver: SliverToBoxAdapter(
          child: TradeSquareHomeWelcomeSection(
                  profile: profile,
            interests: profile.interests,
            onManageInterests: onInterestsChanged == null
                ? null
                : () => _showInterestEditor(context),
          ),
        ),
      ),
            SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              sliver: SliverToBoxAdapter(
          child: TradeSquareHomeAiSearch(
            onAskAssistant: onAskAssistant,
          ),
        ),
      ),
              SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                sliver: SliverToBoxAdapter(
          child: TradeSquareHomeQuickActions(
            onAction: onQuickAction ??
                (action) => _defaultQuickAction(context, action),
          ),
        ),
      ),
    ];

    if (feedState == TradeSquareHomeFeedState.loading) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
                child: _FeedMessage(
                  message: localizations.homeLoading,
                  isLoading: true,
                ),
          ),
        ),
      );
    } else if (feedState == TradeSquareHomeFeedState.error ||
        feedState == TradeSquareHomeFeedState.offline) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
                child: _FeedMessage(
                  message: feedState == TradeSquareHomeFeedState.offline
                      ? localizations.homeOffline
                      : localizations.homeLoadError,
                  actionLabel: onRetry == null ? null : localizations.homeRetry,
                  onAction: onRetry,
                ),
          ),
        ),
      );
    } else if (sections.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
                child: _FeedMessage(
                  message: localizations.homeEmptyBody,
                  title: localizations.homeEmptyTitle,
                ),
          ),
        ),
      );
    } else {
      for (final section in sections) {
        slivers.addAll(_buildSectionSlivers(context, section));
      }
    }

            if (feedState == TradeSquareHomeFeedState.loaded &&
                hasMore &&
        onLoadMore != null) {
      slivers.add(
              SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: OutlinedButton(
                      onPressed: isLoadingMore ? null : onLoadMore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                      child: isLoadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(localizations.homeLoadMore),
                    ),
                  ),
        ),
      ),
    );
                        } else {
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 12)));
    }

    if (partners.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          sliver: SliverToBoxAdapter(
            child: TradeSquareHomePartnersSection(
              partners: partners,
              onOpenPartner: onOpenPartner,
            ),
          ),
        ),
      );
    } else {
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 20)));
    }

    return ColoredBox(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > 920 ? 920.0 : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: CustomScrollView(
                key: const PageStorageKey<String>('trade-square-home-feed'),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                cacheExtent: 800,
                slivers: slivers,
              ),
              ),
            );
          },
      ),
    );
  }

  List<Widget> _buildSectionSlivers(
    BuildContext context,
    TradeSquareFeedSection section,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final title = _sectionTitle(localizations, section.type);
    final opportunities = section.opportunities;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                localizations.homeFeedIntro,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
      ),
      if (opportunities.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: Container(
          width: double.infinity,
              padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
                color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
                    child: Text(
                localizations.homeNoSectionItems,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              for (var index = 0; index < opportunities.length; index++) ...[
                TradeSquareOpportunityCard(
                  opportunity: opportunities[index],
                  isSaved:
                      savedOpportunityIds.contains(opportunities[index].id),
                  onOpen: onOpenOpportunity,
                  onContact: onContactBusiness,
                  onConnect: onConnect,
                  onRespond: onRespondToRequest,
                  onSave: onSaveOpportunity,
                  onFeedback: onRecommendationFeedback,
                  onWhySeeing: onWhySeeing,
                ),
                if (index != opportunities.length - 1)
                  const SizedBox(height: 12),
              ],
            ]),
          ),
        ),
    ];
  }

  Future<void> _showInterestEditor(BuildContext context) async {
    if (onInterestsChanged == null) return;

    final localizations = AppLocalizations.of(context)!;
    final selected = Set<String>.from(profile.interests);
    final options =
        interestOptions.isEmpty ? profile.interests : interestOptions;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
    return Container(
              margin: const EdgeInsets.only(top: 80),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  Center(
                child: Container(
                      width: 42,
                      height: 4,
                  decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
            Text(
                    localizations.homeManageInterestsTitle,
              style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
                  const SizedBox(height: 6),
          Text(
                    localizations.homeManageInterestsHint,
            style: const TextStyle(
                      color: AppColors.secondaryText,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (options.isEmpty)
                    Text(localizations.homeInterestOptionsEmpty)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: options.map((option) {
                        final isSelected = selected.contains(option);
                        return FilterChip(
                          label: Text(option),
                          selected: isSelected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                selected.add(option);
                              } else {
                                selected.remove(option);
                              }
                            });
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.14),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.deepBlue
                                : AppColors.text,
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  Row(
            children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(localizations.homeCancel),
                        ),
                      ),
                      const SizedBox(width: 10),
          Expanded(
                        child: FilledButton(
                          onPressed: () {
                            onInterestsChanged!(selected.toList());
                            Navigator.of(context).pop();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(localizations.homeSaveInterests),
                  ),
                ),
              ],
          ),
        ],
      ),
    );
          },
        );
      },
    );
  }

  void _defaultQuickAction(
    BuildContext context,
    TradeSquareHomeQuickAction action,
  ) {
    final label = switch (action) {
      TradeSquareHomeQuickAction.findBuyers => 'Find Buyers',
      TradeSquareHomeQuickAction.findSuppliers => 'Find Suppliers',
      TradeSquareHomeQuickAction.findPartners => 'Find Partners',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepBlue,
        content: Text('$label opens when discovery matching is connected.'),
      ),
    );
  }

  String _sectionTitle(
    AppLocalizations localizations,
    TradeSquareFeedSectionType type,
  ) {
    return switch (type) {
      TradeSquareFeedSectionType.opportunities =>
        localizations.homeSectionOpportunities,
      TradeSquareFeedSectionType.buyers => localizations.homeSectionBuyers,
      TradeSquareFeedSectionType.suppliers =>
        localizations.homeSectionSuppliers,
      TradeSquareFeedSectionType.products => localizations.homeSectionProducts,
      TradeSquareFeedSectionType.businesses =>
        localizations.homeSectionBusinesses,
      TradeSquareFeedSectionType.buyingRequests =>
        localizations.homeSectionBuyingRequests,
      TradeSquareFeedSectionType.tradeOpportunities =>
        localizations.homeSectionTradeOpportunities,
      TradeSquareFeedSectionType.marketInsights =>
        localizations.homeSectionMarketInsights,
      TradeSquareFeedSectionType.aiRecommendations =>
        localizations.homeSectionAiRecommendations,
    };
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.message,
    this.title,
    this.isLoading = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final bool isLoading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
