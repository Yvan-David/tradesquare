import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/api/tradesquare_api_client.dart';
import '../domain/call_models.dart';

/// Asks the TradeSquare API for a LiveKit join token, then connects the room.
class TradeSquareLiveKitCallConnection extends ChangeNotifier {
  TradeSquareLiveKitCallConnection({TradeSquareApiClient? api})
      : _api = api ?? TradeSquareApiClient();

  final TradeSquareApiClient _api;
  Room? room;
  String? error;
  bool connecting = false;

  VideoTrack? get localVideo =>
      _firstVideo(room?.localParticipant?.videoTrackPublications);

  VideoTrack? get remoteVideo {
    final current = room;
    if (current == null) return null;
    for (final participant in current.remoteParticipants.values) {
      final track = _firstVideo(participant.videoTrackPublications);
      if (track != null) return track;
    }
    return null;
  }

  Future<void> connect({
    required TradeSquareCallSession session,
    required String identity,
    required String displayName,
  }) async {
    if (connecting || room != null) return;
    connecting = true;
    error = null;
    notifyListeners();
    try {
      final roomName = 'tradesquare-call-${session.conversationId}';
      final payload = await _api.postJson('/api/v1/calls/livekit/token', {
        'identity': identity,
        'conversation_id': session.conversationId,
        'room': roomName.length > 128 ? roomName.substring(0, 128) : roomName,
        'media': session.isVideo ? 'video' : 'audio',
        'local_language': session.localLanguageCode,
        'remote_language': session.remoteLanguageCode,
        'display_name': displayName,
      });
      final url = payload['url'] as String?;
      final token = payload['token'] as String?;
      if (url == null || token == null || url.isEmpty || token.isEmpty) {
        throw StateError('The server did not return a LiveKit token.');
      }
      final next = Room();
      next.addListener(notifyListeners);
      await next.connect(url, token);
      await next.localParticipant?.setMicrophoneEnabled(!session.isMuted);
      if (session.isVideo && session.isCameraOn) {
        await next.localParticipant?.setCameraEnabled(true);
      }
      room = next;
      error = null;
    } catch (caught) {
      error = caught.toString();
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<void> setMicrophone(bool enabled) async {
    await room?.localParticipant?.setMicrophoneEnabled(enabled);
    notifyListeners();
  }

  Future<void> setCamera(bool enabled) async {
    await room?.localParticipant?.setCameraEnabled(enabled);
    notifyListeners();
  }

  Future<void> close() async {
    final current = room;
    room = null;
    current?.removeListener(notifyListeners);
    await current?.disconnect();
  }

  VideoTrack? _firstVideo(Iterable<TrackPublication>? publications) {
    if (publications == null) return null;
    for (final publication in publications) {
      final track = publication.track;
      if (track is VideoTrack) return track;
    }
    return null;
  }
}
