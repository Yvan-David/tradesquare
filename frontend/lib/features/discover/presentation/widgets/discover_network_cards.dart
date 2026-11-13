import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/mock_data/mock_buying_requests.dart';
import '../../../../core/mock_data/mock_businesses.dart';
import '../../domain/trade_square_discover_models.dart';
import 'discover_icons.dart';
import 'discover_network_image.dart';

class DiscoverSuggestionCard extends StatelessWidget {
  const DiscoverSuggestionCard({
    required this.card,
    required this.onView,
    required this.onMessage,
    super.key,
  });

  final TradeSquareDiscoverBusinessCard card;
  final VoidCallback onView;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final business = card.business;
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: DiscoverNetworkImage(
                    url: business.logoUrl,
                    fallbackIcon: Icons.storefront_outlined,
                  ),
                ),
              ),
              const Spacer(),
              if (card.isVerified)
                const Icon(
                  DiscoverIcons.verified,
                  size: 18,
                  color: AppColors.primary,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            business.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${business.industry} · ${business.city}, ${business.country}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              business.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.text,
              ),
            ),
          ),
          if (card.reasons.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              card.reasons.first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.25,
                color: AppColors.deepBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onView,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('View'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onMessage,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Message'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DiscoverOpportunityCard extends StatelessWidget {
  const DiscoverOpportunityCard({
    required this.request,
    required this.buyer,
    required this.onOpen,
    required this.onContact,
    super.key,
  });

  final TradeSquareMockBuyingRequest request;
  final TradeSquareMockBusiness? buyer;
  final VoidCallback onOpen;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lightBlue.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Buying request',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    request.status,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                request.productOrService,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                request.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (buyer != null) buyer!.name,
                  request.deliveryDestination,
                  request.preferredSupplierLocation,
                ].where((part) => part.trim().isNotEmpty).join(' · '),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onOpen,
                      child: const Text('View details'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onContact,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('Contact'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoverFilterChip extends StatelessWidget {
  const DiscoverFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? AppColors.deepBlue : AppColors.secondaryText,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      backgroundColor: AppColors.white,
    );
  }
}

class DiscoverSectionHeader extends StatelessWidget {
  const DiscoverSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.text,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
