import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/discover_speech_naturalness.dart';
import '../../domain/trade_square_discover_assistant.dart';
import '../../presentation/widgets/discover_voice_listener.dart';

/// Speech-to-text boundary. Default uses on-device speech_to_text.
/// Cloud / NVIDIA Kinyarwanda STT plugs in here when a server is available.
abstract class DiscoverSpeechToTextAdapter {
  Future<bool> ensureReady();
  bool get isListening;
  bool get supportsPartialResults;
  String get providerId;
  Future<void> start({
    required DiscoverAssistantLanguage language,
    required ValueChanged<String> onPartial,
    required ValueChanged<String> onFinal,
  });
  Future<void> stop();
  Future<void> cancel();
  void dispose();
  String get integrationNote;
}

class DeviceDiscoverSpeechToTextAdapter implements DiscoverSpeechToTextAdapter {
  DeviceDiscoverSpeechToTextAdapter({DiscoverVoiceListener? listener})
      : _listener = listener ?? DiscoverVoiceListener();

  final DiscoverVoiceListener _listener;

  @override
  String get providerId => 'device_speech_to_text';

  @override
  bool get supportsPartialResults => true;

  @override
  String get integrationNote =>
      'Using on-device speech recognition. NVIDIA Kinyarwanda STT '
      '(nvidia/stt_rw_conformer_ctc_large) is file/chunk transcription via NeMo '
      '(~120M params, ~18% WER on MCV-9 test). Native streaming needs NVIDIA Riva '
      'or a custom chunked worker — not loaded in this build.';

  @override
  Future<bool> ensureReady() => _listener.ensureReady();

  @override
  bool get isListening => _listener.isListening;

  @override
  Future<void> start({
    required DiscoverAssistantLanguage language,
    required ValueChanged<String> onPartial,
    required ValueChanged<String> onFinal,
  }) {
    return _listener.start(
      localeId: discoverSpeechLocaleId(language),
      onPartial: onPartial,
      onFinal: onFinal,
    );
  }

  @override
  Future<void> stop() => _listener.stop();

  @override
  Future<void> cancel() => _listener.cancel();

  @override
  void dispose() => _listener.dispose();
}

/// Optional remote STT worker (e.g. NVIDIA NeMo/Riva behind FastAPI).
///
/// This adapter never invents transcripts. If the worker URL is unset or the
/// request fails, [ensureReady] returns false so a fallback can take over.
class RemoteDiscoverSpeechToTextAdapter implements DiscoverSpeechToTextAdapter {
  RemoteDiscoverSpeechToTextAdapter({
    this.endpointUrl,
    this.supportsPartial = false,
  });

  /// Example: http://localhost:8000/api/v1/discover/stt/transcribe
  final String? endpointUrl;
  final bool supportsPartial;
  bool _listening = false;

  @override
  String get providerId => 'remote_nvidia_kinyarwanda_stt';

  @override
  bool get supportsPartialResults => supportsPartial;

  @override
  String get integrationNote => endpointUrl == null || endpointUrl!.isEmpty
      ? 'Remote Kinyarwanda STT worker URL is not configured.'
      : 'Remote STT endpoint configured at $endpointUrl. '
          'File/chunk transcription only unless the worker implements streaming.';

  @override
  Future<bool> ensureReady() async {
    return endpointUrl != null && endpointUrl!.trim().isNotEmpty;
  }

  @override
  bool get isListening => _listening;

  @override
  Future<void> start({
    required DiscoverAssistantLanguage language,
    required ValueChanged<String> onPartial,
    required ValueChanged<String> onFinal,
  }) async {
    final ready = await ensureReady();
    if (!ready) {
      throw StateError(integrationNote);
    }
    // Audio capture + multipart upload belongs in the worker client once the
    // GPU endpoint exists. We refuse to fake a transcript here.
    _listening = false;
    throw StateError(
      'Remote NVIDIA STT worker is configured but audio upload is not enabled '
      'in this Flutter build. Falling back to on-device recognition.',
    );
  }

  @override
  Future<void> stop() async {
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    _listening = false;
  }

  @override
  void dispose() {
    _listening = false;
  }
}

