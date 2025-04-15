import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focus/services/task_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/cupertino.dart'
    show CupertinoButton, CupertinoDatePicker, CupertinoDatePickerMode;

class AddTaskScreen extends StatefulWidget {
  final String userId;

  const AddTaskScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(minutes: 30));
  String _priority = 'Medium';
  final TaskService _taskService = TaskService();

  void _saveTask() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
// removed debug statement
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authenticated user found')),
      );
      return;
    }
    if (widget.userId != currentUser.uid) {
      debugPrint(
          'User ID mismatch: widget.userId=${widget.userId}, auth.uid=${currentUser.uid}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID mismatch')),
      );
      return;
    }

    if (_titleController.text.isNotEmpty) {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );
      if (endDateTime.isBefore(startDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
        return;
      }
      debugPrint(
          'Saving task: Title: ${_titleController.text}, Start: $startDateTime, End: $endDateTime, UserID: ${widget.userId}');
      try {
        await _taskService.addTask(widget.userId, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'start': Timestamp.fromDate(startDateTime),
          'end': Timestamp.fromDate(endDateTime),
          'priority': _priority,
          'status': 'To Do',
        });
// removed debug statement
        Navigator.pop(context);
      } catch (e) {
// removed debug statement
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Colors.black87,
              onSurface: Colors.white70,
            ),
            dialogBackgroundColor: Colors.black.withOpacity(0.9),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _startTime = DateTime(picked.year, picked.month, picked.day,
            _startTime.hour, _startTime.minute);
        _endTime = DateTime(picked.year, picked.month, picked.day,
            _endTime.hour, _endTime.minute);
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initialTime = isStart ? _startTime : _endTime;

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      DateTime? picked;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: 350,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initialTime,
                  use24hFormat: false,
                  onDateTimeChanged: (dateTime) {
                    picked = dateTime;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CupertinoButton(
                  child: const Text('Done',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
      if (picked != null) {
        setState(() {
          if (isStart) {
            _startTime = DateTime(_selectedDate.year, _selectedDate.month,
                _selectedDate.day, picked!.hour, picked!.minute);
          } else {
            _endTime = DateTime(_selectedDate.year, _selectedDate.month,
                _selectedDate.day, picked!.hour, picked!.minute);
          }
        });
      }
    } else {
      // Android: Circular clock picker
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialTime),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.blueAccent,
                onPrimary: Colors.white,
                surface: Colors.black87,
                onSurface: Colors.white70,
              ),
              dialogBackgroundColor: Colors.black.withOpacity(0.9),
              timePickerTheme: TimePickerThemeData(
                backgroundColor: Colors.black87,
                hourMinuteTextColor: Colors.white,
                dialHandColor: Colors.blueAccent,
                dialTextColor: Colors.white70,
                entryModeIconColor: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          if (isStart) {
            _startTime = DateTime(_selectedDate.year, _selectedDate.month,
                _selectedDate.day, picked.hour, picked.minute);
          } else {
            _endTime = DateTime(_selectedDate.year, _selectedDate.month,
                _selectedDate.day, picked.hour, picked.minute);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Task'),
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Enter task title',
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Enter task description (optional)',
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d').format(_selectedDate),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.calendar_today,
                        color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _pickTime(true),
                    child: Text(
                      TimeOfDay.fromDateTime(_startTime).format(context),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Text(
                    '–',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  GestureDetector(
                    onTap: () => _pickTime(false),
                    child: Text(
                      TimeOfDay.fromDateTime(_endTime).format(context),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _priority,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: Colors.black.withOpacity(0.9),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                items: ['Low', 'Medium', 'High'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _priority = value!),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Task',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
