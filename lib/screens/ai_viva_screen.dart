// lib/screens/ai_viva_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/responsive_scaffold.dart';
import '../widgets/app_button.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../services/tts_service.dart';
import '../services/location_service.dart';

class AIVivaScreen extends StatefulWidget {
  const AIVivaScreen({super.key});
  @override
  State<AIVivaScreen> createState() => _AIVivaScreenState();
}

class _AIVivaScreenState extends State<AIVivaScreen> {
  int _selectedCourse = 1;
  bool _sessionActive = false;
  bool _isListening = false;
  bool _isAiTyping = false;

  final _aiService = AiService();
  final _db = FirestoreService();
  final SpeechToText _speech = SpeechToText();
  final TtsService _tts = TtsService();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  
  final List<Map<String, String>> _chat = [];

  @override
  void initState() {
    super.initState();
    _tts.init();
  }


  @override
  void dispose() {
    _tts.dispose();
    _speech.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startSession() async {
    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device.'), behavior: SnackBarBehavior.floating),
        );
      }
    }

    setState(() {
      _sessionActive = true;
      _chat.clear();
      // Invisible system prompt to kick off the conversation on the backend
      _chat.add({'role': 'system', 'content': 'You are an examiner for Nepal Lok Sewa. Introduce yourself briefly and ask the first question for Course $_selectedCourse.'});
    });
    _getAiResponse();
  }

  Future<void> _getAiResponse() async {
    if (!mounted) return;
    setState(() => _isAiTyping = true);
    try {
      final reply = await _aiService.sendChatMessage(_chat, _selectedCourse);
      if (!mounted) return;
      setState(() {
        _chat.add({'role': 'assistant', 'content': reply});
        _isAiTyping = false;
      });
      _scrollToBottom();
      await _tts.speak(reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAiTyping = false;
        _chat.add({'role': 'assistant', 'content': 'Oops, I lost connection. Error details: $e'});
      });
      _scrollToBottom();
    }
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _chat.add({'role': 'user', 'content': text.trim()});
      _textCtrl.clear();
    });
    _scrollToBottom();
    _getAiResponse();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            _textCtrl.text = result.recognizedWords;
            if (result.finalResult) {
              setState(() => _isListening = false);
              _sendMessage(result.recognizedWords);
            }
          },
        );
      }
    }
  }

  Future<void> _endSession() async {
    await _tts.stop();
    await _speech.stop();
    setState(() {
      _isAiTyping = true;
      _chat.add({'role': 'user', 'content': 'I am done. Please end the session and give me a score out of 10 and brief advice.'});
    });

    try {
      final rawReply = await _aiService.sendChatMessage(_chat, _selectedCourse);
      
      int parsedScore = 5;
      String displayReply = rawReply;
      
      try {
        final RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
        final match = jsonRegex.firstMatch(rawReply);
        if (match != null) {
          final jsonData = jsonDecode(match.group(0)!);
          parsedScore = (jsonData['score'] is num) ? (jsonData['score'] as num).toInt() : 5;
          displayReply = jsonData['feedback']?.toString() ?? rawReply;
        } else {
          final scoreMatch = RegExp(r'Score[:\s]+(\d+)\s*/\s*10', caseSensitive: false).firstMatch(rawReply);
          if (scoreMatch != null) parsedScore = int.tryParse(scoreMatch.group(1) ?? '5') ?? 5;
        }
      } catch (_) {}

      setState(() {
        _chat.add({'role': 'assistant', 'content': displayReply});
        _isAiTyping = false;
      });
      _scrollToBottom();
      await _tts.speak(displayReply);
      
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        final loc = await LocationService.getCurrentLocation();
        await _db.saveVivaResult(uid, _selectedCourse, parsedScore, displayReply, location: loc);
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.navyMid,
            title: Text('Session Finished (Score: $parsedScore/10)', style: const TextStyle(color: AppColors.textPrimary)),
            content: Text(displayReply, style: const TextStyle(color: AppColors.textMuted)),
            actions: [
              TextButton(onPressed: () {Navigator.pop(ctx); setState(() => _sessionActive = false);}, child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _sessionActive = false;
        _isAiTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LocaleProvider>().lang;
    final enrolled = List<String>.from(auth.profile?['enrolled'] ?? []);
    final hasAccess = auth.tier == 'gold' || auth.tier == 'silver' || enrolled.isNotEmpty;

    // Filter out 'system' messages for the UI
    final visibleChat = _chat.where((m) => m['role'] != 'system').toList();

    return ResponsiveScaffold(
      currentIndex: 1,
      appBar: AppBar(title: Text(t('viva.title', lang))),
      body: !hasAccess
        ? _lockedView(lang)
        : Column(
            children: [
              if (!_sessionActive)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _selectedCourse,
                        dropdownColor: AppColors.navyMid,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(labelText: t('viva.selectCourse', lang)),
                        items: List.generate(4, (i) => DropdownMenuItem(value: i + 1, child: Text('Course ${i + 1}'))),
                        onChanged: (v) => setState(() => _selectedCourse = v!),
                      ),
                      const SizedBox(height: 20),
                      AppButton(label: t('viva.start', lang), onPressed: _startSession, fullWidth: true, icon: Icons.mic),
                    ],
                  ),
                ),

              if (_sessionActive) ...[
                // Chat List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleChat.length + (_isAiTyping ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == visibleChat.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.saffron, strokeWidth: 2)),
                          ),
                        );
                      }
                      final msg = visibleChat[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.navyLight : AppColors.saffron.withAlpha(38),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isUser ? AppColors.border : AppColors.saffron.withAlpha(77)),
                          ),
                          child: Text(
                            msg['content'] ?? '',
                            style: TextStyle(color: isUser ? AppColors.textPrimary : AppColors.saffron, fontSize: 13),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Input Area
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.navyMid,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textCtrl,
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: _isListening ? 'Listening...' : 'Type your answer...',
                                  hintStyle: TextStyle(color: _isListening ? AppColors.emerald : AppColors.textMuted),
                                  filled: true,
                                  fillColor: AppColors.cardBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSubmitted: _sendMessage,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _toggleListening,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isListening ? AppColors.emerald : AppColors.saffron,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: AppColors.navy),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _sendMessage(_textCtrl.text),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(color: AppColors.navyLight, shape: BoxShape.circle),
                                child: const Icon(Icons.send, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _isAiTyping ? null : _endSession,
                              icon: const Icon(Icons.stop_circle, color: AppColors.ruby),
                              label: const Text('End Interview', style: TextStyle(color: AppColors.ruby, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
    );
  }

  Widget _lockedView(String lang) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: AppColors.saffron.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.saffron.withAlpha(60)),
            ),
            child: const Center(child: Text('🔒', style: TextStyle(fontSize: 42))),
          ),
          const SizedBox(height: 24),
          Text(t('viva.locked', lang),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'Enroll in a course to practice AI-powered mock viva sessions with real-time feedback.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Feature bullets
          ...[
            ('🎤', 'Voice-based Q&A with AI examiner'),
            ('📊', 'Instant scoring out of 10'),
            ('🧠', 'Personalized improvement tips'),
          ].map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text(item.$2, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          )),
          const SizedBox(height: 32),
          AppButton(
            label: 'Explore Courses →',
            onPressed: () => context.go('/dashboard'),
            fullWidth: false,
            icon: Icons.school_outlined,
          ),
        ],
      ),
    ),
  );
}
