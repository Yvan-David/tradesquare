import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/generated/app_localizations.dart';
import '../../app/theme/app_colors.dart';
import '../navigation/trade_square_destination.dart';
import 'trade_square_footer.dart';
import 'trade_square_sidebar.dart';
import 'trade_square_top_bar.dart';

class TradeSquareNavigationShell extends StatefulWidget {
  const TradeSquareNavigationShell({
    required this.body,
    required this.currentLocation,
    required this.routes,
    required this.onNavigate,
    required this.locale,
    required this.onLocaleChanged,
    this.items,
    this.account,
    this.onSignOut,
    this.appBarActions,
    this.onSearchSubmitted,
    this.onImageSearch,
    this.onVoiceSearch,
    this.createRoutes = const {},
    this.notifications = const [],
    this.notificationState = TradeSquareNotificationState.loaded,
    this.unreadNotificationCount = 0,
    this.onMarkNotificationRead,
    this.onRetryNotifications,
    this.onCreatePressed,
    this.router,
    super.key,
  });

  TradeSquareNavigationShell.withGoRouter({
    required this.router,
    required this.body,
    required this.routes,
    required this.locale,
    required this.onLocaleChanged,
    this.items,
    this.account,
    this.onSignOut,
    this.appBarActions,
    this.onSearchSubmitted,
    this.onImageSearch,
    this.onVoiceSearch,
    this.createRoutes = const {},
    this.notifications = const [],
    this.notificationState = TradeSquareNotificationState.loaded,
    this.unreadNotificationCount = 0,
    this.onMarkNotificationRead,
    this.onRetryNotifications,
    this.onCreatePressed,
    super.key,
  })  : currentLocation = '',
        onNavigate = router!.go;

  final Widget body;
  final String currentLocation;
  final Map<TradeSquareDestination, String> routes;
  final ValueChanged<String> onNavigate;
  final GoRouter? router;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final List<TradeSquareNavigationItem>? items;
  final TradeSquareAccount? account;
  final Future<void> Function()? onSignOut;
  final List<Widget>? appBarActions;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onImageSearch;
  final VoidCallback? onVoiceSearch;
  final Map<TradeSquareCreateAction, String> createRoutes;
  final List<TradeSquareNotification> notifications;
  final TradeSquareNotificationState notificationState;
  final int unreadNotificationCount;
  final ValueChanged<TradeSquareNotification>? onMarkNotificationRead;
  final VoidCallback? onRetryNotifications;
  final VoidCallback? onCreatePressed;

  @override
  State<TradeSquareNavigationShell> createState() =>
      _TradeSquareNavigationShellState();
}

