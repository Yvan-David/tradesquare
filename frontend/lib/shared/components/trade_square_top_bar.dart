import 'package:flutter/material.dart';

import '../../app/localization/generated/app_localizations.dart';
import '../../app/theme/app_colors.dart';
import '../branding/trade_square_logo.dart';
import '../navigation/trade_square_destination.dart';
import 'trade_square_menu_button.dart';

enum TradeSquareCreateAction {
  productListing,
  buyingRequest,
}

@immutable
class TradeSquareNotification {
  const TradeSquareNotification({
    required this.title,
    required this.description,
    required this.timeLabel,
    this.destination,
    this.isRead = false,
  });

  final String title;
  final String description;
  final String timeLabel;
  final String? destination;
  final bool isRead;
}

enum TradeSquareNotificationState { loading, loaded, error }

class TradeSquareTopBar extends StatefulWidget implements PreferredSizeWidget {
  const TradeSquareTopBar({
    required this.locale,
    required this.onLocaleChanged,
    required this.onMenuPressed,
    required this.onNavigate,
    this.menuOpen = false,
    this.account,
    this.routes = const {},
    this.createRoutes = const {},
    this.onSearchSubmitted,
    this.onImageSearch,
    this.onVoiceSearch,
    this.notifications = const [],
    this.notificationState = TradeSquareNotificationState.loaded,
    this.unreadNotificationCount = 0,
    this.onMarkNotificationRead,
    this.onRetryNotifications,
    this.onSignOut,
    this.appBarActions = const [],
    super.key,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onMenuPressed;
  final bool menuOpen;
  final ValueChanged<String> onNavigate;
  final TradeSquareAccount? account;
  final Map<TradeSquareDestination, String> routes;
  final Map<TradeSquareCreateAction, String> createRoutes;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onImageSearch;
  final VoidCallback? onVoiceSearch;
  final List<TradeSquareNotification> notifications;
  final TradeSquareNotificationState notificationState;
  final int unreadNotificationCount;
  final ValueChanged<TradeSquareNotification>? onMarkNotificationRead;
  final VoidCallback? onRetryNotifications;
  final Future<void> Function()? onSignOut;
  final List<Widget> appBarActions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<TradeSquareTopBar> createState() => _TradeSquareTopBarState();
}

class _TradeSquareTopBarState extends State<TradeSquareTopBar> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 768;
    final tablet = width >= 768 && width < 1024;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 16),
          child: Row(
            children: [
              TradeSquareMenuButton(
                isOpen: widget.menuOpen,
                onPressed: widget.onMenuPressed,
                tooltip: widget.menuOpen
                    ? localizations.navCloseMenu
                    : localizations.navOpenMenu,
              ),
              const SizedBox(width: 4),
              _BrandSection(
                compact: mobile,
                title: localizations.appTitle,
              ),
              SizedBox(width: mobile ? 4 : 16),
              if (!mobile)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _GlobalSearchBar(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onSubmitted: widget.onSearchSubmitted,
                        duration: duration,
                        onImageSearch: widget.onImageSearch,
                        onVoiceSearch: widget.onVoiceSearch,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _TopBarIconButton(
                      tooltip: localizations.topBarSearch,
                      icon: Icons.search_rounded,
                      onPressed: () => _openMobileSearch(context),
                    ),
                  ),
                ),
              if (!mobile) const SizedBox(width: 8),
              _CreateActionButton(
                compact: mobile || tablet,
                routes: widget.createRoutes,
                onNavigate: widget.onNavigate,
              ),
              if (widget.routes.containsKey(TradeSquareDestination.messages))
                _TopBarIconButton(
                  tooltip: localizations.navMessages,
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () => widget.onNavigate(
                    widget.routes[TradeSquareDestination.messages]!,
                  ),
                ),
              _NotificationButton(
                notifications: widget.notifications,
                state: widget.notificationState,
                unreadCount: widget.unreadNotificationCount,
                onMarkRead: widget.onMarkNotificationRead,
                onRetry: widget.onRetryNotifications,
                onNavigate: widget.onNavigate,
              ),
              if (widget.account != null)
                _ProfileMenu(
                  account: widget.account!,
                  locale: widget.locale,
                  onLocaleChanged: widget.onLocaleChanged,
                  routes: widget.routes,
                  onNavigate: widget.onNavigate,
                  onSignOut: widget.onSignOut,
                  compact: mobile,
                ),
              ...widget.appBarActions,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMobileSearch(BuildContext context) async {
    final query = await showDialog<String>(
      context: context,
      builder: (context) => _MobileSearchDialog(
        initialQuery: _searchController.text,
        onImageSearch: widget.onImageSearch,
        onVoiceSearch: widget.onVoiceSearch,
      ),
    );
    if (query != null && query.trim().isNotEmpty) {
      _searchController.text = query;
      widget.onSearchSubmitted?.call(query.trim());
    }
  }
}

class _BrandSection extends StatelessWidget {
  const _BrandSection({required this.compact, required this.title});