/// Tries preferred providers first, then falls back without changing Discover UI.
class CascadingDiscoverSpeechToTextAdapter
    implements DiscoverSpeechToTextAdapter {
  CascadingDiscoverSpeechToTextAdapter({
    required List<DiscoverSpeechToTextAdapter> providers,
  }) : _providers = providers;

  final List<DiscoverSpeechToTextAdapter> _providers;
  DiscoverSpeechToTextAdapter? _active;

  @override
  String get providerId => _active?.providerId ?? 'cascading_stt';

  @override
  bool get supportsPartialResults =>
      _active?.supportsPartialResults ??
      _providers.any((provider) => provider.supportsPartialResults);

  @override
  String get integrationNote {
    final notes = _providers.map((provider) => provider.integrationNote).join(' | ');
    return 'STT cascade: $notes';
  }

  @override
  Future<bool> ensureReady() async {
    for (final provider in _providers) {
      if (await provider.ensureReady()) {
        _active = provider;
        return true;
      }
    }
    _active = null;
    return false;
  }

  @override
  bool get isListening => _active?.isListening ?? false;

  @override
  Future<void> start({
    required DiscoverAssistantLanguage language,
    required ValueChanged<String> onPartial,
    required ValueChanged<String> onFinal,
  }) async {
    Object? lastError;
    for (final provider in _providers) {
      try {
        if (!await provider.ensureReady()) continue;
        _active = provider;
        await provider.start(
          language: language,
          onPartial: onPartial,
          onFinal: onFinal,
        );
        return;
      } catch (error) {
        lastError = error;
        if (kDebugMode) {
          debugPrint('STT provider ${provider.providerId} failed: $error');
        }
      }
    }
    throw StateError(
      lastError?.toString() ??
          'No speech recognition provider is available right now.',
    );
  }

  @override
  Future<void> stop() async {
    await _active?.stop();
  }

  @override
  Future<void> cancel() async {
    await _active?.cancel();
  }

  @override
  void dispose() {
    for (final provider in _providers) {
      provider.dispose();
    }
  }
}

/// Text-to-speech boundary. Default uses OS voices via flutter_tts.
abstract class DiscoverTextToSpeechAdapter {
  Future<bool> ensureReady();
  Future<void> speak({
    required String text,
    required DiscoverAssistantLanguage language,
    VoidCallback? onComplete,
  });
  Future<void> stop();
  void dispose();
  String get integrationNote;
  String get providerId;
  bool get supportsKinyarwandaNatively;
  bool get supportsStreamingChunks;
}

class DeviceDiscoverTextToSpeechAdapter implements DiscoverTextToSpeechAdapter {
  DeviceDiscoverTextToSpeechAdapter({
    DiscoverSpeechNaturalness naturalness = const DiscoverSpeechNaturalness(),
  }) : _naturalness = naturalness;

  final FlutterTts _tts = FlutterTts();
  final DiscoverSpeechNaturalness _naturalness;
  bool _ready = false;
  int _speakEpoch = 0;
  VoidCallback? _onComplete;

  @override
  String get providerId => 'device_flutter_tts';

  @override
  String get integrationNote =>
      'Using device text-to-speech with phrase chunking. Dedicated Kinyarwanda TTS '
      '(C4IR-RW/kinya-flex-tts preferred; mbazaNLP/kinyarwanda-tts-model alternate) '
      'is not connected. Naturalness is not certified by native speakers yet.';

  @override
  bool get supportsKinyarwandaNatively => false;

  @override
  bool get supportsStreamingChunks => true;

  @override
  Future<bool> ensureReady() async {
    if (_ready) return true;
    try {
      _tts.setCompletionHandler(() {
        final callback = _onComplete;
        _onComplete = null;
        callback?.call();
      });
      _tts.setCancelHandler(() {
        _onComplete = null;
      });
      _tts.setErrorHandler((message) {
        if (kDebugMode) {
          debugPrint('Discover TTS error: $message');
        }
        _onComplete = null;
      });
      // Slightly conversational pacing; still device-dependent.
      await _tts.setSpeechRate(0.46);
      await _tts.setVolume(1);
      await _tts.setPitch(1.02);
      _ready = true;
    } catch (error) {
      _ready = false;
      if (kDebugMode) {
        debugPrint('Discover TTS init failed: $error');
      }
    }
    return _ready;
  }

  @override
  Future<void> speak({
    required String text,
    required DiscoverAssistantLanguage language,
    VoidCallback? onComplete,
  }) async {
    final ready = await ensureReady();
    // Keep spoken output short and clean so device voices sound conversational.
    final spoken = _naturalness.conciseSpokenReply(text);
    if (!ready || spoken.isEmpty) {
      onComplete?.call();
      return;
    }

    // Cancel any in-flight utterance before starting a new one.
    await stop();
    final epoch = ++_speakEpoch;
    _onComplete = () {
      if (epoch != _speakEpoch) return;
      onComplete?.call();
    };

    final locale = discoverTtsLocaleId(language);
    try {
      await _tts.setLanguage(locale);
    } catch (_) {
      await _tts.setLanguage('en-US');
    }

    // Single utterance avoids overlapping playback on flutter_tts backends.
    // Remote/streaming providers can still use speakableChunks().
    await _tts.speak(spoken);
  }

  @override
  Future<void> stop() async {
    _speakEpoch++;
    _onComplete = null;
    await _tts.stop();
  }

  @override
  void dispose() {
    _speakEpoch++;
    _tts.stop();
  }
}

/// Optional remote Kinyarwanda TTS worker.
class RemoteDiscoverTextToSpeechAdapter implements DiscoverTextToSpeechAdapter {
  RemoteDiscoverTextToSpeechAdapter({this.endpointUrl});

  final String? endpointUrl;

  @override
  String get providerId => 'remote_kinya_tts';

  @override
  bool get supportsKinyarwandaNatively => true;

  @override
  bool get supportsStreamingChunks => false;

