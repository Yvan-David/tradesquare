import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../data/messaging_repository.dart';
import '../domain/call_models.dart';
import '../domain/messaging_models.dart';
import 'call_screen.dart';
import 'widgets/chat_composer.dart';
import 'widgets/message_bubble.dart';
import 'widgets/messaging_avatar.dart';

class TradeSquareChatScreen extends StatefulWidget {
  const TradeSquareChatScreen({
    required this.conversation,
    required this.repository,
    this.localLanguageCode = 'en',
    this.callCoordinator = const TradeSquareLocalCallCoordinator(),
    super.key,
  });

  final TradeSquareConversationDetail conversation;
  final TradeSquareMessagingRepository repository;
  final String localLanguageCode;
  final TradeSquareCallCoordinator callCoordinator;

  @override
  State<TradeSquareChatScreen> createState() => _TradeSquareChatScreenState();
}

class _TradeSquareChatScreenState extends State<TradeSquareChatScreen> {
  late TradeSquareConversationDetail _conversation = widget.conversation;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final optimistic = await widget.repository.sendTextMessage(
      conversationId: _conversation.id,
      text: text,
    );
    if (!mounted) return;
    setState(() {
      _conversation = TradeSquareConversationDetail(
        id: _conversation.id,
        participant: _conversation.participant,
        relationship: _conversation.relationship,
        unreadCount: 0,
        messages: [..._conversation.messages, optimistic],
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _startAudioCall() async {
    final session = widget.callCoordinator.startOutgoing(
      conversation: _conversation,
      media: TradeSquareCallMedia.audio,
      localLanguageCode: widget.localLanguageCode,
    );
    await _openCall(session);
  }

  Future<void> _startVideoCall() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _VideoCallConfirmSheet(
        participant: _conversation.participant,
      ),
    );
    if (confirmed != true || !mounted) return;
    final session = widget.callCoordinator.startOutgoing(
      conversation: _conversation,
      media: TradeSquareCallMedia.video,
      localLanguageCode: widget.localLanguageCode,
    );
    await _openCall(session);
  }

  Future<void> _openCall(TradeSquareCallSession session) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: TradeSquareCallScreen(initialSession: session),
        ),
      ),
    );
  }

  void _showAttachPrep() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepBlue,
        content: Text('Attachments will connect when file sharing is enabled.'),
      ),
    );
  }

  void _showVoicePrep() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepBlue,
        content: Text('Voice notes are prepared in the UI and not uploaded yet.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final participant = _conversation.participant;
    final grouped = _groupMessages(_conversation.messages);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _ChatHeader(
            participant: participant,
            relationship: _conversation.relationship,
            onBack: () => Navigator.of(context).maybePop(),
            onAudioCall: _startAudioCall,
            onVideoCall: _startVideoCall,
            onPreviewIncoming: (media) async {
              final session = widget.callCoordinator.simulateIncoming(
                conversation: _conversation,
                media: media,
                localLanguageCode: widget.localLanguageCode,
              );
              await _openCall(session);
            },
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped[index];
                if (entry is _DayLabel) {
                  return TradeSquareDaySeparator(label: entry.label);
                }
                final message = (entry as _MessageEntry).message;
                final showTail = index == grouped.length - 1 ||
                    grouped[index + 1] is _DayLabel ||
                    (grouped[index + 1] as _MessageEntry).message.isMine !=
                        message.isMine;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TradeSquareMessageBubble(
                    message: message,
                    showTail: showTail,
                  ),
                );
              },
            ),
          ),
          TradeSquareChatComposer(
            onSend: _send,
            onAttach: _showAttachPrep,
            onVoice: _showVoicePrep,
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.participant,
    required this.relationship,
    required this.onBack,
    required this.onAudioCall,
    required this.onVideoCall,
    required this.onPreviewIncoming,
  });

  final TradeSquareChatParticipant participant;
  final String relationship;
  final VoidCallback onBack;
  final VoidCallback onAudioCall;
  final VoidCallback onVideoCall;
  final ValueChanged<TradeSquareCallMedia> onPreviewIncoming;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.paddingOf(context).top + 8,
        12,
        12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          ),
          TradeSquareMessagingAvatar(
            participant: participant,
            size: 44,
            showVerified: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    participant.businessName,
                    if (participant.isOnline) 'Active now',
                    relationship,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          _HeaderCallButton(
            tooltip: 'Audio call',
            icon: Icons.call_rounded,
            emphasized: true,
            onTap: onAudioCall,
          ),
          const SizedBox(width: 6),
          _HeaderCallButton(
            tooltip: 'Video call',
            icon: Icons.videocam_outlined,
            emphasized: false,
            onTap: onVideoCall,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.text),
            onSelected: (value) {
              if (value == 'incoming_audio') {
                onPreviewIncoming(TradeSquareCallMedia.audio);
              } else if (value == 'incoming_video') {
                onPreviewIncoming(TradeSquareCallMedia.video);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'incoming_audio',
                child: Text('Preview incoming audio call'),
              ),
              PopupMenuItem(
                value: 'incoming_video',
                child: Text('Preview incoming video call'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCallButton extends StatefulWidget {
  const _HeaderCallButton({
    required this.tooltip,
    required this.icon,
    required this.emphasized,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  State<_HeaderCallButton> createState() => _HeaderCallButtonState();
}

class _HeaderCallButtonState extends State<_HeaderCallButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            customBorder: const CircleBorder(),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.emphasized
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.deepBlue],
                      )
                    : null,
                color: widget.emphasized ? null : AppColors.background,
                border: widget.emphasized
                    ? null
                    : Border.all(color: AppColors.border),
                boxShadow: widget.emphasized
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.icon,
                color: widget.emphasized ? AppColors.white : AppColors.deepBlue,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoCallConfirmSheet extends StatelessWidget {
  const _VideoCallConfirmSheet({required this.participant});

  final TradeSquareChatParticipant participant;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          TradeSquareMessagingAvatar(
            participant: participant,
            size: 64,
            showVerified: true,
          ),
          const SizedBox(height: 14),
          Text(
            'Start a video call with ${participant.displayName}?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Video calling is intentional. Audio remains the default Call action.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.videocam_rounded),
                  label: const Text('Video call'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

sealed class _TimelineEntry {}

class _DayLabel extends _TimelineEntry {
  _DayLabel(this.label);
  final String label;
}

class _MessageEntry extends _TimelineEntry {
  _MessageEntry(this.message);
  final TradeSquareChatMessage message;
}

List<_TimelineEntry> _groupMessages(List<TradeSquareChatMessage> messages) {
  final entries = <_TimelineEntry>[];
  DateTime? lastDay;
  for (final message in messages) {
    final day = DateTime(
      message.sentAt.year,
      message.sentAt.month,
      message.sentAt.day,
    );
    if (lastDay == null || day != lastDay) {
      entries.add(_DayLabel(_dayLabel(day)));
      lastDay = day;
    }
    entries.add(_MessageEntry(message));
  }
  return entries;
}

String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${day.day}/${day.month}/${day.year}';
}
