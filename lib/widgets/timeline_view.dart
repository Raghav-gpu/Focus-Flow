import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'timeline_event.dart';

class TimelineView extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final VoidCallback onTaskUpdated;
  final String userId;

  const TimelineView({
    Key? key,
    required this.tasks,
    required this.onTaskUpdated,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sortedTasks = List.from(tasks)
      ..sort((a, b) =>
          (a['start'] as Timestamp).compareTo(b['start'] as Timestamp));

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: sortedTasks.length,
        itemBuilder: (context, index) {
          final task = sortedTasks[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: TimelineEvent(
                  userId: userId,
                  task: task,
                  onTaskUpdated: onTaskUpdated,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
