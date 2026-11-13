import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/mock_data/mock_buying_requests.dart';
import '../../../core/mock_data/mock_businesses.dart';
import '../../home/domain/trade_square_home_feed.dart';
import '../data/trade_square_discover_assistant_service.dart';
import '../data/trade_square_mock_discover_repository.dart';
import '../domain/trade_square_discover_models.dart';
import '../domain/trade_square_discover_search.dart';
import 'widgets/discover_ai_chat_sheet.dart';
import 'widgets/discover_business_card.dart';
import 'widgets/discover_icons.dart';
import 'widgets/discover_network_cards.dart';
import 'widgets/discover_network_image.dart';

class TradeSquareDiscoverPage extends StatefulWidget {
  const TradeSquareDiscoverPage({
    required this.profile,
    required this.locale,
    required this.onLocaleChanged,
    this.searchService,
    this.assistantService,
    this.speechAdapter,
    this.ttsAdapter,
    this.initialQuery,
    this.onViewBusiness,
    this.onContactBusiness,
    this.onOpenMessages,
    this.onOpenBusinessProfile,
    this.onOpenOpportunities,
    this.onOpenHome,
    super.key,
  });

  final TradeSquareHomeProfile profile;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final TradeSquareDiscoverSearchService? searchService;
  final TradeSquareDiscoverAssistantService? assistantService;

  /// Retained for API compatibility. Discover UI no longer uses voice controls.
  final Object? speechAdapter;
  final Object? ttsAdapter;
  final String? initialQuery;
  final ValueChanged<TradeSquareMockBusiness>? onViewBusiness;
  final ValueChanged<TradeSquareMockBusiness>? onContactBusiness;
  final VoidCallback? onOpenMessages;
  final VoidCallback? onOpenBusinessProfile;
  final VoidCallback? onOpenOpportunities;
  final VoidCallback? onOpenHome;

  @override
  State<TradeSquareDiscoverPage> createState() =>
      _TradeSquareDiscoverPageState();
}

class _TradeSquareDiscoverPageState extends State<TradeSquareDiscoverPage> {
  late final TradeSquareDiscoverSearchService _search =
      widget.searchService ?? createTradeSquareDiscoverSearchService();
  late final TradeSquareDiscoverAssistantService _assistant =
      widget.assistantService ??
          TradeSquareLocalDiscoverAssistantService(searchService: _search);

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  TradeSquareDiscoverCatalog? _catalog;
  TradeSquareDiscoverSearchResult? _searchResult;
  StreamSubscription<TradeSquareDiscoverSearchResult>? _searchSub;
  bool _loading = true;
  String? _error;

