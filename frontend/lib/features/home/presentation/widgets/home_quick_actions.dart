import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

enum TradeSquareHomeQuickAction { findBuyers, findSuppliers, findPartners }

class TradeSquareHomeQuickActions extends StatelessWidget {
  const TradeSquareHomeQuickActions({
    this.onAction,
    super.key,
  });

  final ValueChanged<TradeSquareHomeQuickAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
        action: TradeSquareHomeQuickAction.findBuyers,
        icon: Icons.storefront_outlined,
        title: 'Find Buyers',
        subtitle: 'Demand for your products',
      ),
      _ActionData(
        action: TradeSquareHomeQuickAction.findSuppliers,
        icon: Icons.local_shipping_outlined,
        title: 'Find Suppliers',
        subtitle: 'Trusted supply partners',
      ),
      _ActionData(
        action: TradeSquareHomeQuickAction.findPartners,
        icon: Icons.handshake_outlined,
        title: 'Find Partners',
        subtitle: 'Grow together regionally',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Start with the relationship you need most right now.',
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _QuickActionCard(
                data: actions[index],
                onTap: () => onAction?.call(actions[index].action),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionData {
  const _ActionData({
    required this.action,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final TradeSquareHomeQuickAction action;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _QuickActionCard extends StatefulWidget {
  const _QuickActionCard({
    required this.data,
    required this.onTap,
  });

  final _ActionData data;
  final VoidCallback onTap;

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 110),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: 188,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepBlue.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.data.icon, color: AppColors.primary, size: 20),
                ),
                const Spacer(),
                Text(
                  widget.data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
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
