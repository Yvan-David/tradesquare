import 'package:flutter/material.dart';

import '../../app/localization/generated/app_localizations.dart';

enum TradeSquareDestination {
  overview,
  discover,
  products,
  buyingRequests,
  connections,
  messages,
  aiAssistant,
  marketIntelligence,
  notifications,
  businessProfile,
  settings,
  helpSupport,
}

enum TradeSquareNavigationSection { workspace, intelligence, account }

@immutable
class TradeSquareNavigationItem {
  const TradeSquareNavigationItem({
    required this.destination,
    required this.section,
    required this.icon,
    this.mobileIcon,
    this.badgeCount = 0,
    this.labelOverride,
  });

  final TradeSquareDestination destination;
  final TradeSquareNavigationSection section;
  final IconData icon;
  final IconData? mobileIcon;
  final int badgeCount;
  final String? labelOverride;

  String label(AppLocalizations localizations) {
    if (labelOverride != null) return labelOverride!;
    return switch (destination) {
      TradeSquareDestination.overview => localizations.navOverview,
      TradeSquareDestination.discover => localizations.navDiscover,
      TradeSquareDestination.products => localizations.navProducts,
      TradeSquareDestination.buyingRequests => localizations.navBuyingRequests,
      TradeSquareDestination.connections => localizations.navConnections,
      TradeSquareDestination.messages => localizations.navMessages,
      TradeSquareDestination.aiAssistant => localizations.navAiAssistant,
      TradeSquareDestination.marketIntelligence =>
        localizations.navMarketIntelligence,
      TradeSquareDestination.notifications => localizations.navNotifications,
      TradeSquareDestination.businessProfile =>
        localizations.navBusinessProfile,
      TradeSquareDestination.settings => localizations.navSettings,
      TradeSquareDestination.helpSupport => localizations.navHelpSupport,
    };
  }

  /// Five primary destinations shown in the premium sidebar / mobile bar.
  static List<TradeSquareNavigationItem> primary({
    Map<TradeSquareDestination, int> badgeCounts = const {},
  }) {
    return [
      const TradeSquareNavigationItem(
        destination: TradeSquareDestination.overview,
        section: TradeSquareNavigationSection.workspace,
        icon: Icons.home_outlined,
        mobileIcon: Icons.home_rounded,
        labelOverride: 'Home',
      ),
      const TradeSquareNavigationItem(
        destination: TradeSquareDestination.discover,
        section: TradeSquareNavigationSection.workspace,
        icon: Icons.travel_explore_outlined,
        mobileIcon: Icons.search_rounded,
      ),
      TradeSquareNavigationItem(
        destination: TradeSquareDestination.buyingRequests,
        section: TradeSquareNavigationSection.workspace,
        icon: Icons.tips_and_updates_outlined,
        mobileIcon: Icons.tips_and_updates_outlined,
        labelOverride: 'Opportunities',
        badgeCount: badgeCounts[TradeSquareDestination.buyingRequests] ?? 0,
      ),
      TradeSquareNavigationItem(
        destination: TradeSquareDestination.messages,
        section: TradeSquareNavigationSection.workspace,
        icon: Icons.chat_bubble_outline_rounded,
        mobileIcon: Icons.chat_bubble_rounded,
        badgeCount: badgeCounts[TradeSquareDestination.messages] ?? 0,
      ),
      const TradeSquareNavigationItem(
        destination: TradeSquareDestination.businessProfile,
        section: TradeSquareNavigationSection.workspace,
        icon: Icons.apartment_outlined,
        mobileIcon: Icons.apartment_outlined,
        labelOverride: 'My Business',
      ),
    ];
  }

  static List<TradeSquareNavigationItem> accountActions() {
    return const [
      TradeSquareNavigationItem(
        destination: TradeSquareDestination.settings,
        section: TradeSquareNavigationSection.account,
        icon: Icons.settings_outlined,
      ),
      TradeSquareNavigationItem(
        destination: TradeSquareDestination.helpSupport,
        section: TradeSquareNavigationSection.account,
        icon: Icons.help_outline_rounded,
      ),
    ];
  }

  static List<TradeSquareNavigationItem> defaults({
    Map<TradeSquareDestination, int> badgeCounts = const {},
  }) {
    return [
      ...primary(badgeCounts: badgeCounts),
      TradeSquareNavigationItem(
        destination: TradeSquareDestination.products,
        section: TradeSquareNavigationSection.workspace,
        icon: Icons.inventory_2_outlined,
      ),
      TradeSquareNavigationItem(
        destination: TradeSquareDestination.connections,
        section: TradeSquareNavigationSection.workspace,
        icon: Icons.handshake_outlined,
        badgeCount: badgeCounts[TradeSquareDestination.connections] ?? 0,
      ),
      const TradeSquareNavigationItem(
        destination: TradeSquareDestination.aiAssistant,
        section: TradeSquareNavigationSection.intelligence,
        icon: Icons.auto_awesome_outlined,
        mobileIcon: Icons.auto_awesome_outlined,
      ),
      const TradeSquareNavigationItem(
        destination: TradeSquareDestination.marketIntelligence,
        section: TradeSquareNavigationSection.intelligence,
        icon: Icons.query_stats_outlined,
      ),
      ...accountActions(),
    ];
  }
}

@immutable
class TradeSquareAccount {
  const TradeSquareAccount({
    required this.name,
    required this.businessName,
    this.initials,
    this.imageProvider,
    this.isVerified = false,
  });

  final String name;
  final String businessName;
  final String? initials;
  final ImageProvider<Object>? imageProvider;
  final bool isVerified;
}
