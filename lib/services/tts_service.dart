// lib/services/tts_service.dart
//
// Uses ElevenLabs cloud TTS for a natural, human-sounding voice.
// Falls back to flutter_tts (device engine) if ElevenLabs is not configured.
//
// To enable ElevenLabs:
//   1. Sign up free at https://elevenlabs.io (10,000 chars/month free)
//   2. Copy your API key from https://elevenlabs.io/profile
//   3. Paste it in the _elevenLabsApiKey field below
//   4. Optionally pick a different voice from https://elevenlabs.io/voice-library
//      and update _voiceId.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class TtsService {
  // ── ElevenLabs config ────────────────────────────────────────────────────
  // Set via --dart-define=ELEVENLABS_API_KEY=... only if you intentionally
  // accept client-side key exposure risk. Empty value keeps device fallback.
  static const String _elevenLabsApiKey = String.fromEnvironment('ELEVENLABS_API_KEY', defaultValue: '');
  static const String _voiceId = 'pNInz6obpgDQGcFmaJgB'; // "Adam" – clear, professional

  // ── internals ─────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _fallbackTts = FlutterTts();
  bool _fallbackReady = false;

  // ─── lifecycle ────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_elevenLabsApiKey.isEmpty) {
      await _initFallback();
    }
  }

  Future<void> _initFallback() async {
    await _fallbackTts.setLanguage('en-US');
    await _fallbackTts.setSpeechRate(0.42);
    await _fallbackTts.setVolume(1.0);
    await _fallbackTts.setPitch(1.0);

    // Try to find the best voice on the device
    try {
      final voices = await _fallbackTts.getVoices;
      if (voices != null && voices is List) {
        // Priority: enhanced/premium > network > default
        final ranked = voices.where((v) {
          final locale = (v['locale'] ?? '').toString().toLowerCase();
          return locale.startsWith('en');
        }).toList()
          ..sort((a, b) {
            // prefer voices whose name contains quality hints
            int score(dynamic v) {
              final name = (v['name'] ?? '').toString().toLowerCase();
              if (name.contains('premium') || name.contains('enhanced') || name.contains('neural')) return 3;
              if (name.contains('network') || name.contains('online')) return 2;
              return 1;
            }
            return score(b).compareTo(score(a));
          });

        if (ranked.isNotEmpty) {
          await _fallbackTts.setVoice({
            'name': ranked.first['name'].toString(),
            'locale': ranked.first['locale'].toString(),
          });
          debugPrint('[TTS] Using voice: ${ranked.first['name']}');
        }
      }
    } catch (_) {}
    _fallbackReady = true;
  }

  // ─── public API ───────────────────────────────────────────────────────────

  Future<void> speak(String rawText) async {
    final text = _cleanForSpeech(rawText);
    if (text.isEmpty) return;

    if (_elevenLabsApiKey.isNotEmpty) {
      await _speakWithElevenLabs(text);
    } else {
      if (!_fallbackReady) await _initFallback();
      await _speakWithFallback(text);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    await _fallbackTts.stop();
  }

  void dispose() {
    _player.dispose();
    _fallbackTts.stop();
  }

  // ─── ElevenLabs ──────────────────────────────────────────────────────────

  Future<void> _speakWithElevenLabs(String text) async {
    try {
      // Split long text into chunks ≤ 500 chars (ElevenLabs recommends this)
      final chunks = _splitIntoChunks(text, 500);
      for (final chunk in chunks) {
        final bytes = await _fetchAudio(chunk);
        if (bytes != null) {
          await _playBytes(bytes);
        } else {
          // fallback for this chunk
          await _speakWithFallback(chunk);
        }
      }
    } catch (e) {
      debugPrint('[TTS] ElevenLabs error: $e – falling back');
      await _speakWithFallback(text);
    }
  }

  Future<Uint8List?> _fetchAudio(String text) async {
    final response = await http.post(
      Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
      headers: {
        'xi-api-key': _elevenLabsApiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: '''{
        "text": ${_jsonString(text)},
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {
          "stability": 0.5,
          "similarity_boost": 0.75,
          "style": 0.35,
          "use_speaker_boost": true
        }
      }''',
    );

    if (response.statusCode == 200) return response.bodyBytes;
    debugPrint('[TTS] ElevenLabs HTTP ${response.statusCode}: ${response.body}');
    return null;
  }

  Future<void> _playBytes(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/tts_chunk.mp3');
    await file.writeAsBytes(bytes);
    await _player.setFilePath(file.path);
    await _player.play();
    // Wait until done
    await _player.processingStateStream
        .firstWhere((s) => s == ProcessingState.completed);
  }

  // ─── Fallback (flutter_tts) ───────────────────────────────────────────────

  Future<void> _speakWithFallback(String text) async {
    // flutter_tts.speak returns when speech finishes (on most platforms)
    await _fallbackTts.awaitSpeakCompletion(true);
    await _fallbackTts.speak(text);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Removes markdown formatting so TTS doesn't read "asterisk" etc.
  String _cleanForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')   // bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')        // italic
        .replaceAll(RegExp(r'`[^`]*`'), '')              // inline code
        .replaceAll(RegExp(r'#{1,6}\s*'), '')            // headings
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1') // links
        .replaceAll(RegExp(r'[-*+]\s'), '')              // list bullets
        .replaceAll(RegExp(r'\n{2,}'), '. ')            // paragraph breaks → pause
        .replaceAll('\n', ', ')                         // single newlines → brief pause
        .trim();
  }

  List<String> _splitIntoChunks(String text, int maxLen) {
    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[.?!])\s+'));
    var current = '';
    for (final s in sentences) {
      if ((current + s).length > maxLen && current.isNotEmpty) {
        chunks.add(current.trim());
        current = s;
      } else {
        current += ' $s';
      }
    }
    if (current.trim().isNotEmpty) chunks.add(current.trim());
    return chunks.isEmpty ? [text] : chunks;
  }

  String _jsonString(String s) => '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
}
