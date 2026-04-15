import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';

enum MessageRole { user, assistant }

class ChatMessage {
  String text;
  final MessageRole role;
  ChatMessage({required this.text, required this.role});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      role: MessageRole.assistant,
      text: "Hi! I'm Aegis AI 🤖 Ask me anything about your insurance.",
    ),
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  String _workerId = 'W001';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['worker_id'] is String) {
        setState(() {
          _workerId = args['worker_id'] as String;
        });
      }
      _scrollToBottom();
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isTyping) return;

    final text = _controller.text.trim();

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(role: MessageRole.user, text: text));
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    final response = await ChatService.generateResponse(_workerId, text);

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(role: MessageRole.assistant, text: response));
      _isTyping = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 200), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize: 0.6,
      maxChildSize: 0.95,

      /// 🔥 FIX: Wrap with Material
      builder: (context, scrollController) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),

        child: Column(
          children: [
            _buildHeader(),

            /// MESSAGES
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _buildMessage(_messages[i]),
              ),
            ),

            if (_isTyping) _typingIndicator(),

            _buildInput(),
          ],
        ),
      ),
    );
  }

  /// =======================================================
  /// 🔷 HEADER (GUIDEWIRE STYLE)
  /// =======================================================
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Image.asset('assets/main_logo.png', height: 26),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'Aegis Assistant',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),

          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          )
        ],
      ),
    );
  }

  /// =======================================================
  /// 💬 MESSAGE
  /// =======================================================
  Widget _buildMessage(ChatMessage msg) {
    final isUser = msg.role == MessageRole.user;

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.inter(
            color: isUser ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// =======================================================
  /// ✍ INPUT
  /// =======================================================
  Widget _buildInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            CircleAvatar(
              backgroundColor:
                  _isTyping ? Colors.grey : AppColors.blue,
              child: _isTyping
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white),
                      onPressed: _sendMessage,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// =======================================================
  /// ⏳ TYPING
  /// =======================================================
  Widget _typingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text("Aegis is typing...",
            style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
