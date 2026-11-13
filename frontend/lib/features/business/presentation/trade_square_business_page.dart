import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/mock_data/mock_business_verification.dart';
import '../../../core/mock_data/mock_businesses.dart';
import '../../../core/mock_data/mock_products.dart';
import '../../authentication/domain/trade_square_auth_models.dart';
import '../../discover/presentation/widgets/discover_network_image.dart';
import '../../home/domain/trade_square_home_feed.dart';
import '../data/trade_square_mock_business_repository.dart';
import '../domain/trade_square_business_workspace.dart';
import 'widgets/business_profile_header.dart';
import 'widgets/business_workspace_sections.dart';

class TradeSquareBusinessPage extends StatefulWidget {
  const TradeSquareBusinessPage({
    required this.role,
    required this.profile,
    this.repository,
    super.key,
  });

  final TradeSquareAccountRole role;
  final TradeSquareHomeProfile profile;
  final TradeSquareBusinessRepository? repository;

  @override
  State<TradeSquareBusinessPage> createState() =>
      _TradeSquareBusinessPageState();
}

class _TradeSquareBusinessPageState extends State<TradeSquareBusinessPage> {
  late final TradeSquareBusinessRepository _repository =
      widget.repository ?? TradeSquareMockBusinessRepository();

  TradeSquareBusinessWorkspace? _workspace;
  bool _loading = true;
  String? _error;
  bool _previewMode = false;
  TradeSquareBusinessTab _tab = TradeSquareBusinessTab.overview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TradeSquareBusinessPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role ||
        oldWidget.profile.businessName != widget.profile.businessName) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workspace = await _repository.loadWorkspace(
        role: widget.role,
        profile: widget.profile,
      );
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your business workspace.';
      });
    }
  }

  void _updateWorkspace(TradeSquareBusinessWorkspace Function(
    TradeSquareBusinessWorkspace current,
  ) updater) {
    final current = _workspace;
    if (current == null) return;
    setState(() => _workspace = updater(current));
  }

  void _selectTab(TradeSquareBusinessTab tab) {
    setState(() => _tab = tab);
  }

  Future<void> _editBusiness() async {
    final workspace = _workspace;
    if (workspace == null) return;
    final business = workspace.business;
    final name = TextEditingController(text: business.name);
    final description = TextEditingController(text: business.description);
    final website = TextEditingController(text: business.website);
    final phone = TextEditingController(text: business.phone);
    final email = TextEditingController(text: business.email);
    final markets = TextEditingController(
      text: business.preferredMarkets.join(', '),
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit business',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Business name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: website,
                  decoration: const InputDecoration(
                    labelText: 'Website',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: markets,
                  decoration: const InputDecoration(
                    labelText: 'Markets served (comma separated)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      final updated = TradeSquareMockBusiness(
        id: business.id,
        name: name.text.trim().isEmpty ? business.name : name.text.trim(),
        logoUrl: business.logoUrl,
        description: description.text.trim(),
        industry: business.industry,
        category: business.category,
        country: business.country,
        province: business.province,
        city: business.city,
        address: business.address,
        email: email.text.trim(),
        phone: phone.text.trim(),
        website: website.text.trim(),
        registrationNumber: business.registrationNumber,
        registrationCertificateType: business.registrationCertificateType,
        certificateSubmissionStatus: business.certificateSubmissionStatus,
        verificationStatus: business.verificationStatus,
        businessSize: business.businessSize,
        yearEstablished: business.yearEstablished,
        productsOffered: business.productsOffered,
        productsNeeded: business.productsNeeded,
        businessInterests: business.businessInterests,
        preferredMarkets: markets.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        ownerId: business.ownerId,
        profileCompleteness: business.profileCompleteness,
        createdAt: business.createdAt,
      );
      _updateWorkspace((current) => current.copyWith(business: updated));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business details updated locally.')),
      );
    }

    name.dispose();
    description.dispose();
    website.dispose();
    phone.dispose();
    email.dispose();
    markets.dispose();
  }

  void _previewProfile() {
    setState(() => _previewMode = true);
  }

  Future<void> _addOrEditProduct({TradeSquareMockProductListing? existing}) async {
    final workspace = _workspace;
    if (workspace == null) return;
    final result = await showBusinessProductEditor(
      context: context,
      businessId: workspace.business.id,
      existing: existing,
    );
    if (result == null || !mounted) return;
    _updateWorkspace((current) {
      final products = [...current.products];
      final index = products.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        products[index] = result;
      } else {
        products.insert(0, result);
      }
      return current.copyWith(products: products);
    });
  }

  void _deleteProduct(TradeSquareMockProductListing product) {
    _updateWorkspace((current) {
      return current.copyWith(
        products: current.products.where((item) => item.id != product.id).toList(),
      );
    });
  }

  Future<void> _addOrEditOpportunity({
    TradeSquareBusinessOpportunityItem? existing,
  }) async {
    final result = await showBusinessOpportunityEditor(
      context: context,
      existing: existing,
    );
    if (result == null || !mounted) return;
    _updateWorkspace((current) {
      final items = [...current.opportunities];
      final index = items.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        items[index] = result;
      } else {
        items.insert(0, result);
      }
      return current.copyWith(opportunities: items);
    });
  }

  void _toggleOpportunity(TradeSquareBusinessOpportunityItem item) {
    final paused = item.status.toLowerCase() == 'paused' ||
        item.status.toLowerCase() == 'closed';
    final next = TradeSquareBusinessOpportunityItem(
      id: item.id,
      title: item.title,
      kind: item.kind,
      status: paused ? 'Open' : 'Paused',
      publishedAt: item.publishedAt,
      summary: item.summary,
    );
    _updateWorkspace((current) {
      return current.copyWith(
        opportunities: current.opportunities
            .map((entry) => entry.id == item.id ? next : entry)
            .toList(),
      );
    });
  }

  void _deleteOpportunity(TradeSquareBusinessOpportunityItem item) {
    _updateWorkspace((current) {
      return current.copyWith(
        opportunities:
            current.opportunities.where((entry) => entry.id != item.id).toList(),
      );
    });
  }

  void _viewOpportunity(TradeSquareBusinessOpportunityItem item) {
    final kindLabel = switch (item.kind) {
      TradeSquareBusinessOpportunityKind.buyingRequest => 'Buying request',
      TradeSquareBusinessOpportunityKind.supplierOffer => 'Supplier offer',
      TradeSquareBusinessOpportunityKind.partnership => 'Partnership',
    };
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
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$kindLabel · ${item.status}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.summary,
                style: const TextStyle(fontSize: 14.5, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _manageVerification() async {
    final workspace = _workspace;
    if (workspace == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BusinessVerificationCard(
                workspace: workspace,
                expanded: true,
                onManage: () {},
              ),
              const SizedBox(height: 16),
              if (workspace.verification.status !=
                  TradeSquareMockVerificationState.approved)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updateWorkspace((current) {
                        return current.copyWith(
                          verification: TradeSquareMockBusinessVerification(
                            businessId: current.business.id,
                            status: TradeSquareMockVerificationState.submitted,
                            reviewMessage:
                                'Documents submitted for review in this local preview. No live verification started.',
                            lastUpdated: DateTime.now().toUtc(),
                          ),
                        );
                      });
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Verification documents marked as submitted locally.',
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Submit / update documents'),
                  ),
                )
              else
                const Text(
                  'Approved badge is shown because verification status is approved.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.secondaryText,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyAiDraft(TradeSquareBusinessAiSuggestion suggestion) async {
    final controller = TextEditingController(text: suggestion.draft);
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestion.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Edit this draft before applying. AI is not live yet — this is a local suggestion.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Draft',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Apply to profile'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (apply == true && mounted) {
      final draft = controller.text.trim();
      if (suggestion.id == 'ai_desc' || suggestion.contextLabel == 'Profile copy') {
        _updateWorkspace((current) {
          final business = current.business;
          return current.copyWith(
            business: TradeSquareMockBusiness(
              id: business.id,
              name: business.name,
              logoUrl: business.logoUrl,
              description: draft,
              industry: business.industry,
              category: business.category,
              country: business.country,
              province: business.province,
              city: business.city,
              address: business.address,
              email: business.email,
              phone: business.phone,
              website: business.website,
              registrationNumber: business.registrationNumber,
              registrationCertificateType: business.registrationCertificateType,
              certificateSubmissionStatus: business.certificateSubmissionStatus,
              verificationStatus: business.verificationStatus,
              businessSize: business.businessSize,
              yearEstablished: business.yearEstablished,
              productsOffered: business.productsOffered,
              productsNeeded: business.productsNeeded,
              businessInterests: business.businessInterests,
              preferredMarkets: business.preferredMarkets,
              ownerId: business.ownerId,
              profileCompleteness: business.profileCompleteness,
              createdAt: business.createdAt,
            ),
          );
        });
      } else if (suggestion.id == 'ai_request') {
        final opportunity = TradeSquareBusinessOpportunityItem(
          id: 'opp_ai_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Buying request draft',
          kind: TradeSquareBusinessOpportunityKind.buyingRequest,
          status: 'Open',
          publishedAt: DateTime.now().toUtc(),
          summary: draft,
        );
        _updateWorkspace((current) {
          return current.copyWith(
            opportunities: [opportunity, ...current.opportunities],
          );
        });
        _selectTab(TradeSquareBusinessTab.opportunities);
      } else if (_workspace?.products.isNotEmpty == true) {
        final product = _workspace!.products.first;
        _updateWorkspace((current) {
          final products = [...current.products];
          products[0] = TradeSquareMockProductListing(
            id: product.id,
            businessId: product.businessId,
            name: product.name,
            productImage: product.productImage,
            description: draft,
            category: product.category,
            industry: product.industry,
            condition: product.condition,
            unit: product.unit,
            availableQuantity: product.availableQuantity,
            minimumOrderQuantity: product.minimumOrderQuantity,
            indicativePrice: product.indicativePrice,
            currency: product.currency,
            countryOfOrigin: product.countryOfOrigin,
            deliveryLocations: product.deliveryLocations,
            availabilityStatus: product.availabilityStatus,
            listingStatus: product.listingStatus,
            publishedAt: product.publishedAt,
            views: product.views,
            savedCount: product.savedCount,
          );
          return current.copyWith(products: products);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft applied. Review before sharing publicly.')),
      );
    }
    controller.dispose();
  }

  void _handleImprovement(TradeSquareBusinessImprovement item) {
    switch (item.id) {
      case 'products':
        _selectTab(TradeSquareBusinessTab.products);
        _addOrEditProduct();
      case 'verify':
        _manageVerification();
      case 'desc':
      case 'website':
      case 'markets':
        _editBusiness();
      default:
        _editBusiness();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 768;
    final maxContent = width >= 1280 ? 980.0 : 880.0;

    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null || _workspace == null) {
      return ColoredBox(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Business workspace unavailable'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final workspace = _workspace!;

    if (_previewMode) {
      return _PublicPreview(
        workspace: workspace,
        onExit: () => setState(() => _previewMode = false),
      );
    }

    final tabContent = switch (_tab) {
      TradeSquareBusinessTab.overview => BusinessOverviewSection(
          workspace: workspace,
          onEditBusiness: _editBusiness,
          onOpenProducts: () => _selectTab(TradeSquareBusinessTab.products),
          onOpenVerification: _manageVerification,
          onApplyAiDraft: _applyAiDraft,
          onImprovementAction: _handleImprovement,
        ),
      TradeSquareBusinessTab.products => BusinessProductsSection(
          products: workspace.products,
          onAdd: () => _addOrEditProduct(),
          onEdit: (product) => _addOrEditProduct(existing: product),
          onDelete: _deleteProduct,
        ),
      TradeSquareBusinessTab.opportunities => BusinessOpportunitiesSection(
          items: workspace.opportunities,
          onCreate: () => _addOrEditOpportunity(),
          onEdit: (item) => _addOrEditOpportunity(existing: item),
          onTogglePause: _toggleOpportunity,
          onDelete: _deleteOpportunity,
          onView: _viewOpportunity,
        ),
      TradeSquareBusinessTab.activity =>
        BusinessActivitySection(workspace: workspace),
    };

    return Material(
      color: AppColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContent),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (!compact) const SizedBox(height: 8),
                    Container(
                      color: AppColors.white,
                      child: BusinessProfileHeader(
                        business: workspace.business,
                        coverImageUrl: workspace.coverImageUrl,
                        isVerified: workspace.isVerified,
                        onEdit: _editBusiness,
                        onPreview: _previewProfile,
                      ),
                    ),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _BusinessTabBarDelegate(
                  selected: _tab,
                  compact: compact,
                  onSelect: _selectTab,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: tabContent,
                    ),
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

class _BusinessTabBarDelegate extends SliverPersistentHeaderDelegate {
  _BusinessTabBarDelegate({
    required this.selected,
    required this.compact,
    required this.onSelect,
  });

  final TradeSquareBusinessTab selected;
  final bool compact;
  final ValueChanged<TradeSquareBusinessTab> onSelect;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tabs = <(TradeSquareBusinessTab, String)>[
      (TradeSquareBusinessTab.overview, 'Overview'),
      (TradeSquareBusinessTab.products, 'Products & Services'),
      (TradeSquareBusinessTab.opportunities, 'Opportunities'),
      (TradeSquareBusinessTab.activity, 'Business Activity'),
    ];

    return Material(
      color: AppColors.white,
      elevation: shrinkOffset > 0 ? 1 : 0,
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
          child: Row(
            children: [
              for (final entry in tabs) ...[
                InkWell(
                  onTap: () => onSelect(entry.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 48,
                    padding:
                        EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: entry.$1 == selected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      entry.$2,
                      style: TextStyle(
                        fontWeight: entry.$1 == selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 14,
                        color: entry.$1 == selected
                            ? AppColors.text
                            : AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _BusinessTabBarDelegate oldDelegate) {
    return oldDelegate.selected != selected || oldDelegate.compact != compact;
  }
}

class _PublicPreview extends StatelessWidget {
  const _PublicPreview({
    required this.workspace,
    required this.onExit,
  });

  final TradeSquareBusinessWorkspace workspace;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final business = workspace.business;
    final compact = MediaQuery.sizeOf(context).width < 768;

    return Material(
      color: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.deepBlue,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 10,
              16,
              12,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onExit,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.white,
                ),
                const Expanded(
                  child: Text(
                    'Public preview',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onExit,
                  child: const Text(
                    'Exit preview',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: compact ? 140 : 180,
                  width: double.infinity,
                  child: DiscoverNetworkImage(
                    url: workspace.coverImageUrl,
                    fallbackIcon: Icons.apartment_outlined,
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.white, width: 4),
                          ),
                          child: ClipOval(
                            child: DiscoverNetworkImage(
                              url: business.logoUrl,
                              fallbackIcon: Icons.storefront_outlined,
                            ),
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text('Message'),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              business.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (workspace.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${business.industry} · ${business.city}, ${business.country}',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        business.description,
                        style: const TextStyle(height: 1.4, fontSize: 14.5),
                      ),
                      if (business.preferredMarkets.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Markets: ${business.preferredMarkets.join(', ')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'Products & services',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (workspace.products.isEmpty)
                        const Text(
                          'No public listings yet.',
                          style: TextStyle(color: AppColors.secondaryText),
                        )
                      else
                        ...workspace.products.take(4).map(
                              (product) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 56,
                                        height: 56,
                                        child: DiscoverNetworkImage(
                                          url: product.productImage,
                                          fallbackIcon:
                                              Icons.inventory_2_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            product.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
