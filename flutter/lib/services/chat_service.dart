import '../services/api_service.dart';

class ChatService {
  static Future<String> generateResponse(String workerId, String userInput) async {
    try {
      final data = await ApiService.chatWithAI(workerId, userInput);
      return data['reply'] ?? 'No response';
    } catch (_) {
      return 'Chatbot unavailable';
    }
  }
}
