import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/mock_data/mock_businesses.dart';
import '../../../home/domain/trade_square_home_feed.dart';
import '../../data/trade_square_discover_assistant_service.dart';
import '../../domain/discover_conversation_memory.dart';
import '../../domain/trade_square_discover_assistant.dart';
import 'discover_chat_bubble.dart';

/// Text-only TradeSquare AI conversation surface for Discover.
///
/// Intentionally excludes microphone / voice controls.
class DiscoverAiChatSheet extends StatefulWidget {
  const DiscoverAiChatSheet({
    required this.profile,
    required this.locale,
    required this.assistant,
    required this.onViewBusiness,
    required this.onContactBusiness,
    this.initialQuery,
    this.onOpenMessages,
    this.onOpenBusinessProfile,
    this.onOpenOpportunities,
    this.onOpenHome,
    super.key,
  });

  final TradeSquareHomeProfile profile;
  final Locale locale;
  final TradeSquareDiscoverAssistantService assistant;
  final ValueChanged<TradeSquareMockBusiness> onViewBusiness;
  final ValueChanged<TradeSquareMockBusiness> onContactBusiness;
  final String? initialQuery;
  final VoidCallback? onOpenMessages;
  final VoidCallback? onOpenBusinessProfile;
  final VoidCallback? onOpenOpportunities;
  final VoidCallback? onOpenHome;

  static Future<void> open(
    BuildContext context, {
    required TradeSquareHomeProfile profile,
    required Locale locale,
    required TradeSquareDiscoverAssistantService assistant,
    required ValueChanged<TradeSquareMockBusiness> onViewBusiness,
    required ValueChanged<TradeSquareMockBusiness> onContactBusiness,
    String? initialQuery,
    VoidCallback? onOpenMessages,
    VoidCallback? onOpenBusinessProfile,
    VoidCallback? onOpenOpportunities,
    VoidCallback? onOpenHome,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * 0.88;
        return SizedBox(
          height: height,
          child: DiscoverAiChatSheet(
            profile: profile,
            locale: locale,
            assistant: assistant,
            initialQuery: initialQuery,
            onViewBusiness: onViewBusiness,
            onContactBusiness: onContactBusiness,
            onOpenMessages: onOpenMessages,
            onOpenBusinessProfile: onOpenBusinessProfile,
            onOpenOpportunities: onOpenOpportunities,
            onOpenHome: onOpenHome,
          ),
        );
      },
    );
  }

  @override
  State<DiscoverAiChatSheet> createState() => _DiscoverAiChatSheetState();
}

class _DiscoverAiChatSheetState extends State<DiscoverAiChatSheet> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  final _memory = DiscoverConversationMemory();
  final _detector = const DiscoverLanguageDetector();
  final List<DiscoverChatMessage> _messages = [];
  StreamSubscription<DiscoverAssistantTurn>? _sub;
  int _id = 0;

  @override
  void initState() {
    super.initState();
    final language =
        _detector.detect('', localeHint: widget.locale.languageCode);
    final name =
        widget.profile.businessName ?? widget.profile.displayName ?? 'there';
    _messages.add(
      DiscoverChatMessage(
        id: _nextId(),
        role: DiscoverChatRole.assistant,
        text: discoverWelcomeGreeting(language: language, businessName: name),
        createdAt: DateTime.now().toUtc(),
        language: language,
        serviceNote: discoverWelcomeCapabilityNote(language),
      ),
    );
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(initial));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _nextId() => 'ai_${DateTime.now().microsecondsSinceEpoch}_${_id++}';

  Future<void> _scrollToEnd() async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 60,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final language =
        _detector.detect(text, localeHint: widget.locale.languageCode);
    setState(() {
      _composer.clear();
      _messages.add(
        DiscoverChatMessage(
          id: _nextId(),
          role: DiscoverChatRole.user,
          text: text,
          createdAt: DateTime.now().toUtc(),
          language: language,
        ),
      );
      _messages.add(
        DiscoverChatMessage(
          id: _nextId(),
          role: DiscoverChatRole.assistant,
          text: '…',
          createdAt: DateTime.now().toUtc(),
          language: language,
          isStreaming: true,
        ),
      );
    });
    await _scrollToEnd();

    final index = _messages.length - 1;
    await _sub?.cancel();
    _sub = widget.assistant
        .respond(
          message: text,
          profile: widget.profile,
          localeHint: widget.locale.languageCode,
          memory: _memory,
        )
        .listen((turn) async {
      if (!mounted) return;
      setState(() {
        _messages[index] = DiscoverChatMessage(
          id: _messages[index].id,
          role: DiscoverChatRole.assistant,
          text: turn.replyText,
          createdAt: _messages[index].createdAt,
          language: turn.language,
          isStreaming: turn.replyText.endsWith('…') &&
              turn.businesses.isEmpty &&
              turn.navigationTarget == null,
          businesses: turn.businesses,
          products: turn.products,
          actions: turn.actions,
          serviceNote: turn.serviceNote,
        );
      });
      await _scrollToEnd();
      switch (turn.navigationTarget) {
        case 'messages':
          widget.onOpenMessages?.call();
        case 'business':
          widget.onOpenBusinessProfile?.call();
        case 'opportunities':
          widget.onOpenOpportunities?.call();
        case 'home':
          widget.onOpenHome?.call();
      }
    });
  }

  void _handleAction(DiscoverAssistantAction action) {
    switch (action.tool) {
      case DiscoverAssistantTool.openMessages:
        widget.onOpenMessages?.call();
      case DiscoverAssistantTool.openBusinessProfile:
        widget.onOpenBusinessProfile?.call();
      case DiscoverAssistantTool.openOpportunities:
        widget.onOpenOpportunities?.call();
      case DiscoverAssistantTool.openHome:
        widget.onOpenHome?.call();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prompts = discoverSuggestedPromptsFor(
      _detector.detect('', localeHint: widget.locale.languageCode),
    );

    return Material(
      color: AppColors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TradeSquare AI',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Text assistant for business discovery',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (_messages.length <= 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prompt in prompts.take(4))
                    ActionChip(
                      label: Text(prompt.label),
                      onPressed: () => _send(prompt.query),
                      backgroundColor: AppColors.background,
                      side: const BorderSide(color: AppColors.border),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return DiscoverChatBubble(
                  message: _messages[index],
                  onViewBusiness: (business) {
                    Navigator.pop(context);
                    widget.onViewBusiness(business);
                  },
                  onContactBusiness: (business) {
                    Navigator.pop(context);
                    widget.onContactBusiness(business);
                  },
                  onAction: _handleAction,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                10 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: 'Ask TradeSquare AI…',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('discover-ai-send'),
                    onPressed: () => _send(_composer.text),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
