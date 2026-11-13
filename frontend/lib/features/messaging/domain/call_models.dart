import 'package:flutter/foundation.dart';

import 'messaging_models.dart';

enum TradeSquareCallMedia { audio, video }

enum TradeSquareCallPhase {
  outgoing,
  incoming,
  connecting,
  active,
  ended,
}

enum TradeSquareCallTranslationState {
  /// Same preferred language — AI translation is not engaged.
  bypassed,

  /// Different languages — live translation is active.
  active,

  /// User paused captions / translation display.
  paused,
}

@immutable
class TradeSquareCallSession {
  const TradeSquareCallSession({
    required this.id,
    required this.conversationId,
    required this.participant,
    required this.media,
    required this.phase,
    required this.localLanguageCode,
    required this.remoteLanguageCode,
    this.startedAt,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.isCameraOn = false,
    this.areCaptionsOn = true,
    this.translationPaused = false,
    this.translationEnabled = true,
    this.preferTranslatedAudio = true,
    this.connectionLabel,
    this.captionOriginal,
    this.captionTranslated,
  });

  final String id;
  final String conversationId;
  final TradeSquareChatParticipant participant;
  final TradeSquareCallMedia media;
  final TradeSquareCallPhase phase;
  final String localLanguageCode;
  final String remoteLanguageCode;
  final DateTime? startedAt;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isCameraOn;
  final bool areCaptionsOn;
  final bool translationPaused;
  final bool translationEnabled;
  final bool preferTranslatedAudio;
  final String? connectionLabel;
  final String? captionOriginal;
  final String? captionTranslated;

  bool get languagesDiffer =>
      localLanguageCode.toLowerCase() != remoteLanguageCode.toLowerCase();

  TradeSquareCallTranslationState get translationState {
    if (!languagesDiffer || !translationEnabled) {
      return TradeSquareCallTranslationState.bypassed;
    }
    if (translationPaused) return TradeSquareCallTranslationState.paused;
    return TradeSquareCallTranslationState.active;
  }

  bool get isVideo => media == TradeSquareCallMedia.video;

  TradeSquareCallSession copyWith({
    TradeSquareCallPhase? phase,
    DateTime? startedAt,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isCameraOn,
    bool? areCaptionsOn,
    bool? translationPaused,
    bool? translationEnabled,
    bool? preferTranslatedAudio,
    String? localLanguageCode,
    String? remoteLanguageCode,
    String? connectionLabel,
    String? captionOriginal,
    String? captionTranslated,
  }) {
    return TradeSquareCallSession(
      id: id,
      conversationId: conversationId,
      participant: participant,
      media: media,
      phase: phase ?? this.phase,
      localLanguageCode: localLanguageCode ?? this.localLanguageCode,
      remoteLanguageCode: remoteLanguageCode ?? this.remoteLanguageCode,
      startedAt: startedAt ?? this.startedAt,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      areCaptionsOn: areCaptionsOn ?? this.areCaptionsOn,
      translationPaused: translationPaused ?? this.translationPaused,
      translationEnabled: translationEnabled ?? this.translationEnabled,
      preferTranslatedAudio:
          preferTranslatedAudio ?? this.preferTranslatedAudio,
      connectionLabel: connectionLabel ?? this.connectionLabel,
      captionOriginal: captionOriginal ?? this.captionOriginal,
      captionTranslated: captionTranslated ?? this.captionTranslated,
    );
  }
}

/// UI-only call coordinator. Keeps LiveKit / AI translation services out of widgets.
abstract interface class TradeSquareCallCoordinator {
  TradeSquareCallSession startOutgoing({
    required TradeSquareConversationDetail conversation,
    required TradeSquareCallMedia media,
    required String localLanguageCode,
  });

  TradeSquareCallSession simulateIncoming({
    required TradeSquareConversationDetail conversation,
    required TradeSquareCallMedia media,
    required String localLanguageCode,
  });
}

class TradeSquareLocalCallCoordinator implements TradeSquareCallCoordinator {
  const TradeSquareLocalCallCoordinator();

  @override
  TradeSquareCallSession startOutgoing({
    required TradeSquareConversationDetail conversation,
    required TradeSquareCallMedia media,
    required String localLanguageCode,
  }) {
    return TradeSquareCallSession(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversation.id,
      participant: conversation.participant,
      media: media,
      phase: TradeSquareCallPhase.outgoing,
      localLanguageCode: localLanguageCode,
      remoteLanguageCode: conversation.participant.preferredLanguage,
      isCameraOn: media == TradeSquareCallMedia.video,
    );
  }

  @override
  TradeSquareCallSession simulateIncoming({
    required TradeSquareConversationDetail conversation,
    required TradeSquareCallMedia media,
    required String localLanguageCode,
  }) {
    return TradeSquareCallSession(
      id: 'call_in_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversation.id,
      participant: conversation.participant,
      media: media,
      phase: TradeSquareCallPhase.incoming,
      localLanguageCode: localLanguageCode,
      remoteLanguageCode: conversation.participant.preferredLanguage,
      isCameraOn: media == TradeSquareCallMedia.video,
    );
  }
}

String tradeSquareLanguageLabel(String code) {
  return switch (code.toLowerCase()) {
    'en' => 'English',
    'rw' => 'Kinyarwanda',
    'fr' => 'French',
    'sw' => 'Swahili',
    _ => code.toUpperCase(),
  };
}