  final bool compact;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TradeSquareLogo(size: 36, borderRadius: 10),
        if (!compact) ...[
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _GlobalSearchBar extends StatefulWidget {
  const _GlobalSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.duration,
    required this.onImageSearch,
    required this.onVoiceSearch,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onSubmitted;
  final Duration duration;
  final VoidCallback? onImageSearch;
  final VoidCallback? onVoiceSearch;

  @override
  State<_GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends State<_GlobalSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _GlobalSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return AnimatedContainer(
      duration: widget.duration,
      height: 42,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerHighest
            : const Color(0xFFF3F6F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.focusNode.hasFocus
              ? theme.colorScheme.primary.withValues(alpha: 0.6)
              : theme.brightness == Brightness.dark
                  ? theme.colorScheme.outlineVariant
                  : AppColors.border,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSubmitted,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: localizations.topBarSearchHint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: widget.onImageSearch == null &&
                  widget.onVoiceSearch == null
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onImageSearch != null)
                      IconButton(
                        constraints: const BoxConstraints.tightFor(
                            width: 36, height: 36),
                        padding: EdgeInsets.zero,
                        tooltip: localizations.topBarImageSearch,
                        onPressed: widget.onImageSearch,
                        icon: const Icon(Icons.image_search_outlined, size: 19),
                      ),
                    if (widget.onVoiceSearch != null)
                      IconButton(
                        constraints: const BoxConstraints.tightFor(
                            width: 36, height: 36),
                        padding: EdgeInsets.zero,
                        tooltip: localizations.topBarVoiceSearch,
                        onPressed: widget.onVoiceSearch,
                        icon:
                            const Icon(Icons.keyboard_voice_outlined, size: 19),
                      ),
                  ],
                ),
          suffixIconConstraints: const BoxConstraints(minHeight: 40),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          isDense: true,
        ),
      ),
    );
  }
}

class _MobileSearchDialog extends StatefulWidget {
  const _MobileSearchDialog({
    required this.initialQuery,
    required this.onImageSearch,
    required this.onVoiceSearch,
  });

  final String initialQuery;
  final VoidCallback? onImageSearch;
  final VoidCallback? onVoiceSearch;

  @override
  State<_MobileSearchDialog> createState() => _MobileSearchDialogState();
}

class _MobileSearchDialogState extends State<_MobileSearchDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          autofocus: true,
          controller: _controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: localizations.topBarSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onImageSearch != null)
                  IconButton(
                    tooltip: localizations.topBarImageSearch,
                    onPressed: widget.onImageSearch,
                    icon: const Icon(Icons.image_search_outlined, size: 19),
                  ),
                if (widget.onVoiceSearch != null)
                  IconButton(
                    tooltip: localizations.topBarVoiceSearch,
                    onPressed: widget.onVoiceSearch,
                    icon: const Icon(Icons.keyboard_voice_outlined, size: 19),
                  ),
                IconButton(
                  tooltip: localizations.topBarCloseSearch,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          onSubmitted: (query) => Navigator.of(context).pop(query),
        ),
      ),
    );
  }
}

