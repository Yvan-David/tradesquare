import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/mock_data/mock_businesses.dart';
import '../../../discover/presentation/widgets/discover_network_image.dart';

class BusinessProfileHeader extends StatelessWidget {
  const BusinessProfileHeader({
    required this.business,
    required this.coverImageUrl,
    required this.isVerified,
    required this.onEdit,
    required this.onPreview,
    super.key,
  });

  final TradeSquareMockBusiness business;
  final String coverImageUrl;
  final bool isVerified;
  final VoidCallback onEdit;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 768;
    final coverHeight = compact ? 140.0 : 180.0;
    final avatarSize = compact ? 84.0 : 108.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: coverHeight,
              width: double.infinity,
              child: DiscoverNetworkImage(
                url: coverImageUrl,
                fallbackIcon: Icons.apartment_outlined,
              ),
            ),
            Positioned(
              left: compact ? 16 : 20,
              bottom: -(avatarSize / 2.2),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepBlue.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: DiscoverNetworkImage(
                    url: business.logoUrl,
                    fallbackIcon: Icons.storefront_outlined,
                  ),
                ),
              ),
            ),
            Positioned(
              right: compact ? 12 : 16,
              bottom: 12,
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: onPreview,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      backgroundColor: AppColors.white.withValues(alpha: 0.94),
                      side: const BorderSide(color: AppColors.border),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Preview',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton(
                    onPressed: onEdit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Edit business',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: avatarSize / 2.2 + 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      business.name,
                      style: TextStyle(
                        fontSize: compact ? 24 : 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${business.industry} · ${business.city}, ${business.country}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                business.description,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    icon: Icons.location_on_outlined,
                    label: '${business.city}, ${business.country}',
                  ),
                  if (business.website.isNotEmpty)
                    _MetaChip(
                      icon: Icons.language_rounded,
                      label: business.website
                          .replaceFirst(RegExp(r'^https?://'), ''),
                    ),
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    label: 'Est. ${business.yearEstablished}',
                  ),
                ],
              ),
              if (business.preferredMarkets.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final market in business.preferredMarkets.take(5))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          market,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 22,
                runSpacing: 8,
                children: [
                  _StatText(
                    value: '${business.profileCompleteness}%',
                    label: 'Profile ready',
                  ),
                  _StatText(
                    value: '${business.productsOffered.length}',
                    label: 'Offerings',
                  ),
                  _StatText(
                    value: '${business.preferredMarkets.length}',
                    label: 'Markets',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.secondaryText),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatText extends StatelessWidget {
  const _StatText({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: AppColors.text,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
