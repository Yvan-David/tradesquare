import '../../../core/mock_data/mock_businesses.dart';
import '../../../core/mock_data/mock_messages.dart';
import '../../../core/mock_data/mock_users.dart';
import '../domain/messaging_models.dart';

abstract interface class TradeSquareMessagingRepository {
  Future<List<TradeSquareConversationPreview>> fetchConversations({
    String? query,
    TradeSquareConversationFilter filter = TradeSquareConversationFilter.all,
  });

  Future<TradeSquareConversationDetail?> fetchConversation(String id);

  Future<TradeSquareChatMessage> sendTextMessage({
    required String conversationId,
    required String text,
  });

  Future<List<TradeSquareChatParticipant>> searchContacts(String query);
}

class TradeSquareMockMessagingRepository
    implements TradeSquareMessagingRepository {
  TradeSquareMockMessagingRepository({
    this.currentUserId = 'usr_001',
    List<TradeSquareMockConversation>? seed,
  }) : _seedOverride = seed;

  final String currentUserId;
  final List<TradeSquareMockConversation>? _seedOverride;
  List<TradeSquareMockConversation>? _mutableConversations;
  final List<TradeSquareChatMessage> _draftSent = [];

  List<TradeSquareMockConversation> get _conversations {
    _mutableConversations ??=
        List.of(_seedOverride ?? tradeSquareMockConversations);
    // Refresh from catalog when local cache is empty but DB data arrived later.
    if (_mutableConversations!.isEmpty &&
        _seedOverride == null &&
        tradeSquareMockConversations.isNotEmpty) {
      _mutableConversations = List.of(tradeSquareMockConversations);
    }
    return _mutableConversations!;
  }

  @override
  Future<List<TradeSquareConversationPreview>> fetchConversations({
    String? query,
    TradeSquareConversationFilter filter = TradeSquareConversationFilter.all,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final previews = _conversations
        .map(_toPreview)
        .whereType<TradeSquareConversationPreview>()
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.lastMessageAt.compareTo(a.lastMessageAt);
      });

    final normalized = query?.trim().toLowerCase() ?? '';
    var filtered = previews;
    if (normalized.isNotEmpty) {
      filtered = filtered
          .where(
            (item) =>
                item.participant.displayName.toLowerCase().contains(normalized) ||
                item.participant.businessName
                    .toLowerCase()
                    .contains(normalized) ||
                item.lastMessage.toLowerCase().contains(normalized),
          )
          .toList();
    }

    return switch (filter) {
      TradeSquareConversationFilter.all => filtered,
      TradeSquareConversationFilter.unread =>
        filtered.where((item) => item.hasUnread).toList(),
      TradeSquareConversationFilter.buyers =>
        filtered.where((item) => item.relationship == 'buyer').toList(),
      TradeSquareConversationFilter.suppliers =>
        filtered.where((item) => item.relationship == 'supplier').toList(),
    };
  }

  @override
  Future<TradeSquareConversationDetail?> fetchConversation(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final match = _conversations.where((c) => c.id == id).firstOrNull;
    if (match == null) return null;

    final participant = _otherParticipant(match);
    if (participant == null) return null;

    final baseMessages = match.messages
        .map((message) => _toMessage(match.id, message))
        .toList();
    final extras =
        _draftSent.where((message) => message.conversationId == id).toList();
    final messages = [...baseMessages, ...extras]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

    final unread = match.messages
        .where(
          (message) =>
              message.senderId != currentUserId &&
              message.readStatus == 'unread',
        )
        .length;

    return TradeSquareConversationDetail(
      id: match.id,
      participant: participant,
      messages: messages,
      relationship: match.businessRelationship,
      unreadCount: unread,
    );
  }

  @override
  Future<TradeSquareChatMessage> sendTextMessage({
    required String conversationId,
    required String text,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final message = TradeSquareChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: currentUserId,
      text: text.trim(),
      sentAt: DateTime.now().toUtc(),
      kind: TradeSquareMessageKind.text,
      status: TradeSquareMessageStatus.sent,
      isMine: true,
    );
    _draftSent.add(message);
    return message;
  }

  @override
  Future<List<TradeSquareChatParticipant>> searchContacts(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final normalized = query.trim().toLowerCase();
    return tradeSquareMockUsers
        .where((user) => user.id != currentUserId)
        .map(_participantFromUser)
        .where(
          (participant) =>
              normalized.isEmpty ||
              participant.displayName.toLowerCase().contains(normalized) ||
              participant.businessName.toLowerCase().contains(normalized),
        )
        .toList();
  }

  TradeSquareConversationPreview? _toPreview(
    TradeSquareMockConversation conversation,
  ) {
    final participant = _otherParticipant(conversation);
    if (participant == null) return null;
    final last = conversation.messages.isEmpty
        ? null
        : conversation.messages.reduce(
            (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
          );
    final unread = conversation.messages
        .where(
          (message) =>
              message.senderId != currentUserId &&
              message.readStatus == 'unread',
        )
        .length;

    return TradeSquareConversationPreview(
      id: conversation.id,
      participant: participant,
      lastMessage: _previewText(last),
      lastMessageAt: last?.timestamp ?? DateTime.utc(2026, 1, 1),
      unreadCount: unread,
      relationship: conversation.businessRelationship,
      isPinned: conversation.id == 'conv_001',
    );
  }

  TradeSquareChatParticipant? _otherParticipant(
    TradeSquareMockConversation conversation,
  ) {
    final otherId = conversation.participants
        .where((id) => id != currentUserId)
        .firstOrNull;
    if (otherId == null) return null;
    final user =
        tradeSquareMockUsers.where((entry) => entry.id == otherId).firstOrNull;
    if (user == null) return null;
    return _participantFromUser(user);
  }

  TradeSquareChatParticipant _participantFromUser(TradeSquareMockUser user) {
    final business = tradeSquareMockBusinesses
        .where((entry) => entry.id == user.businessAssociation)
        .firstOrNull;
    final roleLabel = switch (user.role) {
      TradeSquareMockUserRole.buyer => 'Buyer',
      TradeSquareMockUserRole.supplier => 'Supplier',
      TradeSquareMockUserRole.businessOwner => 'Business owner',
      TradeSquareMockUserRole.administrator => 'Admin',
    };

    return TradeSquareChatParticipant(
      id: user.id,
      displayName: user.fullName,
      businessName: business?.name ?? user.businessAssociation,
      preferredLanguage: user.preferredLanguage,
      photoUrl: user.photoUrl,
      roleLabel: roleLabel,
      isOnline: user.status == TradeSquareMockUserStatus.active,
      isVerified: business?.verificationStatus ==
          TradeSquareMockVerificationStatus.approved,
    );
  }

  TradeSquareChatMessage _toMessage(
    String conversationId,
    TradeSquareMockMessage message,
  ) {
    final kind = switch (message.messageType) {
      'image' => TradeSquareMessageKind.image,
      'voice' => TradeSquareMessageKind.voice,
      'attachment' => TradeSquareMessageKind.attachment,
      'system' => TradeSquareMessageKind.system,
      _ => TradeSquareMessageKind.text,
    };
    final status = switch (message.readStatus) {
      'unread' => TradeSquareMessageStatus.delivered,
      'sending' => TradeSquareMessageStatus.sending,
      _ => TradeSquareMessageStatus.read,
    };

    return TradeSquareChatMessage(
      id: message.id,
      conversationId: conversationId,
      senderId: message.senderId,
      text: message.text,
      sentAt: message.timestamp,
      kind: kind,
      status: status,
      attachmentLabel: message.attachmentName,
      durationLabel: message.voiceDuration,
      isMine: message.senderId == currentUserId,
    );
  }

  String _previewText(TradeSquareMockMessage? message) {
    if (message == null) return 'No messages yet';
    return switch (message.messageType) {
      'image' => 'Photo',
      'voice' => 'Voice message',
      'attachment' => message.attachmentName ?? 'Attachment',
      _ => message.text,
    };
  }
}
