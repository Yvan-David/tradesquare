import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper around speech_to_text so Discover can listen for voice queries.
class DiscoverVoiceListener {
  DiscoverVoiceListener();

  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  bool _initializing = false;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _ready;

  Future<bool> ensureReady() async {
    if (_ready) return true;
    if (_initializing) return _ready;
    _initializing = true;
    try {
      _ready = await _speech.initialize(
        onError: (error) {
          if (kDebugMode) {
            debugPrint('Discover voice error: ${error.errorMsg}');
          }
        },
        onStatus: (status) {
          if (kDebugMode) {
            debugPrint('Discover voice status: $status');
          }
        },
      );
    } catch (error) {
      _ready = false;
      if (kDebugMode) {
        debugPrint('Discover voice init failed: $error');
      }
    } finally {
      _initializing = false;
    }
    return _ready;
  }

  Future<void> start({
    required String localeId,
    required ValueChanged<String> onPartial,
    required ValueChanged<String> onFinal,
  }) async {
    final ready = await ensureReady();
    if (!ready) {
      throw StateError('Voice listening is not available on this device.');
    }
    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        if (result.finalResult) {
          onFinal(text);
        } else {
          onPartial(text);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  void dispose() {
    _speech.cancel();
  }
}
