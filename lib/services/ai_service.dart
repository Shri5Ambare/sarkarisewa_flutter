// lib/services/ai_service.dart
import 'package:cloud_functions/cloud_functions.dart';

class AiService {
  final _functions = FirebaseFunctions.instance;

  /// Sends the chat history to the server-side Cloud Function (chatViva)
  /// which securely holds the API key. No secrets leave the backend.
  Future<String> sendChatMessage(List<Map<String, String>> history, int courseId) async {
    if (history.isEmpty) return "Error: No message to send.";

    final callable = _functions.httpsCallable(
      'chatViva',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
    );

    final result = await callable.call({
      'history': history,
      'courseId': courseId,
    });

    final reply = result.data['reply']?.toString().trim() ?? 'No reply from AI.';
    return reply;
  }
}
