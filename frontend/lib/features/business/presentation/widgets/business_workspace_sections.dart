import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/mock_data/mock_business_verification.dart';
import '../../../../core/mock_data/mock_products.dart';
import '../../../discover/presentation/widgets/discover_network_image.dart';
import '../../domain/trade_square_business_workspace.dart';

class BusinessSectionCard extends StatelessWidget {
  const BusinessSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
      ),
    );
  }
}

class BusinessOverviewSection extends StatelessWidget {
  const BusinessOverviewSection({
    required this.workspace,
    required this.onEditBusiness,
    required this.onOpenProducts,
    required this.onOpenVerification,
    required this.onApplyAiDraft,
    required this.onImprovementAction,
    super.key,
  });

  final TradeSquareBusinessWorkspace workspace;
  final VoidCallback onEditBusiness;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenVerification;
  final ValueChanged<TradeSquareBusinessAiSuggestion> onApplyAiDraft;
  final ValueChanged<TradeSquareBusinessImprovement> onImprovementAction;

  @override
  Widget build(BuildContext context) {
    final business = workspace.business;
    final width = MediaQuery.sizeOf(context).width;
    final twoCol = width >= 960;

    final intro = BusinessSectionCard(
      title: 'About the business',
      subtitle: 'How your company introduces itself on TradeSquare.',
      trailing: TextButton(
        onPressed: onEditBusiness,
        child: const Text('Edit'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            business.description,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(label: 'Industry', value: business.industry),
              _InfoPill(label: 'Category', value: business.category),
              _InfoPill(label: 'Size', value: business.businessSize),
              _InfoPill(
                label: 'Location',
                value: '${business.city}, ${business.country}',
              ),
            ],
          ),
        ],
      ),
    );

    final productsPreview = BusinessSectionCard(
      title: 'Products & services',
      subtitle: workspace.products.isEmpty
          ? 'Publish offerings so buyers can find you.'
          : 'A quick look at what you currently offer.',
      trailing: TextButton(
        onPressed: onOpenProducts,
        child: Text(workspace.products.isEmpty ? 'Add' : 'Manage'),
      ),
      child: workspace.products.isEmpty
          ? const _EmptyHint(
              icon: Icons.inventory_2_outlined,
              message: 'No products listed yet.',
            )
          : Column(
              children: [
                for (final product in workspace.products.take(3)) ...[
                  _ProductPreviewRow(product: product),
                  if (product != workspace.products.take(3).last)
                    const Divider(height: 20, color: AppColors.border),
                ],
              ],
            ),
    );

    final info = BusinessSectionCard(
      title: 'Business information',
      child: Column(
        children: [
          _DetailRow(label: 'Email', value: business.email),
          _DetailRow(label: 'Phone', value: business.phone),
          _DetailRow(
            label: 'Website',
            value: business.website.isEmpty ? 'Not added' : business.website,
          ),
          _DetailRow(
            label: 'Registration',
            value: business.registrationNumber.isEmpty
                ? 'Not provided'
                : business.registrationNumber,
          ),
          _DetailRow(
            label: 'Markets served',
            value: business.preferredMarkets.isEmpty
                ? 'Not set'
                : business.preferredMarkets.join(', '),
          ),
        ],
      ),
    );

    final verification = BusinessVerificationCard(
      workspace: workspace,
      onManage: onOpenVerification,
    );

    final improvements = BusinessSectionCard(
      title: 'Profile improvements',
      subtitle: workspace.improvements.isEmpty
          ? 'Your profile looks solid. Keep listings up to date.'
          : 'Optional steps to improve discoverability.',
      child: workspace.improvements.isEmpty
          ? const _EmptyHint(
              icon: Icons.check_circle_outline,
              message: 'No urgent improvements right now.',
            )
          : Column(
              children: [
                for (final item in workspace.improvements) ...[
                  _ImprovementTile(
                    item: item,
                    onTap: () => onImprovementAction(item),
                  ),
                  if (item != workspace.improvements.last)
                    const SizedBox(height: 10),
                ],
              ],
            ),
    );

    final ai = BusinessAiAssistCard(
      suggestions: workspace.aiSuggestions,
      onApply: onApplyAiDraft,
    );

    if (twoCol) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    intro,
                    const SizedBox(height: 14),
                    productsPreview,
                    const SizedBox(height: 14),
                    ai,
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    info,
                    const SizedBox(height: 14),
                    verification,
                    const SizedBox(height: 14),
                    improvements,
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        intro,
        const SizedBox(height: 14),
        productsPreview,
        const SizedBox(height: 14),
        info,
        const SizedBox(height: 14),
        verification,
        const SizedBox(height: 14),
        improvements,
        const SizedBox(height: 14),
        ai,
      ],
    );
  }
}

