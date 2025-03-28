import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:focus/pages/calendar_task_page.dart';
import 'package:focus/services/task_service.dart'; // Import TaskService
import 'package:intl/intl.dart';

class CompactTaskList extends StatefulWidget {
  final String userId;

  const CompactTaskList({Key? key, required this.userId}) : super(key: key);

  @override
  _CompactTaskListState createState() => _CompactTaskListState();
}

class _CompactTaskListState extends State<CompactTaskList> {
  final TaskService _taskService = TaskService(); // Add TaskService

  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orangeAccent;
      case 'Low':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _taskService.getTasks(widget.userId), // Use TaskService
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.blueAccent,
              strokeWidth: 2,
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Error loading tasks: ${snapshot.error}',
            style: const TextStyle(color: Colors.redAccent),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            'No tasks to do!',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          );
        }

        // Sort tasks by date and take the first 3
        final tasks = snapshot.data!
          ..sort((a, b) =>
              (a['date'] as Timestamp).compareTo(b['date'] as Timestamp));
        final limitedTasks = tasks.take(3).toList();

        return Container(
          width: screenWidth * 0.5,
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 16,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 16,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: limitedTasks
                .map((task) => TaskItem(
                      task: task,
                      priorityColor:
                          getPriorityColor(task['priority'] ?? 'Low'),
                      onCardTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) =>
                                CalendarTaskPage(userId: widget.userId),
                          ),
                        );
                      },
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class TaskItem extends StatelessWidget {
  final Map<String, dynamic> task;
  final Color priorityColor;
  final VoidCallback onCardTap;

  const TaskItem({
    Key? key,
    required this.task,
    required this.priorityColor,
    required this.onCardTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final taskDate =
        (task['date'] as Timestamp?)?.toDate().toLocal() ?? DateTime.now();

    return GestureDetector(
      onTap: onCardTap,
      child: Padding(
        padding: const EdgeInsets.only(
            bottom: 12), // Fix this typo: should be "bottom"
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5,
              height: 50,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] != null
                        ? '${task['title'][0].toUpperCase()}${task['title'].substring(1)}'
                        : 'Untitled',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat.MMMd().format(taskDate)} • ${DateFormat.Hm().format(taskDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
