import '../api/catalog_store.dart';

class TradeSquareMockMessage {
  const TradeSquareMockMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.messageType,
    required this.readStatus,
    this.attachmentName,
    this.voiceDuration,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String messageType;
  final String readStatus;
  final String? attachmentName;
  final String? voiceDuration;

  factory TradeSquareMockMessage.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockMessage(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: json['timestamp'] is String
          ? DateTime.tryParse(json['timestamp'] as String) ??
              DateTime.utc(2026, 1, 1)
          : DateTime.utc(2026, 1, 1),
      messageType: json['messageType'] as String? ?? 'text',
      readStatus: json['readStatus'] as String? ?? 'read',
      attachmentName: json['attachmentName'] as String?,
      voiceDuration: json['voiceDuration'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'messageType': messageType,
        'readStatus': readStatus,
        'attachmentName': attachmentName,
        'voiceDuration': voiceDuration,
      };
}

class TradeSquareMockConversation {
  const TradeSquareMockConversation({
    required this.id,
    required this.participants,
    required this.businessRelationship,
    required this.messages,
  });

  final String id;
  final List<String> participants;
  final String businessRelationship;
  final List<TradeSquareMockMessage> messages;

  factory TradeSquareMockConversation.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockConversation(
      id: json['id'] as String? ?? '',
      participants:
          List<String>.from(json['participants'] as List? ?? const []),
      businessRelationship: json['businessRelationship'] as String? ?? '',
      messages: (json['messages'] as List? ?? const [])
          .map((entry) => TradeSquareMockMessage.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'participants': participants,
        'businessRelationship': businessRelationship,
        'messages': messages.map((message) => message.toJson()).toList(),
      };
}

List<TradeSquareMockConversation> get tradeSquareMockConversations => CatalogStore.instance.conversations;
