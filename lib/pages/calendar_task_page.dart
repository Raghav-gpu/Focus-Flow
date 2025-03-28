import 'package:flutter/material.dart';
import 'package:focus/pages/add_task_screen.dart';
import 'package:focus/services/task_service.dart';
import 'package:focus/widgets/compact_calendar.dart';
import 'package:focus/widgets/timeline_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp

class CalendarTaskPage extends StatefulWidget {
  final String userId;

  const CalendarTaskPage({Key? key, required this.userId}) : super(key: key);

  @override
  _CalendarTaskPageState createState() => _CalendarTaskPageState();
}

class _CalendarTaskPageState extends State<CalendarTaskPage> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  late Map<DateTime, List<Map<String, dynamic>>> _tasks;
  final TaskService _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _tasks = {};
  }

  List<Map<String, dynamic>> _getTasksForDay(DateTime day) {
    final targetDay = DateTime(day.year, day.month, day.day);
    return _tasks[targetDay] ?? [];
  }

  void _addTask() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTaskScreen(userId: widget.userId),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size using MediaQuery
    final screenSize = MediaQuery.of(context).size;
    final padding = screenSize.width * 0.05; // 5% of screen width for padding

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Calendar Tasks',
          style: TextStyle(
              fontSize: screenSize.width * 0.05), // Responsive font size
        ),
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.white,
              size: screenSize.width * 0.07, // Responsive icon size
            ),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      floatingActionButton: Container(
        width: screenSize.width * 0.15, // 15% of screen width
        height: screenSize.width * 0.15, // Square FAB
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blueAccent.withOpacity(0.9),
              Colors.blue[700]!.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(
              screenSize.width * 0.03), // Responsive radius
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.3),
              spreadRadius: screenSize.width * 0.02, // Responsive spread
              blurRadius: screenSize.width * 0.045, // Responsive blur
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            Icons.add,
            color: Colors.white,
            size: screenSize.width * 0.08, // Responsive icon size
          ),
          onPressed: _addTask,
          padding:
              EdgeInsets.all(screenSize.width * 0.025), // Responsive padding
          splashRadius: screenSize.width * 0.06, // Responsive splash radius
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // Calendar with responsive height
              CompactCalendar(
                focusedDay: _focusedDay,
                selectedDay: _selectedDay,
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: _getTasksForDay,
              ),
              // Task section takes remaining space
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _taskService.getTasks(widget.userId),
                  builder: (context, snapshot) {
                    // Loading state
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Colors.blueAccent,
                          strokeWidth:
                              screenSize.width * 0.005, // Responsive stroke
                        ),
                      );
                    }

                    // Error state
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading tasks: ${snapshot.error}',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize:
                                screenSize.width * 0.04, // Responsive font
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    // Process tasks
                    _tasks = {};
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      for (var task in snapshot.data!) {
                        final date =
                            (task['date'] as Timestamp?)?.toDate().toLocal() ??
                                DateTime.now();
                        final day = DateTime(date.year, date.month, date.day);
                        _tasks.update(
                          day,
                          (existing) => [...existing, task],
                          ifAbsent: () => [task],
                        );
                      }
                    }

                    // Check if there are tasks for the selected day
                    final tasksForSelectedDay = _getTasksForDay(_selectedDay);
                    if (tasksForSelectedDay.isEmpty) {
                      return Center(
                        child: Text(
                          'No tasks for this day',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize:
                                screenSize.width * 0.04, // Responsive font
                          ),
                        ),
                      );
                    }

                    // Show tasks if there are any
                    return TimelineView(
                      tasks: tasksForSelectedDay,
                      onTaskUpdated: () => setState(() {}),
                      userId: widget.userId,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
