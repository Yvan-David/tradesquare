/// Helpers that make spoken assistant replies sound conversational.
///
/// These do not claim native-speaker quality for Kinyarwanda TTS. They only
/// clean formatting and chunk text into speakable phrases.
class DiscoverSpeechNaturalness {
  const DiscoverSpeechNaturalness();

  /// Strip markdown/JSON/tool noise and normalize pauses for speech.
  String sanitizeForSpeech(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    // Drop fenced code / JSON-looking blobs.
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    text = text.replaceAll(RegExp(r'`[^`]+`'), ' ');
    text = text.replaceAll(RegExp(r'\{[^{}]*\}'), ' ');
    text = text.replaceAll(RegExp(r'\[[^\[\]]*\]'), ' ');

    // Remove markdown emphasis and bullets.
    text = text.replaceAll(RegExp(r'[*_#>-]+'), ' ');
    text = text.replaceAll(RegExp(r'https?://\S+'), ' ');
    text = text.replaceAll('…', '.');
    text = text.replaceAll('—', ', ');
    text = text.replaceAll('–', ', ');

    // Expand common symbols.
    text = text.replaceAll('%', ' percent');
    text = text.replaceAll('&', ' and ');
    text = text.replaceAll('@', ' at ');

    // Collapse whitespace.
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Prefer a short spoken answer for simple replies; keep detail in chat UI.
  String conciseSpokenReply(String raw, {int maxSentences = 2}) {
    final cleaned = sanitizeForSpeech(raw);
    if (cleaned.isEmpty) return '';
    final sentences = splitSentences(cleaned);
    if (sentences.isEmpty) return cleaned;
    return sentences.take(maxSentences).join(' ').trim();
  }

  List<String> splitSentences(String text) {
    final cleaned = sanitizeForSpeech(text);
    if (cleaned.isEmpty) return const [];
    final parts = cleaned
        .split(RegExp(r'(?<=[\.\!\?])\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? [cleaned] : parts;
  }

  /// Chunk long replies so TTS can start sooner and pause naturally.
  List<String> speakableChunks(String raw, {int maxChars = 140}) {
    final sentences = splitSentences(raw);
    if (sentences.isEmpty) return const [];

    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final sentence in sentences) {
      if (buffer.isEmpty) {
        buffer.write(sentence);
        continue;
      }
      if (buffer.length + sentence.length + 1 <= maxChars) {
        buffer.write(' ');
        buffer.write(sentence);
      } else {
        chunks.add(buffer.toString());
        buffer
          ..clear()
          ..write(sentence);
      }
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString());
    return chunks;
  }

  bool isProgressOnly(String text) {
    final cleaned = text.trim();
    return cleaned == '…' ||
        cleaned.endsWith('…') ||
        cleaned.toLowerCase().contains('thinking') ||
        cleaned.toLowerCase().contains('ndatekereza') ||
        cleaned.toLowerCase().contains('nafikiri') ||
        cleaned.toLowerCase().contains('réflexion');
  }
}
