import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/mock_data/mock_businesses.dart';
import '../../domain/trade_square_discover_assistant.dart';
import '../../domain/trade_square_discover_models.dart';
import 'discover_business_card.dart';
import 'discover_network_image.dart';

class DiscoverChatBubble extends StatelessWidget {
  const DiscoverChatBubble({
    required this.message,
    required this.onViewBusiness,
    required this.onContactBusiness,
    required this.onAction,
    super.key,
  });

  final DiscoverChatMessage message;
  final ValueChanged<TradeSquareMockBusiness> onViewBusiness;
  final ValueChanged<TradeSquareMockBusiness> onContactBusiness;
  final ValueChanged<DiscoverAssistantAction> onAction;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == DiscoverChatRole.user;
    final width = MediaQuery.sizeOf(context).width;
    final maxBubble = width < 768 ? width * 0.88 : 560.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubble),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isUser)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(
                    'TradeSquare AI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: isUser ? AppColors.primary : AppColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 18),
                  ),
                  border: isUser
                      ? null
                      : Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: isUser ? AppColors.white : AppColors.text,
                        ),
                      ),
                      if (message.isStreaming) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isUser
                                ? AppColors.white.withValues(alpha: 0.8)
                                : AppColors.primary,
                          ),
                        ),
                      ],
                      if (message.serviceNote != null && !isUser) ...[
                        const SizedBox(height: 10),
                        Text(
                          message.serviceNote!,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: AppColors.secondaryText.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (message.actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in message.actions)
                      OutlinedButton(
                        onPressed: () => onAction(action),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.deepBlue,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(action.label),
                      ),
                  ],
                ),
              ],
              if (message.businesses.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...message.businesses.take(4).map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DiscoverBusinessCard(
                          card: card,
                          compact: true,
                          onView: () => onViewBusiness(card.business),
                          onContact: () => onContactBusiness(card.business),
                        ),
                      ),
                    ),
              ],
              if (message.products.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...message.products.take(3).map(
                      (card) => _InlineProductRow(
                        card: card,
                        onOpen: () => onViewBusiness(card.business),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineProductRow extends StatelessWidget {
  const _InlineProductRow({required this.card, required this.onOpen});

  final TradeSquareDiscoverProductCard card;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: DiscoverNetworkImage(
                      url: card.product.productImage,
                      fallbackIcon: Icons.inventory_2_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        card.business.name,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      if (card.reasons.isNotEmpty)
                        Text(
                          card.reasons.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.deepBlue,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
