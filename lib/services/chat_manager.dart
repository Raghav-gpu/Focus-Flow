class ChatManager {
  static final ChatManager _instance = ChatManager._internal();
  factory ChatManager() => _instance;
  ChatManager._internal();

  List<Map<String, String>> messages = [];
  List<Map<String, String>> conversationHistory = [];

  void clearChat() {
    messages.clear();
    conversationHistory.clear();
  }
}