class _CreateActionButton extends StatelessWidget {
  const _CreateActionButton({
    required this.compact,
    required this.routes,
    required this.onNavigate,
  });

  final bool compact;
  final Map<TradeSquareCreateAction, String> routes;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopupMenuButton<TradeSquareCreateAction>(
      tooltip: routes.isEmpty
          ? localizations.topBarCreateUnavailable
          : localizations.topBarCreate,
      enabled: routes.isNotEmpty,
      onSelected: (action) {
        final route = routes[action];
        if (route != null) onNavigate(route);
      },
      itemBuilder: (context) => [
        if (routes.containsKey(TradeSquareCreateAction.productListing))
          PopupMenuItem(
            value: TradeSquareCreateAction.productListing,
            child: Text(localizations.topBarAddProduct),
          ),
        if (routes.containsKey(TradeSquareCreateAction.buyingRequest))
          PopupMenuItem(
            value: TradeSquareCreateAction.buyingRequest,
            child: Text(localizations.topBarNewBuyingRequest),
          ),
      ],
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13),
        decoration: BoxDecoration(
          color: routes.isEmpty
              ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
              : theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              size: 19,
              color: routes.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onPrimary,
            ),
            if (!compact) ...[
              const SizedBox(width: 5),
              Text(
                localizations.topBarCreate,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: routes.isEmpty
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.notifications,
    required this.state,
    required this.unreadCount,
    required this.onMarkRead,
    required this.onRetry,
    required this.onNavigate,
  });

  final List<TradeSquareNotification> notifications;
  final TradeSquareNotificationState state;
  final int unreadCount;
  final ValueChanged<TradeSquareNotification>? onMarkRead;
  final VoidCallback? onRetry;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return _TopBarIconButton(
      tooltip: unreadCount > 0
          ? localizations.topBarUnreadNotifications(unreadCount)
          : localizations.topBarNotifications,
      icon: Icons.notifications_none_outlined,
      badgeCount: unreadCount,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => _NotificationDialog(
          notifications: notifications,
          state: state,
          onMarkRead: onMarkRead,
          onRetry: onRetry,
          onNavigate: onNavigate,
        ),
      ),
    );
  }
}

class _NotificationDialog extends StatelessWidget {
  const _NotificationDialog({
    required this.notifications,
    required this.state,
    required this.onMarkRead,
    required this.onRetry,
    required this.onNavigate,
  });

  final List<TradeSquareNotification> notifications;
  final TradeSquareNotificationState state;
  final ValueChanged<TradeSquareNotification>? onMarkRead;
  final VoidCallback? onRetry;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final content = switch (state) {
      TradeSquareNotificationState.loading => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Semantics(
              label: localizations.topBarNotificationsLoading,
              child: const CircularProgressIndicator(),
            ),
          ),
        ),
      TradeSquareNotificationState.error => _NotificationMessage(
          message: localizations.topBarNotificationsError,
          actionLabel: onRetry == null ? null : localizations.topBarRetry,
          onAction: onRetry,
        ),
      TradeSquareNotificationState.loaded when notifications.isEmpty =>
        _NotificationMessage(
          message: localizations.topBarNoNotifications,
        ),
      TradeSquareNotificationState.loaded => SizedBox(
          width:
              (MediaQuery.sizeOf(context).width - 48).clamp(0, 390).toDouble(),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: notifications.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.timeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                trailing: notification.isRead
                    ? null
                    : Icon(Icons.circle,
                        size: 8, color: theme.colorScheme.primary),
                onTap: () {
                  onMarkRead?.call(notification);
                  final route = notification.destination;
                  Navigator.of(context).pop();
                  if (route != null) onNavigate(route);
                },
              );
            },
          ),
        ),
    };

    return Dialog(
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.only(top: 76, right: 16, left: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      localizations.topBarNotifications,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: localizations.topBarCloseNotifications,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Flexible(child: content),
          ],
        ),
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

