import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:focus/pages/calendar_task_page.dart';
import 'package:focus/services/task_service.dart';
import 'package:intl/intl.dart';

class TopTasksWidget extends StatelessWidget {
  final String userId;
  final TaskService _taskService = TaskService();

  TopTasksWidget({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define today's range with explicit UTC handling
    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    print('Start of today (UTC): $startOfToday');
    print('End of today (UTC): $endOfToday');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CalendarTaskPage(userId: userId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Tasks Today',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _taskService.getTasks(userId).map(
                (tasks) {
                  final filteredTasks = tasks.where((task) {
                    final taskDate = (task['date'] as Timestamp).toDate();
                    final isToday = taskDate.isAfter(startOfToday) &&
                        taskDate.isBefore(endOfToday);
                    final isNotDone = task['status'] != 'Done';
                    print(
                        'Task: ${task['title']}, Date: $taskDate, Status: ${task['status']}, IsToday: $isToday, IsNotDone: $isNotDone');
                    return isToday && isNotDone;
                  }).toList()
                    ..sort((a, b) =>
                        (a['date'] as Timestamp).compareTo(b['date']));
                  return filteredTasks;
                },
              ),
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
                  print('Snapshot error: ${snapshot.error}');
                  return const Text(
                    'Error loading tasks',
                    style: TextStyle(color: Colors.redAccent),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  print('No tasks due today: ${snapshot.data}');
                  return const Text(
                    'No tasks due today!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  );
                }

                final tasks = snapshot.data!.take(3).toList();
                print(
                    'Displayed tasks: ${tasks.map((t) => t['title']).toList()}');

                return Column(
                  children: tasks.map((task) {
                    final taskDate = (task['date'] as Timestamp).toDate();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['title'].toString()[0].toUpperCase() +
                                      task['title'].toString().substring(1),
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
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