  @override
  String get integrationNote => endpointUrl == null || endpointUrl!.isEmpty
      ? 'Remote Kinyarwanda TTS worker URL is not configured. '
          'Evaluate C4IR-RW/kinya-flex-tts vs mbazaNLP for license, latency and tone.'
      : 'Remote TTS endpoint configured at $endpointUrl.';

  @override
  Future<bool> ensureReady() async {
    return endpointUrl != null && endpointUrl!.trim().isNotEmpty;
  }

  @override
  Future<void> speak({
    required String text,
    required DiscoverAssistantLanguage language,
    VoidCallback? onComplete,
  }) async {
    final ready = await ensureReady();
    if (!ready) {
      onComplete?.call();
      throw StateError(integrationNote);
    }
    onComplete?.call();
    throw StateError(
      'Remote Kinyarwanda TTS worker is configured but audio synthesis playback '
      'is not enabled in this Flutter build. Falling back to device TTS.',
    );
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class CascadingDiscoverTextToSpeechAdapter
    implements DiscoverTextToSpeechAdapter {
  CascadingDiscoverTextToSpeechAdapter({
    required List<DiscoverTextToSpeechAdapter> providers,
  }) : _providers = providers;

  final List<DiscoverTextToSpeechAdapter> _providers;
  DiscoverTextToSpeechAdapter? _active;

  @override
  String get providerId => _active?.providerId ?? 'cascading_tts';

  @override
  bool get supportsKinyarwandaNatively =>
      _active?.supportsKinyarwandaNatively ??
      _providers.any((provider) => provider.supportsKinyarwandaNatively);

  @override
  bool get supportsStreamingChunks =>
      _active?.supportsStreamingChunks ??
      _providers.any((provider) => provider.supportsStreamingChunks);

  @override
  String get integrationNote {
    final notes = _providers.map((provider) => provider.integrationNote).join(' | ');
    return 'TTS cascade: $notes';
  }

  @override
  Future<bool> ensureReady() async {
    for (final provider in _providers) {
      if (await provider.ensureReady()) {
        _active = provider;
        return true;
      }
    }
    _active = null;
    return false;
  }

  @override
  Future<void> speak({
    required String text,
    required DiscoverAssistantLanguage language,
    VoidCallback? onComplete,
  }) async {
    Object? lastError;
    for (final provider in _providers) {
      try {
        if (!await provider.ensureReady()) continue;
        _active = provider;
        await provider.speak(
          text: text,
          language: language,
          onComplete: onComplete,
        );
        return;
      } catch (error) {
        lastError = error;
        if (kDebugMode) {
          debugPrint('TTS provider ${provider.providerId} failed: $error');
        }
      }
    }
    onComplete?.call();
    throw StateError(
      lastError?.toString() ?? 'No text-to-speech provider is available.',
    );
  }

  @override
  Future<void> stop() async {
    for (final provider in _providers) {
      await provider.stop();
    }
  }

  @override
  void dispose() {
    for (final provider in _providers) {
      provider.dispose();
    }
  }
}

/// LiveKit real-time voice session boundary.
class DiscoverLiveKitSessionAdapter {
  DiscoverLiveKitSessionAdapter({
    this.tokenEndpointUrl,
    this.wsUrl,
  });

  /// FastAPI endpoint that mints LiveKit room tokens.
  final String? tokenEndpointUrl;
  final String? wsUrl;

  bool get isConfigured =>
      tokenEndpointUrl != null &&
      tokenEndpointUrl!.trim().isNotEmpty &&
      wsUrl != null &&
      wsUrl!.trim().isNotEmpty;

  String get missingDependency =>
      'LiveKit Agents is not configured. Set LIVEKIT_URL, LIVEKIT_API_KEY and '
      'LIVEKIT_API_SECRET on the FastAPI backend, expose /api/v1/discover/livekit/token, '
      'then provide the Flutter app with the token endpoint and LiveKit WebSocket URL.';

  String get integrationNote => isConfigured
      ? 'LiveKit token endpoint is configured, but the Flutter LiveKit room client '
          'is not linked in this build. On-device voice remains the active path.'
      : missingDependency;

  Future<Map<String, String>> createSession({
    required String identity,
    String roomPrefix = 'tradesquare-discover',
  }) async {
    if (!isConfigured) {
      throw StateError(missingDependency);
    }
    // Token minting and room join require livekit_client + valid credentials.
    // Refuse to invent a connected session.
    throw StateError(integrationNote);
  }
}

DiscoverSpeechToTextAdapter createDefaultDiscoverSpeechAdapter({
  String? remoteSttUrl,
}) {
  return CascadingDiscoverSpeechToTextAdapter(
    providers: [
      RemoteDiscoverSpeechToTextAdapter(endpointUrl: remoteSttUrl),
      DeviceDiscoverSpeechToTextAdapter(),
    ],
  );
}

DiscoverTextToSpeechAdapter createDefaultDiscoverTtsAdapter({
  String? remoteTtsUrl,
}) {
  return CascadingDiscoverTextToSpeechAdapter(
    providers: [
      RemoteDiscoverTextToSpeechAdapter(endpointUrl: remoteTtsUrl),
      DeviceDiscoverTextToSpeechAdapter(),
    ],
  );
}