enum _ProfileAction {
  businessProfile,
  settings,
  helpSupport,
  english,
  kinyarwanda,
  kiswahili,
  french,
  signOut,
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.account,
    required this.locale,
    required this.onLocaleChanged,
    required this.routes,
    required this.onNavigate,
    required this.onSignOut,
    required this.compact,
  });

  final TradeSquareAccount account;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final Map<TradeSquareDestination, String> routes;
  final ValueChanged<String> onNavigate;
  final Future<void> Function()? onSignOut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final initials = _accountInitials(account);

    return PopupMenuButton<_ProfileAction>(
      tooltip: '${account.name}, ${account.businessName}',
      onSelected: (action) => _handleAction(context, action, localizations),
      itemBuilder: (context) => [
        PopupMenuItem<_ProfileAction>(
          enabled: false,
          child: SizedBox(
            width: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: theme.textTheme.titleSmall),
                Text(
                  account.businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        if (routes.containsKey(TradeSquareDestination.businessProfile))
          PopupMenuItem(
            value: _ProfileAction.businessProfile,
            child: Text(localizations.topBarBusinessProfile),
          ),
        if (routes.containsKey(TradeSquareDestination.settings))
          PopupMenuItem(
            value: _ProfileAction.settings,
            child: Text(localizations.topBarAccountSettings),
          ),
        PopupMenuItem(
          enabled: false,
          child: Text(
            localizations.topBarLanguage,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _languageItem(const Locale('en'), localizations.languageEnglish),
        _languageItem(const Locale('rw'), localizations.languageKinyarwanda),
        _languageItem(const Locale('sw'), localizations.languageKiswahili),
        _languageItem(const Locale('fr'), localizations.languageFrench),
        if (routes.containsKey(TradeSquareDestination.helpSupport))
          PopupMenuItem(
            value: _ProfileAction.helpSupport,
            child: Text(localizations.topBarHelpSupport),
          ),
        if (onSignOut != null)
          PopupMenuItem(
            value: _ProfileAction.signOut,
            child: Text(
              localizations.topBarSignOut,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
      child: Padding(
        padding: EdgeInsets.only(left: compact ? 2 : 8),
        child: CircleAvatar(
          radius: 17,
          backgroundImage: account.imageProvider,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: account.imageProvider == null
              ? Text(
                  initials,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  PopupMenuItem<_ProfileAction> _languageItem(Locale locale, String label) {
    final action = switch (locale.languageCode) {
      'rw' => _ProfileAction.kinyarwanda,
      'sw' => _ProfileAction.kiswahili,
      'fr' => _ProfileAction.french,
      _ => _ProfileAction.english,
    };
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: this.locale.languageCode == locale.languageCode
                ? const Icon(Icons.check, size: 16)
                : null,
          ),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    _ProfileAction action,
    AppLocalizations localizations,
  ) async {
    final destination = switch (action) {
      _ProfileAction.businessProfile => TradeSquareDestination.businessProfile,
      _ProfileAction.settings => TradeSquareDestination.settings,
      _ProfileAction.helpSupport => TradeSquareDestination.helpSupport,
      _ => null,
    };
    if (destination != null) {
      final route = routes[destination];
      if (route != null) onNavigate(route);
      return;
    }

    final selectedLocale = switch (action) {
      _ProfileAction.english => const Locale('en'),
      _ProfileAction.kinyarwanda => const Locale('rw'),
      _ProfileAction.kiswahili => const Locale('sw'),
      _ProfileAction.french => const Locale('fr'),
      _ => null,
    };
    if (selectedLocale != null) {
      onLocaleChanged(selectedLocale);
      return;
    }

    if (action == _ProfileAction.signOut && onSignOut != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(localizations.topBarSignOut),
          content: Text(localizations.topBarSignOutConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations.topBarCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(localizations.topBarSignOut),
            ),
          ],
        ),
      );
      if (confirmed == true) await onSignOut!();
    }
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 22, color: color),
          if (badgeCount > 0)
            Positioned(
              top: -7,
              right: -9,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _accountInitials(TradeSquareAccount account) {
  if (account.initials?.trim().isNotEmpty ?? false) {
    return account.initials!.trim();
  }
  final words = account.name.trim().split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word.characters.first)
      .join()
      .toUpperCase();
}
