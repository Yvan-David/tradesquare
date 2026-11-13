import 'package:flutter/foundation.dart';

enum TradeSquareMessageKind { text, image, voice, attachment, system }

enum TradeSquareMessageStatus { sending, sent, delivered, read }

enum TradeSquareConversationFilter { all, unread, buyers, suppliers }

@immutable
class TradeSquareChatParticipant {
  const TradeSquareChatParticipant({
    required this.id,
    required this.displayName,
    required this.businessName,
    required this.preferredLanguage,
    this.photoUrl,
    this.roleLabel = '',
    this.isOnline = false,
    this.isVerified = false,
  });

  final String id;
  final String displayName;
  final String businessName;
  final String preferredLanguage;
  final String? photoUrl;
  final String roleLabel;
  final bool isOnline;
  final bool isVerified;

  String get initials {
    final parts =
        displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) {
      final value = list.first;
      return value.substring(0, value.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
  }
}

@immutable
class TradeSquareChatMessage {
  const TradeSquareChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.kind,
    required this.status,
    this.attachmentLabel,
    this.durationLabel,
    this.isMine = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final TradeSquareMessageKind kind;
  final TradeSquareMessageStatus status;
  final String? attachmentLabel;
  final String? durationLabel;
  final bool isMine;
}

@immutable
class TradeSquareConversationPreview {
  const TradeSquareConversationPreview({
    required this.id,
    required this.participant,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.relationship,
    this.isPinned = false,
    this.isMuted = false,
  });

  final String id;
  final TradeSquareChatParticipant participant;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final String relationship;
  final bool isPinned;
  final bool isMuted;

  bool get hasUnread => unreadCount > 0;
}

@immutable
class TradeSquareConversationDetail {
  const TradeSquareConversationDetail({
    required this.id,
    required this.participant,
    required this.messages,
    required this.relationship,
    this.unreadCount = 0,
  });

  final String id;
  final TradeSquareChatParticipant participant;
  final List<TradeSquareChatMessage> messages;
  final String relationship;
  final int unreadCount;
}
