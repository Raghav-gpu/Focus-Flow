import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:focus/services/ai_service.dart';
import 'package:focus/services/chat_manager.dart';
import 'package:focus/services/task_service.dart';
import 'package:focus/widgets/focus_animation.dart';
import 'package:focus/widgets/message_bubble.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class ChatPage extends StatefulWidget {
  final String userId;

  const ChatPage({Key? key, required this.userId}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  late AnimationController _promptController;
  late Animation<double> _promptAnimation;
  final TaskService _taskService = TaskService();
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = true;
  String _currentResponse = '';
  final ChatManager _chatManager = ChatManager();
  late stt.SpeechToText _speech;
  bool _isListening = false;

  final List<Map<String, String>> _prompts = [
    {'text': 'Build my daily schedule for today', 'emoji': '📅'},
    {'text': 'Build my schedule for tomorrow', 'emoji': '📅'},
    {'text': 'Build my schedule for next week', 'emoji': '📅'},
    {'text': 'Boost my focus now', 'emoji': '🚀'},
    {'text': 'Plan my study session', 'emoji': '📚'},
    {'text': 'Set my daily goals', 'emoji': '🎯'},
    {'text': 'Organize my tasks now', 'emoji': '📋'},
    {'text': 'Schedule a quick break', 'emoji': '☕'},
    {'text': 'Prioritize my workload today', 'emoji': '⚖️'},
    {'text': 'Track my progress today', 'emoji': '📊'},
    {'text': 'Clear my distractions now', 'emoji': '🔇'},
    {'text': 'Create a focus playlist', 'emoji': '🎶'},
    {'text': 'Plan my next meeting', 'emoji': '📞'},
    {'text': 'Simplify my day now', 'emoji': '🧹'},
    {'text': 'Set a task deadline', 'emoji': '⏰'},
    {'text': 'Review my week ahead', 'emoji': '🗓️'},
    {'text': 'Start a focus timer', 'emoji': '⏳'},
    {'text': 'Assign my task priorities', 'emoji': '⭐'},
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _promptController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _promptAnimation = Tween<double>(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(parent: _promptController, curve: Curves.linear),
    );
    _scrollController.addListener(() {
      setState(() {
        _isAtBottom = _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 10;
      });
    });
  }

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final userMessage = _messageController.text;
      _messageController.clear();
      setState(() {
        _chatManager.messages.add({
          'sender': 'user',
          'text': userMessage,
          'time': DateTime.now().toString(),
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      });

      String promptToSend = userMessage;
      final now = DateTime.now();
      final timeString = DateFormat('HH:mm').format(now);
      final dateString = DateFormat('ddMMyyyy').format(now);
      final dayString = DateFormat('EEEE').format(now);
      final yearString = DateFormat('yyyy').format(now);
      final tasksSnapshot = await _taskService.getTasks(widget.userId).first;
      final tasks = tasksSnapshot;
      final tasksString = tasks.map((task) {
        if (task == null)
          return '- Untitled (No description), Priority: Unknown, Status: Unknown, Due: No date specified';
        final date = task['date'] != null
            ? (task['date'] as Timestamp).toDate().toString()
            : 'No date specified';
        final title = task['title']?.toString() ?? 'Untitled';
        final description = task['description']?.toString() ?? 'No description';
        final priority = task['priority']?.toString() ?? 'Unknown';
        final status = task['status']?.toString() ?? 'Unknown';
        return '- $title ($description), Priority: $priority, Status: $status, Due: $date';
      }).join('\n');
      promptToSend =
          '$userMessage\n\nCurrent date: $dateString\nCurrent day: $dayString\nCurrent year: $yearString\nCurrent time: $timeString\nExisting tasks:\n$tasksString';

      _chatManager.conversationHistory
          .add({'role': 'user', 'content': promptToSend});
      _currentResponse = '';
      setState(() {
        _chatManager.messages.add({
          'sender': 'ai',
          'text': '',
          'time': DateTime.now().toString(),
        });
      });

      await Future.delayed(const Duration(seconds: 1));
      final stream =
          GeminiService.sendMessage(_chatManager.conversationHistory);
      String filteredResponse = '';
      await for (final chunk in stream) {
        _currentResponse += chunk;
        filteredResponse = _currentResponse.trim();
        setState(() {
          _chatManager.messages.last['text'] = filteredResponse;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
            );
          });
        });
      }
      _chatManager.conversationHistory
          .add({'role': 'assistant', 'content': _currentResponse});
    }
  }

  void _handlePromptTap(String text) {
    _messageController.text = text;
    _sendMessage();
  }

  void _startNewChat() {
    setState(() {
      _chatManager.clearChat();
    });
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Speech-to-Text with Permission Handling
  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return false;
    } else if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable microphone permission in settings'),
        ),
      );
      await openAppSettings();
      return false;
    }
    return false;
  }

  void _startListening() async {
    if (_isListening) return;

    final permissionGranted = await _requestMicrophonePermission();
    if (!permissionGranted) return;

    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _messageController.text = result.recognizedWords;
          });
          if (result.finalResult) {
            _stopListening();
          }
        },
        localeId: 'en_US', // Adjust as needed
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _onAddToCalendar(
      List<Map<String, dynamic>> scheduleRows, String userId) async {
    debugPrint('Adding to calendar: $scheduleRows');
    if (scheduleRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No schedule rows to add')),
      );
      return;
    }

    for (var row in scheduleRows) {
      final dayString = row['day']!.trim();
      final time = row['time']!.trim();
      final activity = row['activity']!.trim();
      final duration = row['duration']!.trim();
      final priority = row['priority']!.trim();
      DateTime? taskDate = row['date'] as DateTime?;

      if (taskDate == null) {
        debugPrint('Warning: No date parsed for "$dayString", skipping');
        continue;
      }

      final timeParts = time.split(':');
      if (timeParts.length < 2) {
        debugPrint('Invalid time format for "$time", skipping');
        continue;
      }

      final hour = int.tryParse(timeParts[0]);
      final minuteParts = timeParts[1].split(' ');
      final minute = int.tryParse(minuteParts[0]);
      if (hour == null || minute == null) {
        debugPrint(
            'Failed to parse time "$time" into hour and minute, skipping');
        continue;
      }

      final period = minuteParts.length > 1 ? minuteParts[1].toUpperCase() : '';
      final adjustedHour = period == 'PM' && hour != 12
          ? hour + 12
          : (period == 'AM' && hour == 12 ? 0 : hour);

      final startTime = DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day,
        adjustedHour,
        minute,
      );
      debugPrint('Final startTime: $startTime');

      final parts = activity.split(':');
      final title = parts[0].trim();
      final description = parts.length > 1 ? parts[1].trim() : 'No description';

      try {
        await _taskService.addTask(widget.userId, {
          'title': title,
          'description': description,
          'date': Timestamp.fromDate(startTime),
          'priority': priority,
          'status': 'To Do',
        });
        debugPrint('Task added successfully: $title at $startTime');
      } catch (e) {
        debugPrint('Failed to add task: $title - Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add task: $e')),
        );
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule added to calendar!')),
    );
  }

  void _onEditTask(String task, String time, String priority, String userId) {
    debugPrint(
        'Editing task: $task, Time: $time, Priority: $priority, UserID: $userId');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'FocusFlow AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.blueAccent,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.blueAccent.withOpacity(0.3),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedOpacity(
            opacity: _chatManager.messages.isNotEmpty ? 1 : 0.0,
            duration: const Duration(seconds: 1),
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/chatpagebg.png'),
                  fit: BoxFit.cover,
                  opacity: 0.73,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black87.withOpacity(0.9),
                ],
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: _chatManager.messages.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            child: AnimatedOpacity(
                              opacity: 1.0,
                              duration: const Duration(milliseconds: 500),
                              child: SizedBox(
                                width: screenWidth * 0.8,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 250,
                                      child: FocusAnimation(),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Welcome to FocusFlow AI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.blueAccent,
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Start boosting your focus now!',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    InfiniteScrollWidget(prompts: _prompts),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _chatManager.messages.length,
                          itemBuilder: (context, index) {
                            final message = _chatManager.messages[index];
                            return AnimatedOpacity(
                              opacity: 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Align(
                                alignment: message['sender'] == 'user'
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: MessageBubble(
                                  message: message,
                                  onAddToCalendar: _onAddToCalendar,
                                  onEditTask: _onEditTask,
                                  userId: widget.userId,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? 'Listening...'
                              : 'Type a message...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueAccent.withOpacity(0.9),
                            Colors.blue.withOpacity(0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.redAccent : Colors.white,
                        ),
                        onPressed:
                            _isListening ? _stopListening : _startListening,
                        splashRadius: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueAccent.withOpacity(0.9),
                            Colors.blue.withOpacity(0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                        splashRadius: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_isAtBottom)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: _scrollToBottom,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blueAccent.withOpacity(0.8),
                        Colors.blue.withOpacity(0.6),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.arrow_downward, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// InfiniteScrollWidget remains unchanged
class InfiniteScrollWidget extends StatefulWidget {
  final List<Map<String, String>> prompts;
  final double scrollSpeed;

  const InfiniteScrollWidget({
    super.key,
    required this.prompts,
    this.scrollSpeed = 100.0,
  });

  @override
  _InfiniteScrollWidgetState createState() => _InfiniteScrollWidgetState();
}

class _InfiniteScrollWidgetState extends State<InfiniteScrollWidget> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    Future.delayed(Duration.zero, () async {
      while (mounted && _scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(
              seconds: (_scrollController.position.maxScrollExtent /
                      widget.scrollSpeed)
                  .round()),
          curve: Curves.linear,
        );
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.prompts.length * 3,
        itemBuilder: (context, index) {
          final prompt = widget.prompts[index % widget.prompts.length];
          return _buildPrompt('${prompt['emoji']} ${prompt['text']}');
        },
      ),
    );
  }

  Widget _buildPrompt(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent.withOpacity(0.3),
            Colors.black.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
