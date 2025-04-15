import 'package:flutter/material.dart';
import 'package:focus/pages/add_task_screen.dart';
import 'package:focus/services/task_service.dart';
import 'package:focus/widgets/compact_calendar.dart';
import 'package:focus/widgets/timeline_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    _triggerSilentSync(); // Initial silent sync
  }

  Future<void> _triggerSilentSync() async {
    try {
      await _taskService.triggerSync(widget.userId); // Silent sync
      // No setState needed—stream will update UI if changes occur
    } catch (e) {
// removed debug statement
      // Optionally show a subtle error (e.g., SnackBar) if critical
    }
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
    ).then((_) => _triggerSilentSync()); // Silent sync after adding task
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = screenSize.width * 0.05;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Calendar Tasks',
          style: TextStyle(fontSize: screenSize.width * 0.05),
        ),
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.white,
              size: screenSize.width * 0.07,
            ),
            onPressed: _triggerSilentSync, // Silent manual sync
            tooltip: 'Refresh and Sync',
          ),
        ],
      ),
      floatingActionButton: Container(
        width: screenSize.width * 0.15,
        height: screenSize.width * 0.15,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blueAccent.withOpacity(0.9),
              Colors.blue[700]!.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(screenSize.width * 0.03),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.3),
              spreadRadius: screenSize.width * 0.02,
              blurRadius: screenSize.width * 0.045,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            Icons.add,
            color: Colors.white,
            size: screenSize.width * 0.08,
          ),
          onPressed: _addTask,
          padding: EdgeInsets.all(screenSize.width * 0.025),
          splashRadius: screenSize.width * 0.06,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              CompactCalendar(
                focusedDay: _focusedDay,
                selectedDay: _selectedDay,
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _triggerSilentSync(); // Silent sync on day change
                },
                eventLoader: _getTasksForDay,
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _taskService.getTasks(widget.userId),
                  builder: (context, snapshot) {
                    // Always show data, even during initial load or sync
                    _tasks = {};
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      for (var task in snapshot.data!) {
                        final date =
                            (task['start'] as Timestamp?)?.toDate().toLocal() ??
                                DateTime.now(); // Use 'start' instead of 'date'
                        final day = DateTime(date.year, date.month, date.day);
                        _tasks.update(
                          day,
                          (existing) => [...existing, task],
                          ifAbsent: () => [task],
                        );
                      }
                    }

                    final tasksForSelectedDay = _getTasksForDay(_selectedDay);
                    if (tasksForSelectedDay.isEmpty) {
                      return Center(
                        child: Text(
                          'No tasks for this day',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: screenSize.width * 0.04,
                          ),
                        ),
                      );
                    }

                    return TimelineView(
                      tasks: tasksForSelectedDay,
                      onTaskUpdated:
                          _triggerSilentSync, // Silent sync on update
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
