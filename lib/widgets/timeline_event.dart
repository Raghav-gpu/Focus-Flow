import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focus/widgets/task_detail_popup.dart';
import 'package:intl/intl.dart';

class TimelineEvent extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTaskUpdated;
  final String userId;

  const TimelineEvent({
    Key? key,
    required this.task,
    required this.onTaskUpdated,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final startTime = (task['start'] as Timestamp).toDate();
    final cardOpacity = task['status'] == 'Completed' ? 0.58 : 1.0;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withOpacity(0.7),
          builder: (context) => TaskDetailPopup(
            task: task,
            userId: userId,
            onTaskUpdated: onTaskUpdated,
          ),
        ).then((_) => onTaskUpdated());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              child: Opacity(
                opacity: cardOpacity,
                child: Text(
                  DateFormat.jm().format(startTime), // e.g., "11:23 AM"
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey[300],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Opacity(
                opacity: cardOpacity,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getStatusColor(task['status']).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(task['status']).withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(task['priority']),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                task['priority'].toString()[0].toUpperCase() +
                                    task['priority'].toString().substring(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              task['status'],
                              style: TextStyle(
                                color: _getStatusColor(task['status']),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task['title'].toString()[0].toUpperCase() +
                              task['title'].toString().substring(1),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: task['status'] == 'Completed'
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.grey.withOpacity(0.9),
                            decorationThickness: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
      case 'To Do': // Add 'To Do' as valid status
        return Colors.blueAccent;
      case 'Completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
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
}
