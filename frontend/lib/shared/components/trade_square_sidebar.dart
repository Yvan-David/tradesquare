import 'package:flutter/material.dart';

import '../../app/localization/generated/app_localizations.dart';
import '../../app/theme/app_colors.dart';
import '../navigation/trade_square_destination.dart';

class TradeSquareSidebar extends StatelessWidget {
  const TradeSquareSidebar({
    required this.currentLocation,
    required this.routes,
    required this.onNavigate,
    required this.onClose,
    this.items,
    this.accountItems,
    this.account,
    this.onNavigateRequested,
    this.width = 272,
    super.key,
  });

  final String currentLocation;
  final Map<TradeSquareDestination, String> routes;
  final ValueChanged<String> onNavigate;
  final VoidCallback onClose;
  final List<TradeSquareNavigationItem>? items;
  final List<TradeSquareNavigationItem>? accountItems;
  final TradeSquareAccount? account;
  final VoidCallback? onNavigateRequested;
  final double width;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final primaryItems = items ?? TradeSquareNavigationItem.primary();
    final footerItems =
        accountItems ?? TradeSquareNavigationItem.accountActions();

    return Material(
      color: AppColors.white,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(
              right: BorderSide(color: AppColors.border),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: localizations.navCloseMenu,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.secondaryText,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    children: [
                      for (final item in primaryItems)
                        _SidebarNavTile(
                          item: item,
                          active: _isActive(
                            routes[item.destination],
                            currentLocation,
                          ),
                          available: routes.containsKey(item.destination),
                          onTap: () => _handleTap(item),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    children: [
                      for (final item in footerItems)
                        _SidebarNavTile(
                          item: item,
                          active: _isActive(
                            routes[item.destination],
                            currentLocation,
                          ),
                          available: routes.containsKey(item.destination),
                          onTap: () => _handleTap(item),
                          compact: true,
                        ),
                    ],
                  ),
                ),
                if (account != null)
                  _SidebarAccountCard(account: account!)
                else
                  const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(TradeSquareNavigationItem item) {
    final route = routes[item.destination];
    if (route == null) return;
    onNavigateRequested?.call();
    onNavigate(route);
  }

  bool _isActive(String? route, String location) {
    if (route == null || route.isEmpty) return false;
    final normalized = route.length > 1 && route.endsWith('/')
        ? route.substring(0, route.length - 1)
        : route;
    return location == normalized ||
        (normalized != '/' && location.startsWith('$normalized/'));
  }
}

class _SidebarNavTile extends StatefulWidget {
  const _SidebarNavTile({
    required this.item,
    required this.active,
    required this.available,
    required this.onTap,
    this.compact = false,
  });

  final TradeSquareNavigationItem item;
  final bool active;
  final bool available;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final label = widget.item.label(localizations);
    final semanticsLabel = widget.available
        ? label
        : localizations.navDestinationUnavailable(label);
    final foreground = !widget.available
        ? AppColors.secondaryText.withValues(alpha: 0.45)
        : widget.active
            ? AppColors.primary
            : AppColors.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        button: widget.available,
        enabled: widget.available,
        selected: widget.active,
        label: semanticsLabel,
        excludeSemantics: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.available ? widget.onTap : null,
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                height: widget.compact ? 44 : 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: widget.active
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : _hovered && widget.available
                          ? AppColors.background
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.item.icon,
                      size: 22,
                      color: foreground,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.compact ? 14.5 : 15.5,
                          height: 1.2,
                          letterSpacing: -0.2,
                          fontWeight:
                              widget.active ? FontWeight.w700 : FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                    if (widget.item.badgeCount > 0)
                      Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.item.badgeCount > 99
                              ? '99+'
                              : '${widget.item.badgeCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarAccountCard extends StatelessWidget {
  const _SidebarAccountCard({required this.account});

  final TradeSquareAccount account;

  @override
  Widget build(BuildContext context) {
    final initials = account.initials ??
        account.name
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              backgroundImage: account.imageProvider,
              child: account.imageProvider == null
                  ? Text(
                      initials.isEmpty ? 'TS' : initials,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (account.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
