import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  static const String _base =
      "https://aegis-backend-i4z5.onrender.com";

  static Future<String> generateResponse(String userInput) async {
    try {
      final res = await http.post(
        Uri.parse("$_base/chat"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "message": userInput,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data["reply"] ?? "No response";
      } else {
        return "Server error 😅";
      }
    } catch (e) {
      return "Chatbot unavailable 😅";
    }
  }
}