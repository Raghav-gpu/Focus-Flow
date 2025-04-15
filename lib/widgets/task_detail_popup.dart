import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:focus/services/task_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
  final List<String> _statuses = ['To Do', 'Completed'];
  final TaskService _taskService = TaskService();
  bool _isUpdating = false;

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) {
// removed debug statement
      return;
    }
    debugPrint(
        'Updating status to: $newStatus for task ID: ${widget.task['id']}');
    setState(() => _isUpdating = true);
    try {
      if (newStatus == 'Completed') {
// removed debug statement
        await _taskService.completeTask(widget.userId, widget.task['id']);
      } else {
// removed debug statement
        await _taskService.updateTask(
            widget.userId, widget.task['id'], {'status': newStatus});
// removed debug statement
      }
// removed debug statement
      widget.onTaskUpdated();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
// removed debug statement
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red[900],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
// removed debug statement
      }
    }
  }

  Future<void> _deleteTask() async {
// removed debug statement
    try {
      await _taskService.deleteTask(widget.userId, widget.task['id']);
      widget.onTaskUpdated();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
// removed debug statement
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
// removed debug statement
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
// removed debug statement
    setState(() {});
  }

  Stream<Map<String, dynamic>> _getTaskStream(String userId, String taskId) {
// removed debug statement
    return _taskService.getTasks(userId).map((tasks) {
      return tasks.firstWhere((task) => task['id'] == taskId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.05)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: StreamBuilder<Map<String, dynamic>>(
        stream: _getTaskStream(widget.userId, widget.task['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(screenHeight, screenWidth);
          }

          if (snapshot.hasError) {
// removed debug statement
            return _buildErrorState(
                'Error: ${snapshot.error}', screenHeight, screenWidth);
          }

          if (!snapshot.hasData) {
// removed debug statement
            return _buildErrorState(
                'Task not found', screenHeight, screenWidth);
          }

          final task = snapshot.data!;
          debugPrint(
              'Task data loaded: ${task['title']}, status: ${task['status']}');
          final startTime = (task['start'] as Timestamp).toDate();
          final endTime = (task['end'] as Timestamp).toDate();
          final priorityColor = _getPriorityColor(task['priority']);

          return Container(
            height: screenHeight * 0.8,
            width: screenWidth * 0.9, // Increased slightly for better fit
            padding: EdgeInsets.all(screenWidth * 0.05),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.85),
                  Colors.black.withOpacity(0.65),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
              border:
                  Border.all(color: priorityColor.withOpacity(0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: priorityColor.withOpacity(0.3),
                  spreadRadius: screenWidth * 0.005,
                  blurRadius: screenWidth * 0.025,
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
                            fontSize: screenWidth * 0.07,
                            fontWeight: task['status'] == 'To Do'
                                ? FontWeight.w800
                                : FontWeight.w400,
                            color: task['status'] == 'To Do'
                                ? Colors.white
                                : Colors.grey[400],
                            decoration: task['status'] == 'Completed'
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.grey[400],
                            shadows: task['status'] == 'To Do'
                                ? [
                                    Shadow(
                                      color: priorityColor.withOpacity(0.7),
                                      blurRadius: screenWidth * 0.02,
                                    ),
                                  ]
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(screenWidth * 0.015),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                blurRadius: screenWidth * 0.01,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: screenWidth * 0.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.calendar_today,
                          size: screenWidth * 0.05, color: priorityColor),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.yMMMMd().format(startTime),
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${DateFormat.jm().format(startTime)} - ${DateFormat.jm().format(endTime)}',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: _statuses.map((status) {
                      return Padding(
                        padding: EdgeInsets.only(right: screenWidth * 0.03),
                        child: _buildStatusButton(
                            status, task['status'], screenWidth),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Row(
                    children: [
                      Icon(Icons.priority_high,
                          size: screenWidth * 0.05, color: priorityColor),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        'Priority: ${task['priority']}',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w600,
                          color: priorityColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    task['description']?.isEmpty ?? true
                        ? 'No description'
                        : task['description'],
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCustomButton(
                        text: 'Delete',
                        icon: Icons.delete,
                        color: Colors.redAccent,
                        onTap: _deleteTask,
                        screenWidth: screenWidth,
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
      width: width * 0.9,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(width * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: width * 0.005,
            blurRadius: width * 0.03,
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
      width: width * 0.9,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(width * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: width * 0.005,
            blurRadius: width * 0.03,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                color: Colors.redAccent, size: width * 0.12),
            SizedBox(height: height * 0.02),
            Text(
              message,
              style: TextStyle(
                fontSize: width * 0.04,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: height * 0.025),
            _buildCustomButton(
              text: 'Retry',
              icon: Icons.refresh,
              color: Colors.blueAccent,
              onTap: _retryFetch,
              screenWidth: width,
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
    required double screenWidth,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenWidth * 0.03,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.9),
              color.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              spreadRadius: screenWidth * 0.002,
              blurRadius: screenWidth * 0.025,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: screenWidth * 0.05),
            SizedBox(width: screenWidth * 0.02),
            Text(
              text,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(
      String status, String currentStatus, double screenWidth) {
    final statusColor = _getStatusColor(status);
    final isSelected = status == currentStatus;
    return GestureDetector(
      onTap: () => _updateStatus(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenWidth * 0.02,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? statusColor.withOpacity(0.9)
              : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          border: Border.all(color: statusColor.withOpacity(0.7)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: statusColor.withOpacity(0.5),
                    spreadRadius: screenWidth * 0.002,
                    blurRadius: screenWidth * 0.012,
                  ),
                ]
              : null,
        ),
        child: _isUpdating && !isSelected
            ? SizedBox(
                width: screenWidth * 0.05,
                height: screenWidth * 0.05,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == 'To Do' ? Icons.play_arrow : Icons.check,
                    color: Colors.white,
                    size: screenWidth * 0.05,
                  ),
                  SizedBox(width: screenWidth * 0.01),
                  Text(
                    status,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: screenWidth * 0.035,
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
