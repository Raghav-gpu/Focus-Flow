import 'package:flutter/material.dart';
import 'package:focus/services/task_service.dart';

class EditTaskDialog extends StatelessWidget {
  final Map<String, dynamic> task;
  final String userId;
  final VoidCallback onTaskUpdated;
  final TaskService _taskService = TaskService(); // Initialize TaskService

  EditTaskDialog({
    Key? key,
    required this.task,
    required this.userId,
    required this.onTaskUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Update Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildStatusButton(context, 'To Do'),
            _buildStatusButton(context, 'Doing'),
            _buildStatusButton(context, 'Done'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context, String status) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(bottom: 8), // Assuming 'bottom' was intended
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: _getStatusColor(status).withOpacity(0.1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          try {
            if (status == 'Done') {
              // Use completeTask for "Done" to handle XP and streak
              await _taskService.completeTask(userId, task['id']);
            } else {
              // Use updateTask for "To Do" and "Doing"
              await _taskService.updateTask(
                userId,
                task['id'],
                {'status': status},
              );
            }
            Navigator.pop(context);
            onTaskUpdated();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update status: $e')),
            );
          }
        },
        child: Text(
          status,
          style: TextStyle(
            color: _getStatusColor(status),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'To Do':
        return Colors.grey;
      case 'Doing':
        return Colors.blue;
      case 'Done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