  String? _industryFilter;
  String? _countryFilter;
  bool _verifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _searchController.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runSearch(initial);
        _openAiChat(initialQuery: initial);
      });
    }
  }

  @override
  void dispose() {
    _searchSub?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _search.loadCatalog(profile: widget.profile);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load Discover recommendations.';
      });
    }
  }

  void _runSearch([String? override]) {
    final query = (override ?? _searchController.text).trim();
    if (query.isEmpty) {
      setState(() => _searchResult = null);
      return;
    }
    _searchSub?.cancel();
    _searchSub = _search
        .searchJourney(query: query, profile: widget.profile)
        .listen((result) {
      if (!mounted) return;
      setState(() => _searchResult = result);
    });
  }

  void _clearSearch() {
    _searchSub?.cancel();
    setState(() {
      _searchController.clear();
      _searchResult = null;
    });
  }

  List<TradeSquareDiscoverBusinessCard> get _suggestions {
    final catalog = _catalog;
    if (catalog == null) return const [];
    final merged = <TradeSquareDiscoverBusinessCard>[
      ...catalog.personalized,
      ...catalog.aiMatches,
    ];
    final seen = <String>{};
    return [
      for (final card in merged)
        if (seen.add(card.business.id)) card,
    ].take(8).toList();
  }

  List<TradeSquareDiscoverBusinessCard> get _recommended {
    final catalog = _catalog;
    if (catalog == null) return const [];
    var cards = [...catalog.allBusinesses];
    if (_industryFilter != null) {
      cards = cards
          .where((card) => card.business.industry == _industryFilter)
          .toList();
    }
    if (_countryFilter != null) {
      cards = cards
          .where((card) => card.business.country == _countryFilter)
          .toList();
    }
    if (_verifiedOnly) {
      cards = cards.where((card) => card.isVerified).toList();
    }
    cards.sort((a, b) => b.reasons.length.compareTo(a.reasons.length));
    return cards;
  }

  List<String> get _industries {
    final catalog = _catalog;
    if (catalog == null) return const [];
    return catalog.allBusinesses
        .map((card) => card.business.industry)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get _countries {
    final catalog = _catalog;
    if (catalog == null) return const [];
    return catalog.allBusinesses
        .map((card) => card.business.country)
        .toSet()
        .toList()
      ..sort();
  }

  List<(TradeSquareMockBuyingRequest, TradeSquareMockBusiness?)>
      get _opportunities {
    final byId = {
      for (final business in tradeSquareMockBusinesses) business.id: business,
    };
    final items = tradeSquareMockBuyingRequests
        .where((request) => request.status.toLowerCase() == 'open')
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return [
      for (final request in items) (request, byId[request.buyerBusinessId]),
    ];
  }

  void _showBusiness(TradeSquareMockBusiness business) {
    widget.onViewBusiness?.call(business);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final verified = business.verificationStatus ==
            TradeSquareMockVerificationStatus.approved;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: DiscoverNetworkImage(
                            url: business.logoUrl,
                            fallbackIcon: Icons.storefront_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          business.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (verified)
                        const Icon(
                          DiscoverIcons.verified,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${business.industry} · ${business.city}, ${business.country}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(business.description, style: const TextStyle(height: 1.4)),
                  if (business.productsOffered.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in business.productsOffered.take(6))
                          Chip(label: Text(item)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _contact(business);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Message'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _contact(TradeSquareMockBusiness business) {
    final handler = widget.onContactBusiness;
    if (handler != null) {
      handler(business);
      return;
    }
    widget.onOpenMessages?.call();
  }

  void _showOpportunity(
    TradeSquareMockBuyingRequest request,
    TradeSquareMockBusiness? buyer,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buying request',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                request.productOrService,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(request.description, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 12),
              Text(
                'Destination: ${request.deliveryDestination}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Preferred suppliers: ${request.preferredSupplierLocation}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (buyer != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Posted by ${buyer.name}',
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (buyer != null) {
                      _contact(buyer);
                    } else {
                      widget.onOpenOpportunities?.call();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Contact about this request'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAiChat({String? initialQuery}) {
    return DiscoverAiChatSheet.open(
      context,
      profile: widget.profile,
      locale: widget.locale,
      assistant: _assistant,
      initialQuery: initialQuery,
      onViewBusiness: _showBusiness,
      onContactBusiness: _contact,
      onOpenMessages: widget.onOpenMessages,
      onOpenBusinessProfile: widget.onOpenBusinessProfile,
      onOpenOpportunities: widget.onOpenOpportunities,
      onOpenHome: widget.onOpenHome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 768;
    final desktop = width >= 1100;
    final horizontal = compact ? 16.0 : 24.0;
    final searching = _searchResult != null &&
        _searchResult!.stage != TradeSquareDiscoverSearchStage.idle;

    return Material(
      color: AppColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktop ? 1180 : 960),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 8),
                sliver: SliverToBoxAdapter(
                  child: _DiscoverHeader(
                    compact: compact,
                    locale: widget.locale,
                    onLocaleChanged: widget.onLocaleChanged,
                    searchController: _searchController,
                    onSearch: () => _runSearch(),
                    onClear: _clearSearch,
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadCatalog,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (searching)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 28),
                  sliver: SliverToBoxAdapter(
                    child: _SearchResultsPanel(
                      result: _searchResult!,
                      onClear: _clearSearch,
                      onView: (card) => _showBusiness(card.business),
                      onContact: (card) => _contact(card.business),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 32),
                  sliver: SliverToBoxAdapter(
                    child: desktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: _MainColumn(
                                  suggestions: _suggestions,
                                  recommended: _recommended,
                                  opportunities: _opportunities,
                                  industries: _industries,
                                  countries: _countries,
                                  industryFilter: _industryFilter,
                                  countryFilter: _countryFilter,
                                  verifiedOnly: _verifiedOnly,
                                  onIndustry: (value) => setState(
                                    () => _industryFilter =
                                        _industryFilter == value ? null : value,
                                  ),
                                  onCountry: (value) => setState(
                                    () => _countryFilter =
                                        _countryFilter == value ? null : value,
                                  ),
                                  onVerified: () => setState(
                                    () => _verifiedOnly = !_verifiedOnly,
                                  ),
                                  onView: _showBusiness,
                                  onMessage: _contact,
                                  onOpenOpportunity: _showOpportunity,
                                ),
                              ),
                              const SizedBox(width: 18),
                              SizedBox(
                                width: 300,
                                child: _SideColumn(
                                  onAskAi: _openAiChat,
                                  markets: _catalog?.markets ?? const [],
                                  onMarket: (country) {
                                    _searchController.text =
                                        'Discover businesses in $country';
                                    _runSearch();
                                  },
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _AiEntryCard(onAskAi: () => _openAiChat()),
                              const SizedBox(height: 18),
                              _MainColumn(
                                suggestions: _suggestions,
                                recommended: _recommended,
                                opportunities: _opportunities,
                                industries: _industries,
                                countries: _countries,
                                industryFilter: _industryFilter,
                                countryFilter: _countryFilter,
                                verifiedOnly: _verifiedOnly,
                                onIndustry: (value) => setState(
                                  () => _industryFilter =
                                      _industryFilter == value ? null : value,
                                ),
                                onCountry: (value) => setState(
                                  () => _countryFilter =
                                      _countryFilter == value ? null : value,
                                ),
                                onVerified: () => setState(
                                  () => _verifiedOnly = !_verifiedOnly,
                                ),
                                onView: _showBusiness,
                                onMessage: _contact,
                                onOpenOpportunity: _showOpportunity,
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.compact,
    required this.locale,
    required this.onLocaleChanged,
    required this.searchController,
    required this.onSearch,
    required this.onClear,
  });

  final bool compact;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Discover',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.text,
                ),
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<Locale>(
                value: locale,
                items: const [
                  DropdownMenuItem(value: Locale('en'), child: Text('EN')),
                  DropdownMenuItem(value: Locale('rw'), child: Text('RW')),
                  DropdownMenuItem(value: Locale('sw'), child: Text('SW')),
                  DropdownMenuItem(value: Locale('fr'), child: Text('FR')),
                ],
                onChanged: (value) {
                  if (value != null) onLocaleChanged(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Find businesses, build regional trade connections and explore commercial opportunities across East Africa.',
          style: TextStyle(
            fontSize: 14.5,
            height: 1.4,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch(),
                decoration: InputDecoration(
                  hintText: 'Search businesses, products, services or partners',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear search',
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onSearch,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 18,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Search'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AiEntryCard extends StatelessWidget {
  const _AiEntryCard({required this.onAskAi});

  final VoidCallback onAskAi;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onAskAi,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ask TradeSquare AI to find business connections…',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({
    required this.suggestions,
    required this.recommended,
    required this.opportunities,
    required this.industries,
    required this.countries,
    required this.industryFilter,
    required this.countryFilter,
    required this.verifiedOnly,
    required this.onIndustry,
    required this.onCountry,
    required this.onVerified,
    required this.onView,
    required this.onMessage,
    required this.onOpenOpportunity,
  });

  final List<TradeSquareDiscoverBusinessCard> suggestions;
  final List<TradeSquareDiscoverBusinessCard> recommended;
  final List<(TradeSquareMockBuyingRequest, TradeSquareMockBusiness?)>
      opportunities;
  final List<String> industries;
  final List<String> countries;
  final String? industryFilter;
  final String? countryFilter;
  final bool verifiedOnly;
  final ValueChanged<String> onIndustry;
  final ValueChanged<String> onCountry;
  final VoidCallback onVerified;
  final ValueChanged<TradeSquareMockBusiness> onView;
  final ValueChanged<TradeSquareMockBusiness> onMessage;
  final void Function(
    TradeSquareMockBuyingRequest request,
    TradeSquareMockBusiness? buyer,
  ) onOpenOpportunity;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 2
        : width >= 700
            ? 2
            : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverSectionHeader(
          title: 'Businesses you may want to know',
          subtitle:
              'Recommendations based on your industry, markets and catalogue overlap — not invented mutual connections.',
        ),
        const SizedBox(height: 12),
        if (suggestions.isEmpty)
          const _EmptyBlock(message: 'No recommendations available yet.')
        else
          SizedBox(
            height: 248,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final card = suggestions[index];
                return DiscoverSuggestionCard(
                  card: card,
                  onView: () => onView(card.business),
                  onMessage: () => onMessage(card.business),
                );
              },
            ),
          ),
        const SizedBox(height: 28),
        DiscoverSectionHeader(
          title: 'Recommended businesses',
          subtitle:
              'Browse companies in related industries, supply chains and regional markets.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DiscoverFilterChip(
              label: 'Verified only',
              selected: verifiedOnly,
              onTap: onVerified,
            ),
            for (final industry in industries.take(8))
              DiscoverFilterChip(
                label: industry,
                selected: industryFilter == industry,
                onTap: () => onIndustry(industry),
              ),
            for (final country in countries)
              DiscoverFilterChip(
                label: country,
                selected: countryFilter == country,
                onTap: () => onCountry(country),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (recommended.isEmpty)
          const _EmptyBlock(message: 'No businesses match these filters.')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = 14.0;
              final itemWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final card in recommended.take(12))
                    SizedBox(
                      width: itemWidth,
                      child: DiscoverBusinessCard(
                        card: card,
                        compact: true,
                        onView: () => onView(card.business),
                        onContact: () => onMessage(card.business),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 28),
        const DiscoverSectionHeader(
          title: 'Commercial opportunities',
          subtitle:
              'Open buying requests from the TradeSquare catalogue. These are distinct from business profiles.',
        ),
        const SizedBox(height: 12),
        if (opportunities.isEmpty)
          const _EmptyBlock(message: 'No open opportunities right now.')
        else
          Column(
            children: [
              for (final entry in opportunities) ...[
                DiscoverOpportunityCard(
                  request: entry.$1,
                  buyer: entry.$2,
                  onOpen: () => onOpenOpportunity(entry.$1, entry.$2),
                  onContact: () {
                    final buyer = entry.$2;
                    if (buyer != null) onMessage(buyer);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.onAskAi,
    required this.markets,
    required this.onMarket,
  });

  final Future<void> Function({String? initialQuery}) onAskAi;
  final List<TradeSquareDiscoverMarketSummary> markets;
  final ValueChanged<String> onMarket;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AiEntryCard(onAskAi: () => onAskAi()),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Explore markets',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Browse businesses by country using live catalogue counts.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              for (final market in markets) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    market.country,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${market.businessCount} businesses'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onMarket(market.country),
                ),
                if (market != markets.last)
                  const Divider(height: 1, color: AppColors.border),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => onAskAi(
                  initialQuery: 'Find distributors for my products.',
                ),
                child: const Text('Try an AI search example'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchResultsPanel extends StatelessWidget {
  const _SearchResultsPanel({
    required this.result,
    required this.onClear,
    required this.onView,
    required this.onContact,
  });

  final TradeSquareDiscoverSearchResult result;
  final VoidCallback onClear;
  final ValueChanged<TradeSquareDiscoverBusinessCard> onView;
  final ValueChanged<TradeSquareDiscoverBusinessCard> onContact;

  @override
  Widget build(BuildContext context) {
    final loading = result.stage == TradeSquareDiscoverSearchStage.understanding ||
        result.stage == TradeSquareDiscoverSearchStage.identifying ||
        result.stage == TradeSquareDiscoverSearchStage.searching ||
        result.stage == TradeSquareDiscoverSearchStage.ranking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Search results for “${result.criteria.rawQuery}”',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        if (result.serviceNote != null) ...[
          const SizedBox(height: 4),
          Text(
            result.serviceNote!,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.secondaryText,
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (result.isEmpty)
          const _EmptyBlock(
            message: 'No catalogue matches yet. Try a broader market or product.',
          )
        else
          Column(
            children: [
              for (final card in result.businesses) ...[
                DiscoverBusinessCard(
                  card: card,
                  compact: true,
                  onView: () => onView(card),
                  onContact: () => onContact(card),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