class _TradeSquareNavigationShellState
    extends State<TradeSquareNavigationShell>
    with SingleTickerProviderStateMixin {
  /// Sidebar starts fully collapsed/hidden on every screen size.
  bool _sidebarOpen = false;

  static const double _sidebarWidth = 272;

  late final AnimationController _sidebarController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  late final Animation<double> _sidebarAnimation = CurvedAnimation(
    parent: _sidebarController,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  void _setSidebarOpen(bool open) {
    if (_sidebarOpen == open) return;
    setState(() => _sidebarOpen = open);
    if (open) {
      _sidebarController.forward();
    } else {
      _sidebarController.reverse();
    }
  }

  void _toggleSidebar() => _setSidebarOpen(!_sidebarOpen);

  @override
  Widget build(BuildContext context) {
    final router = widget.router;
    if (router != null) {
      return AnimatedBuilder(
        animation: router.routeInformationProvider,
        builder: (context, _) => _buildShell(
          context,
          router.routeInformationProvider.value.uri.path,
        ),
      );
    }

    return _buildShell(context, widget.currentLocation);
  }

  Widget _buildShell(BuildContext context, String currentLocation) {
    final navigationItems =
        widget.items ?? TradeSquareNavigationItem.primary();
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 768;
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        if (reduceMotion) {
          _sidebarController.value = _sidebarOpen ? 1 : 0;
        }

        final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
        final showMobileNav = mobile && !keyboardVisible;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: TradeSquareTopBar(
              locale: widget.locale,
              onLocaleChanged: widget.onLocaleChanged,
              menuOpen: _sidebarOpen,
              onMenuPressed: _toggleSidebar,
              onNavigate: widget.onNavigate,
              account: widget.account,
              routes: widget.routes,
              createRoutes: widget.createRoutes,
              onSearchSubmitted: widget.onSearchSubmitted,
              onImageSearch: widget.onImageSearch,
              onVoiceSearch: widget.onVoiceSearch,
              notifications: widget.notifications,
              notificationState: widget.notificationState,
              unreadNotificationCount: widget.unreadNotificationCount,
              onMarkNotificationRead: widget.onMarkNotificationRead,
              onRetryNotifications: widget.onRetryNotifications,
              onSignOut: widget.onSignOut,
              appBarActions: widget.appBarActions ?? const [],
            ),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // Reserved animated width so content never jumps under an overlay.
                        if (!mobile)
                          AnimatedBuilder(
                            animation: _sidebarAnimation,
                            builder: (context, _) {
                              return SizedBox(
                                width: _sidebarWidth * _sidebarAnimation.value,
                              );
                            },
                          ),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: widget.body),
                              const TradeSquareFooter(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!mobile)
                AnimatedBuilder(
                  animation: _sidebarAnimation,
                  builder: (context, child) {
                    final t = _sidebarAnimation.value;
                    if (t == 0) return const SizedBox.shrink();
                    // Clip the reveal while keeping the panel at full width so
                    // labels/icons never reflow mid-animation.
                    return ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: t,
                        child: SizedBox(
                          width: _sidebarWidth,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: TradeSquareSidebar(
                    currentLocation: currentLocation,
                    routes: widget.routes,
                    onNavigate: widget.onNavigate,
                    onClose: () => _setSidebarOpen(false),
                    items: navigationItems,
                    account: widget.account,
                    onNavigateRequested: () => _setSidebarOpen(false),
                    width: _sidebarWidth,
                  ),
                )
              else ...[
                AnimatedBuilder(
                  animation: _sidebarAnimation,
                  builder: (context, _) {
                    final t = _sidebarAnimation.value;
                    if (t == 0) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: GestureDetector(
                        onTap: () => _setSidebarOpen(false),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.28 * t),
                        ),
                      ),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _sidebarAnimation,
                  builder: (context, child) {
                    final t = _sidebarAnimation.value;
                    if (t == 0) return const SizedBox.shrink();
                    final panelWidth = constraints.maxWidth < 320
                        ? constraints.maxWidth - 24
                        : constraints.maxWidth < 464
                            ? constraints.maxWidth * 0.86
                            : 320.0;
                    return Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: panelWidth,
                      child: Transform.translate(
                        offset: Offset(-panelWidth * (1 - t), 0),
                        child: child,
                      ),
                    );
                  },
                  child: Material(
                    elevation: 12,
                    color: AppColors.white,
                    child: TradeSquareSidebar(
                      currentLocation: currentLocation,
                      routes: widget.routes,
                      onNavigate: widget.onNavigate,
                      onClose: () => _setSidebarOpen(false),
                      items: navigationItems,
                      account: widget.account,
                      onNavigateRequested: () => _setSidebarOpen(false),
                      width: constraints.maxWidth < 320
                          ? constraints.maxWidth - 24
                          : constraints.maxWidth < 464
                              ? constraints.maxWidth * 0.86
                              : 320,
                    ),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: showMobileNav
              ? _MobileBottomNavigation(
                  currentLocation: currentLocation,
                  routes: widget.routes,
                  onNavigate: widget.onNavigate,
                  items: navigationItems,
                  animationDuration: animationDuration,
                )
              : null,
        );
      },
    );
  }
}

/// Premium three-destination mobile bar: Home · Discover · Messages.
class _MobileBottomNavigation extends StatelessWidget {
  const _MobileBottomNavigation({
    required this.currentLocation,
    required this.routes,
    required this.onNavigate,
    required this.items,
    required this.animationDuration,
  });

  final String currentLocation;
  final Map<TradeSquareDestination, String> routes;
  final ValueChanged<String> onNavigate;
  final List<TradeSquareNavigationItem> items;
  final Duration animationDuration;

  static const double _barHeight = 64;
  static const double _centerSize = 54;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final itemByDestination = {
      for (final item in items) item.destination: item,
    };
    final messagesItem = itemByDestination[TradeSquareDestination.messages];
    final homeRoute = routes[TradeSquareDestination.overview];
    final discoverRoute = routes[TradeSquareDestination.discover];
    final messagesRoute = routes[TradeSquareDestination.messages];
    final discoverActive = _isActive(discoverRoute, currentLocation);

