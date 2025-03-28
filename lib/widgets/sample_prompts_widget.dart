import 'package:flutter/material.dart';

// Reusable InfiniteScrollWidget
class InfiniteScrollWidget extends StatefulWidget {
  final List<Map<String, String>> prompts;
  final double scrollSpeed; // Pixels per second

  const InfiniteScrollWidget({
    super.key,
    required this.prompts,
    this.scrollSpeed = 120.0,
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
      while (true) {
        if (!mounted || !_scrollController.hasClients) return;
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
      height: 50,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.prompts.length * 3, // Repeat for seamless effect
        itemBuilder: (context, index) {
          final prompt = widget.prompts[index % widget.prompts.length];
          return _buildPrompt('${prompt['emoji']} ${prompt['text']}');
        },
      ),
    );
  }

  Widget _buildPrompt(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}

// Example usage on a page
class InfiniteScrollPage extends StatelessWidget {
  const InfiniteScrollPage({super.key});

  static const List<Map<String, String>> _prompts = [
    {'text': 'Build my daily schedule', 'emoji': '📅'},
    {'text': 'Boost my focus now', 'emoji': '🚀'},
    {'text': 'Streamline my day', 'emoji': '⏳'},
    {'text': 'Sort my tasks by urgency', 'emoji': '📋'},
    {'text': 'Plan a focused week', 'emoji': '🗓️'},
    {'text': 'Simplify my workload', 'emoji': '🧹'},
    {'text': 'Define my focus goals', 'emoji': '🎯'},
    {'text': 'Cut distractions today', 'emoji': '🔇'},
    {'text': 'Align my priorities', 'emoji': '⚖️'},
    {'text': 'Schedule my breaks', 'emoji': '☕'},
    {'text': 'Track my progress', 'emoji': '📊'},
    {'text': 'Organize my projects', 'emoji': '🗂️'},
    {'text': 'Clear my mental clutter', 'emoji': '🧠'},
    {'text': 'Set deadlines for me', 'emoji': '⏰'},
    {'text': 'Balance my workload', 'emoji': '⚖️'},
    {'text': 'Focus on one task now', 'emoji': '🔍'},
    {'text': 'Plan my study session', 'emoji': '📚'},
    {'text': 'Reduce my stress today', 'emoji': '🧘'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: InfiniteScrollWidget(
          prompts: _prompts,
          scrollSpeed: 100.0, // Optional: can be customized
        ),
      ),
    );
  }
}
