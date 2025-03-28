import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:focus/services/task_service.dart';
import 'package:intl/intl.dart';
import 'task_form.dart';

class TaskDetailPopup extends StatefulWidget {
  final Map<String, dynamic> task;
  final String userId;
  final VoidCallback onTaskUpdated;

  const TaskDetailPopup({
    Key? key,
    required this.task,
    required this.userId,
    required this.onTaskUpdated,
  }) : super(key: key);

  @override
  _TaskDetailPopupState createState() => _TaskDetailPopupState();
}

class _TaskDetailPopupState extends State<TaskDetailPopup> {
  final List<String> _statuses = ['To Do', 'Doing', 'Done'];
  final TaskService _taskService = TaskService();

  Future<void> _updateStatus(String newStatus) async {
    try {
      if (newStatus == 'Done') {
        await _taskService.completeTask(widget.userId, widget.task['id']);
      } else {
        await _taskService.updateTask(
            widget.userId, widget.task['id'], {'status': newStatus});
      }
      widget.onTaskUpdated();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red[900],
        ),
      );
    }
  }

  Future<void> _deleteTask() async {
    try {
      Navigator.pop(context);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('tasks')
          .doc(widget.task['id'])
          .delete();
      widget.onTaskUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete task: $e'),
            backgroundColor: Colors.red[900],
          ),
        );
      }
    }
  }

  void _editTask() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskForm(
        userId: widget.userId,
        onTaskAdded: () {
          setState(() {});
          widget.onTaskUpdated();
        },
        task: widget.task,
      ),
    );
  }

  void _retryFetch() {
    setState(() {});
  }

  Stream<Map<String, dynamic>> _getTaskStream(String userId, String taskId) {
    return _taskService.getTasks(userId).map((tasks) {
      return tasks.firstWhere((task) => task['id'] == taskId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: StreamBuilder<Map<String, dynamic>>(
        stream: _getTaskStream(widget.userId, widget.task['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(screenHeight, screenWidth);
          }

          if (snapshot.hasError) {
            return _buildErrorState(
                'Error: ${snapshot.error}', screenHeight, screenWidth);
          }

          if (!snapshot.hasData) {
            return _buildErrorState(
                'Task not found', screenHeight, screenWidth);
          }

          final task = snapshot.data!;
          final dueDate = (task['date'] as Timestamp).toDate();
          final priorityColor = _getPriorityColor(task['priority']);

          return Container(
            height: screenHeight * 0.8,
            width: screenWidth * 0.85,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.85),
                  Colors.black.withOpacity(0.65),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: priorityColor.withOpacity(0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: priorityColor.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 10,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          task['title'].toString()[0].toUpperCase() +
                              task['title'].toString().substring(1),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: priorityColor.withOpacity(0.7),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 20, color: priorityColor),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.yMMMMd().add_jm().format(dueDate),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: _statuses.map((status) {
                      return ChoiceChip(
                        label: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: task['status'] == status,
                        selectedColor: _getStatusColor(status).withOpacity(0.9),
                        backgroundColor: Colors.black.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                              color: _getStatusColor(status).withOpacity(0.7)),
                        ),
                        onSelected: (selected) {
                          if (selected) _updateStatus(status);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.priority_high, size: 20, color: priorityColor),
                      const SizedBox(width: 8),
                      Text(
                        'Priority: ${task['priority']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: priorityColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task['description']?.isEmpty ?? true
                        ? 'No description'
                        : task['description'],
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // _buildCustomButton(
                      //   text: 'Edit',
                      //   icon: Icons.edit,
                      //   color: Colors.blueAccent,
                      //   onTap: _editTask,
                      // ),
                      _buildCustomButton(
                        text: 'Delete',
                        icon: Icons.delete,
                        color: Colors.redAccent,
                        onTap: _deleteTask,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(double height, double width) {
    return Container(
      height: height * 0.8,
      width: width * 0.85,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 12,
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.blueAccent,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, double height, double width) {
    return Container(
      height: height * 0.8,
      width: width * 0.85,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 12,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildCustomButton(
              text: 'Retry',
              icon: Icons.refresh,
              color: Colors.blueAccent,
              onTap: _retryFetch,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.9),
              color.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'To Do':
        return Colors.redAccent;
      case 'Doing':
        return Colors.blueAccent;
      case 'Done':
        return Colors.greenAccent;
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