    return Material(
      color: AppColors.white,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepBlue.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: SizedBox(
            height: _barHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: _MobileSideNavItem(
                      label: 'Home',
                      semanticsLabel: itemByDestination[
                                  TradeSquareDestination.overview]
                              ?.label(localizations) ??
                          'Home',
                      activeIcon: Icons.home_rounded,
                      idleIcon: Icons.home_outlined,
                      active: _isActive(homeRoute, currentLocation),
                      enabled: homeRoute != null,
                      animationDuration: animationDuration,
                      onTap: homeRoute == null
                          ? null
                          : () => onNavigate(homeRoute),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Center(
                      child: _MobileDiscoverFab(
                        key: const ValueKey('mobile-discover-nav'),
                        active: discoverActive,
                        enabled: discoverRoute != null,
                        label: localizations.navDiscover,
                        animationDuration: animationDuration,
                        size: _centerSize,
                        onTap: discoverRoute == null
                            ? null
                            : () => onNavigate(discoverRoute),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MobileSideNavItem(
                      label: localizations.navMessages,
                      semanticsLabel: messagesItem?.label(localizations) ??
                          localizations.navMessages,
                      activeIcon: Icons.chat_bubble_rounded,
                      idleIcon: Icons.chat_bubble_outline_rounded,
                      active: _isActive(messagesRoute, currentLocation),
                      enabled: messagesRoute != null,
                      badgeCount: messagesItem?.badgeCount ?? 0,
                      animationDuration: animationDuration,
                      onTap: messagesRoute == null
                          ? null
                          : () => onNavigate(messagesRoute),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileDiscoverFab extends StatefulWidget {
  const _MobileDiscoverFab({
    required this.active,
    required this.enabled,
    required this.label,
    required this.animationDuration,
    required this.size,
    this.onTap,
    super.key,
  });

  final bool active;
  final bool enabled;
  final String label;
  final Duration animationDuration;
  final double size;
  final VoidCallback? onTap;

  @override
  State<_MobileDiscoverFab> createState() => _MobileDiscoverFabState();
}

class _MobileDiscoverFabState extends State<_MobileDiscoverFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : widget.animationDuration;

    return Semantics(
      button: widget.enabled,
      selected: widget.active,
      enabled: widget.enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap?.call();
              }
            : null,
        onTapCancel:
            widget.enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : widget.active ? 1.04 : 1,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.enabled
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.35),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary
                      .withValues(alpha: widget.active ? 0.34 : 0.22),
                  blurRadius: widget.active ? 16 : 12,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: AppColors.white,
                width: 3,
              ),
            ),
            child: Icon(
              Icons.search_rounded,
              color: AppColors.white,
              size: widget.active ? 26 : 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileSideNavItem extends StatelessWidget {
  const _MobileSideNavItem({
    required this.label,
    required this.semanticsLabel,
    required this.activeIcon,
    required this.idleIcon,
    required this.active,
    required this.enabled,
    required this.animationDuration,
    this.badgeCount = 0,
    this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final IconData activeIcon;
  final IconData idleIcon;
  final bool active;
  final bool enabled;
  final Duration animationDuration;
  final int badgeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.secondaryText.withValues(alpha: 0.4)
        : active
            ? AppColors.primary
            : AppColors.secondaryText;

    return Semantics(
      button: enabled,
      selected: active,
      enabled: enabled,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: animationDuration,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        active ? activeIcon : idleIcon,
                        key: ValueKey<bool>(active),
                        size: 24,
                        color: color,
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -10,
                        top: -4,
                        child: _MobileBadge(count: badgeCount),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.1,
                    height: 1,
                  ),
                  child: Text(label),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  width: active ? 14 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(99),
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

class _MobileBadge extends StatelessWidget {
  const _MobileBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onError,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

bool _isActive(String? route, String location) {
  if (route == null || route.isEmpty) return false;
  final normalized = route.length > 1 && route.endsWith('/')
      ? route.substring(0, route.length - 1)
      : route;
  return location == normalized ||
      (normalized != '/' && location.startsWith('$normalized/'));
}
