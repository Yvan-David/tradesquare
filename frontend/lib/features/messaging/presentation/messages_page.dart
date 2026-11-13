import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../data/messaging_repository.dart';
import '../domain/messaging_models.dart';
import 'chat_screen.dart';
import 'widgets/conversation_tile.dart';
import 'widgets/messaging_avatar.dart';

class TradeSquareMessagesPage extends StatefulWidget {
  const TradeSquareMessagesPage({
    this.repository,
    this.localLanguageCode = 'en',
    super.key,
  });

  final TradeSquareMessagingRepository? repository;
  final String localLanguageCode;

  @override
  State<TradeSquareMessagesPage> createState() =>
      _TradeSquareMessagesPageState();
}

class _TradeSquareMessagesPageState extends State<TradeSquareMessagesPage> {
  late final TradeSquareMessagingRepository _repository =
      widget.repository ?? TradeSquareMockMessagingRepository();
  final _searchController = TextEditingController();

  TradeSquareConversationFilter _filter = TradeSquareConversationFilter.all;
  List<TradeSquareConversationPreview> _conversations = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _conversations.isEmpty;
      _error = null;
    });
    try {
      final results = await _repository.fetchConversations(
        query: _searchController.text,
        filter: _filter,
      );
      if (!mounted) return;
      setState(() {
        _conversations = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load conversations.';
        _loading = false;
      });
    }
  }

  Future<void> _openConversation(TradeSquareConversationPreview preview) async {
    final detail = await _repository.fetchConversation(preview.id);
    if (!mounted || detail == null) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: TradeSquareChatScreen(
              conversation: detail,
              repository: _repository,
              localLanguageCode: widget.localLanguageCode,
            ),
          ),
        ),
      ),
    );
    await _load();
  }

  Future<void> _openNewMessageSheet() async {
    final contacts = await _repository.searchContacts('');
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _NewMessageSheet(
          contacts: contacts,
          onSearch: _repository.searchContacts,
          onSelect: (participant) async {
            Navigator.of(context).pop();
            final existing = _conversations
                .where((c) => c.participant.id == participant.id)
                .firstOrNull;
            if (existing != null) {
              await _openConversation(existing);
              return;
            }
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.deepBlue,
                content: Text(
                  'Start a conversation with ${participant.displayName} once messaging is connected.',
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadTotal =
        _conversations.fold<int>(0, (sum, item) => sum + item.unreadCount);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Messages',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  unreadTotal == 0
                                      ? 'Stay close to your trade partners'
                                      : '$unreadTotal unread · reply when ready',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _PremiumIconButton(
                            icon: Icons.edit_square,
                            tooltip: 'New message',
                            onTap: _openNewMessageSheet,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SearchField(controller: _searchController),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final filter in TradeSquareConversationFilter
                                .values) ...[
                              _FilterChip(
                                label: switch (filter) {
                                  TradeSquareConversationFilter.all => 'All',
                                  TradeSquareConversationFilter.unread =>
                                    'Unread',
                                  TradeSquareConversationFilter.buyers =>
                                    'Buyers',
                                  TradeSquareConversationFilter.suppliers =>
                                    'Suppliers',
                                },
                                selected: _filter == filter,
                                onTap: () {
                                  setState(() => _filter = filter);
                                  _load();
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Messages unavailable',
                    subtitle: _error!,
                    actionLabel: 'Try again',
                    onAction: _load,
                  ),
                )
              else if (_conversations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No conversations yet',
                    subtitle:
                        'Start a message to coordinate orders, quotes, and deliveries.',
                    actionLabel: 'New message',
                    onAction: _openNewMessageSheet,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  sliver: SliverList.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      return TradeSquareConversationTile(
                        conversation: conversation,
                        onTap: () => _openConversation(conversation),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        decoration: const InputDecoration(
          hintText: 'Search messages or partners',
          hintStyle: TextStyle(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.deepBlue),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumIconButton extends StatefulWidget {
  const _PremiumIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_PremiumIconButton> createState() => _PremiumIconButtonState();
}

class _PremiumIconButtonState extends State<_PremiumIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 110),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            customBorder: const CircleBorder(),
            child: Ink(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.deepBlue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: AppColors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _NewMessageSheet extends StatefulWidget {
  const _NewMessageSheet({
    required this.contacts,
    required this.onSearch,
    required this.onSelect,
  });

  final List<TradeSquareChatParticipant> contacts;
  final Future<List<TradeSquareChatParticipant>> Function(String query)
      onSearch;
  final ValueChanged<TradeSquareChatParticipant> onSelect;

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  late List<TradeSquareChatParticipant> _contacts = widget.contacts;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final results = await widget.onSearch(value);
    if (!mounted) return;
    setState(() => _contacts = results);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 72),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'New message',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _controller,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search partners',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: _contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return ListTile(
                  onTap: () => widget.onSelect(contact),
                  leading: TradeSquareMessagingAvatar(
                    participant: contact,
                    size: 46,
                    showVerified: true,
                  ),
                  title: Text(
                    contact.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: Text(
                    '${contact.businessName} · ${contact.roleLabel}',
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