class BusinessProductsSection extends StatelessWidget {
  const BusinessProductsSection({
    required this.products,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<TradeSquareMockProductListing> products;
  final VoidCallback onAdd;
  final ValueChanged<TradeSquareMockProductListing> onEdit;
  final ValueChanged<TradeSquareMockProductListing> onDelete;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 3
        : width >= 700
            ? 2
            : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Products & services',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add product'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Manage listings your buyers and partners can discover.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 16),
        if (products.isEmpty)
          const BusinessSectionCard(
            title: 'No listings yet',
            child: _EmptyHint(
              icon: Icons.inventory_2_outlined,
              message: 'Add your first product or service to start attracting interest.',
            ),
          )
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
                  for (final product in products)
                    SizedBox(
                      width: itemWidth,
                      child: _ProductCard(
                        product: product,
                        onEdit: () => onEdit(product),
                        onDelete: () => onDelete(product),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class BusinessOpportunitiesSection extends StatelessWidget {
  const BusinessOpportunitiesSection({
    required this.items,
    required this.onCreate,
    required this.onEdit,
    required this.onTogglePause,
    required this.onDelete,
    required this.onView,
    super.key,
  });

  final List<TradeSquareBusinessOpportunityItem> items;
  final VoidCallback onCreate;
  final ValueChanged<TradeSquareBusinessOpportunityItem> onEdit;
  final ValueChanged<TradeSquareBusinessOpportunityItem> onTogglePause;
  final ValueChanged<TradeSquareBusinessOpportunityItem> onDelete;
  final ValueChanged<TradeSquareBusinessOpportunityItem> onView;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Opportunities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Buying requests, supplier offers and partnership outreach you published.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const BusinessSectionCard(
            title: 'No opportunities yet',
            child: _EmptyHint(
              icon: Icons.handshake_outlined,
              message: 'Create a buying request or supplier offer to get started.',
            ),
          )
        else
          Column(
            children: [
              for (final item in items) ...[
                _OpportunityCard(
                  item: item,
                  onEdit: () => onEdit(item),
                  onTogglePause: () => onTogglePause(item),
                  onDelete: () => onDelete(item),
                  onView: () => onView(item),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }
}

class BusinessActivitySection extends StatelessWidget {
  const BusinessActivitySection({
    required this.workspace,
    super.key,
  });

  final TradeSquareBusinessWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900
        ? 4
        : width >= 600
            ? 2
            : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Metrics drawn from your published listings and opportunities. No estimated or invented figures.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = 12.0;
            final itemWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final metric in workspace.activity)
                  SizedBox(
                    width: itemWidth,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            metric.valueLabel,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metric.detail,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (workspace.analytics.isNotEmpty) ...[
          const SizedBox(height: 16),
          BusinessSectionCard(
            title: 'Marketplace signals',
            subtitle: 'Additional activity available from TradeSquare analytics.',
            child: Column(
              children: [
                for (final row in workspace.analytics) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.metric,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Text(
                        '${row.value}${row.unit.isEmpty ? '' : ' ${row.unit}'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepBlue,
                        ),
                      ),
                    ],
                  ),
                  if (row != workspace.analytics.last)
                    const Divider(height: 18, color: AppColors.border),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class BusinessVerificationCard extends StatelessWidget {
  const BusinessVerificationCard({
    required this.workspace,
    required this.onManage,
    this.expanded = false,
    super.key,
  });

  final TradeSquareBusinessWorkspace workspace;
  final VoidCallback onManage;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final status = workspace.verification.status;
    final meta = _verificationMeta(status);

    return BusinessSectionCard(
      title: 'Business verification',
      subtitle: meta.detail,
      trailing: TextButton(
        onPressed: onManage,
        child: Text(expanded ? 'Refresh' : 'Manage'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(meta.icon, size: 16, color: meta.color),
                const SizedBox(width: 6),
                Text(
                  meta.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: meta.color,
                  ),
                ),
              ],
            ),
          ),
          if (workspace.verification.reviewMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              workspace.verification.reviewMessage,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
            ),
          ],
          if (expanded) ...[
            const SizedBox(height: 14),
            const Text(
              'Documents stay private and are only used for verification review. '
              'An approved badge appears only after TradeSquare confirms approval.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Registration no.',
              value: workspace.business.registrationNumber.isEmpty
                  ? 'Required'
                  : workspace.business.registrationNumber,
            ),
            _DetailRow(
              label: 'Certificate type',
              value: workspace.business.registrationCertificateType.isEmpty
                  ? 'Required'
                  : workspace.business.registrationCertificateType,
            ),
            _DetailRow(
              label: 'Last updated',
              value: _formatDate(workspace.verification.lastUpdated),
            ),
          ],
        ],
      ),
    );
  }
}

class BusinessAiAssistCard extends StatelessWidget {
  const BusinessAiAssistCard({
    required this.suggestions,
    required this.onApply,
    super.key,
  });

  final List<TradeSquareBusinessAiSuggestion> suggestions;
  final ValueChanged<TradeSquareBusinessAiSuggestion> onApply;

  @override
  Widget build(BuildContext context) {
    return BusinessSectionCard(
      title: 'TradeSquare Business AI',
      subtitle:
          'Optional drafts to improve copy. Review and edit before publishing. Live AI is not connected yet.',
      child: suggestions.isEmpty
          ? const _EmptyHint(
              icon: Icons.auto_awesome_outlined,
              message: 'No suggestions available for this profile yet.',
            )
          : Column(
              children: [
                for (final suggestion in suggestions) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                suggestion.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            Text(
                              suggestion.contextLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          suggestion.draft,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => onApply(suggestion),
                            child: const Text('Review draft'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (suggestion != suggestions.last) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final TradeSquareMockProductListing product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: DiscoverNetworkImage(
              url: product.productImage,
              fallbackIcon: Icons.inventory_2_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ),
                Text(
                  product.category,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniTag(
                      label:
                          '${product.indicativePrice.toStringAsFixed(0)} ${product.currency}',
                    ),
                    _MiniTag(label: 'MOQ ${product.minimumOrderQuantity}'),
                    _MiniTag(label: product.listingStatus),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.item,
    required this.onEdit,
    required this.onTogglePause,
    required this.onDelete,
    required this.onView,
  });

  final TradeSquareBusinessOpportunityItem item;
  final VoidCallback onEdit;
  final VoidCallback onTogglePause;
  final VoidCallback onDelete;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final kindLabel = switch (item.kind) {
      TradeSquareBusinessOpportunityKind.buyingRequest => 'Buying request',
      TradeSquareBusinessOpportunityKind.supplierOffer => 'Supplier offer',
      TradeSquareBusinessOpportunityKind.partnership => 'Partnership',
    };

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'view':
                          onView();
                        case 'edit':
                          onEdit();
                        case 'pause':
                          onTogglePause();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'view', child: Text('View')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'pause',
                        child: Text(
                          item.status.toLowerCase() == 'paused'
                              ? 'Reopen'
                              : 'Pause / close',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MiniTag(label: kindLabel),
                  _MiniTag(label: item.status),
                  _MiniTag(label: 'Published ${_formatDate(item.publishedAt)}'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPreviewRow extends StatelessWidget {
  const _ProductPreviewRow({required this.product});

  final TradeSquareMockProductListing product;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 52,
            height: 52,
            child: DiscoverNetworkImage(
              url: product.productImage,
              fallbackIcon: Icons.inventory_2_outlined,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                product.category,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        Text(
          product.listingStatus,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.deepBlue,
          ),
        ),
      ],
    );
  }
}

class _ImprovementTile extends StatelessWidget {
  const _ImprovementTile({required this.item, required this.onTap});

  final TradeSquareBusinessImprovement item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.tips_and_updates_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.detail,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              item.actionLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.deepBlue,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondaryText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerificationMeta {
  const _VerificationMeta({
    required this.label,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String label;
  final String detail;
  final Color color;
  final IconData icon;
}

_VerificationMeta _verificationMeta(TradeSquareMockVerificationState status) {
  return switch (status) {
    TradeSquareMockVerificationState.approved => const _VerificationMeta(
        label: 'Approved',
        detail: 'Your business is verified on TradeSquare.',
        color: Color(0xFF0F7B3A),
        icon: Icons.verified_rounded,
      ),
    TradeSquareMockVerificationState.underReview ||
    TradeSquareMockVerificationState.submitted =>
      const _VerificationMeta(
        label: 'Under review',
        detail: 'Documents are being reviewed. This can take a few business days.',
        color: Color(0xFFB7791F),
        icon: Icons.hourglass_top_rounded,
      ),
    TradeSquareMockVerificationState.additionalInformationRequired =>
      const _VerificationMeta(
        label: 'More information needed',
        detail: 'Provide the requested details to continue verification.',
        color: Color(0xFFC05621),
        icon: Icons.info_outline_rounded,
      ),
    TradeSquareMockVerificationState.rejected => const _VerificationMeta(
        label: 'Rejected',
        detail: 'Verification was not approved. Review feedback and resubmit.',
        color: Color(0xFFC53030),
        icon: Icons.cancel_outlined,
      ),
    TradeSquareMockVerificationState.notSubmitted => const _VerificationMeta(
        label: 'Not submitted',
        detail: 'Submit registration documents to start verification.',
        color: AppColors.secondaryText,
        icon: Icons.shield_outlined,
      ),
  };
}

String _formatDate(DateTime value) {
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

/// Shared helpers for product / opportunity editors used by the page.
Future<TradeSquareMockProductListing?> showBusinessProductEditor({
  required BuildContext context,
  required String businessId,
  TradeSquareMockProductListing? existing,
}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final description = TextEditingController(text: existing?.description ?? '');
  final category = TextEditingController(text: existing?.category ?? '');
  final quantity =
      TextEditingController(text: '${existing?.availableQuantity ?? 100}');
  final moq =
      TextEditingController(text: '${existing?.minimumOrderQuantity ?? 10}');
  final price =
      TextEditingController(text: '${existing?.indicativePrice ?? 0}');
  final markets = TextEditingController(
    text: existing?.deliveryLocations.join(', ') ?? '',
  );
  final imageUrl = TextEditingController(text: existing?.productImage ?? '');

  final result = await showModalBottomSheet<TradeSquareMockProductListing>(
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
              Text(
                existing == null ? 'Add product' : 'Edit product',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _Field(controller: name, label: 'Name'),
              _Field(controller: description, label: 'Description', maxLines: 3),
              _Field(controller: category, label: 'Category'),
              _Field(
                controller: quantity,
                label: 'Available quantity / capacity',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              _Field(
                controller: moq,
                label: 'Minimum order quantity',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              _Field(
                controller: price,
                label: 'Indicative price',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              _Field(
                controller: markets,
                label: 'Markets / delivery locations (comma separated)',
              ),
              _Field(
                controller: imageUrl,
                label: 'Image URL (optional)',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (name.text.trim().isEmpty) return;
                    Navigator.of(context).pop(
                      TradeSquareMockProductListing(
                        id: existing?.id ??
                            'prod_local_${DateTime.now().millisecondsSinceEpoch}',
                        businessId: businessId,
                        name: name.text.trim(),
                        productImage: imageUrl.text.trim().isEmpty
                            ? (existing?.productImage ?? '')
                            : imageUrl.text.trim(),
                        description: description.text.trim(),
                        category: category.text.trim().isEmpty
                            ? 'General'
                            : category.text.trim(),
                        industry: existing?.industry ?? 'General',
                        condition: existing?.condition ?? 'New',
                        unit: existing?.unit ?? 'unit',
                        availableQuantity: int.tryParse(quantity.text) ?? 0,
                        minimumOrderQuantity: int.tryParse(moq.text) ?? 0,
                        indicativePrice:
                            double.tryParse(price.text) ?? 0,
                        currency: existing?.currency ?? 'USD',
                        countryOfOrigin: existing?.countryOfOrigin ?? '',
                        deliveryLocations: markets.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                        availabilityStatus:
                            existing?.availabilityStatus ?? 'In stock',
                        listingStatus: existing?.listingStatus ?? 'Active',
                        publishedAt: existing?.publishedAt ?? DateTime.now().toUtc(),
                        views: existing?.views ?? 0,
                        savedCount: existing?.savedCount ?? 0,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(existing == null ? 'Add listing' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  name.dispose();
  description.dispose();
  category.dispose();
  quantity.dispose();
  moq.dispose();
  price.dispose();
  markets.dispose();
  imageUrl.dispose();
  return result;
}

Future<TradeSquareBusinessOpportunityItem?> showBusinessOpportunityEditor({
  required BuildContext context,
  TradeSquareBusinessOpportunityItem? existing,
}) async {
  final title = TextEditingController(text: existing?.title ?? '');
  final summary = TextEditingController(text: existing?.summary ?? '');
  var kind = existing?.kind ?? TradeSquareBusinessOpportunityKind.buyingRequest;

  final result =
      await showModalBottomSheet<TradeSquareBusinessOpportunityItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
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
                  Text(
                    existing == null ? 'Create opportunity' : 'Edit opportunity',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<TradeSquareBusinessOpportunityKind>(
                    value: kind,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TradeSquareBusinessOpportunityKind.buyingRequest,
                        child: Text('Buying request'),
                      ),
                      DropdownMenuItem(
                        value: TradeSquareBusinessOpportunityKind.supplierOffer,
                        child: Text('Supplier offer'),
                      ),
                      DropdownMenuItem(
                        value: TradeSquareBusinessOpportunityKind.partnership,
                        child: Text('Partnership'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => kind = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(controller: title, label: 'Title'),
                  _Field(controller: summary, label: 'Summary', maxLines: 4),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (title.text.trim().isEmpty) return;
                        Navigator.of(context).pop(
                          TradeSquareBusinessOpportunityItem(
                            id: existing?.id ??
                                'opp_local_${DateTime.now().millisecondsSinceEpoch}',
                            title: title.text.trim(),
                            kind: kind,
                            status: existing?.status ?? 'Open',
                            publishedAt:
                                existing?.publishedAt ?? DateTime.now().toUtc(),
                            summary: summary.text.trim(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(existing == null ? 'Publish' : 'Save changes'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  title.dispose();
  summary.dispose();
  return result;
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
