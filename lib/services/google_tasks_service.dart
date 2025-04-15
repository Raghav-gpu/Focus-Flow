import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:focus/services/task_service.dart';
import 'package:focus/services/firebase_auth_methods.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class GoogleCalendarService {
  final AuthService _authService;
  final TaskService _taskService;
  static const String _baseUrl = 'https://www.googleapis.com/calendar/v3';
  static const String _calendarId = 'primary';

  GoogleCalendarService(this._authService, this._taskService) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken != null) {
// removed debug statement
      } else {
// removed debug statement
      }
    } catch (e) {
// removed debug statement
    }
  }

  Future<String?> _getAccessToken() async {
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null) {
// removed debug statement
      return null;
    }
// removed debug statement
    return accessToken;
  }

  String _formatDateTimeForGoogle(Timestamp timestamp) {
    final date = timestamp.toDate().toUtc();
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(date);
  }

  Timestamp _parseGoogleDateTime(String googleDateTime) {
    try {
      final dateTime = DateTime.parse(googleDateTime).toUtc();
      return Timestamp.fromDate(dateTime);
    } catch (e) {
// removed debug statement
      return Timestamp.now();
    }
  }

  Future<List<Map<String, dynamic>>> fetchGoogleEvents() async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) throw Exception('No access token available');
    final url = Uri.parse(
        '$_baseUrl/calendars/$_calendarId/events?singleEvents=true&orderBy=startTime');
// removed debug statement
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );
// removed debug statement
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
// removed debug statement
      return List<Map<String, dynamic>>.from(data['items'] ?? []);
    } else {
      debugPrint(
          'Failed to fetch Google Events: ${response.statusCode} - ${response.body}');
      throw Exception(
          'Failed to fetch Google Events: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String?> addEventToGoogle(Map<String, dynamic> task) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
// removed debug statement
      return null;
    }
    final url = Uri.parse('$_baseUrl/calendars/$_calendarId/events');

    final startTime = (task['start'] as Timestamp).toDate();
    final endTime = (task['end'] as Timestamp).toDate();
    debugPrint(
        'Adding to Google - Start: ${DateFormat('yyyy-MM-dd HH:mm').format(startTime)}, End: ${DateFormat('yyyy-MM-dd HH:mm').format(endTime)}');

    final descriptionWithPriority =
        '${task['description'] ?? ''}\nPriority - ${task['priority'] ?? 'Medium'}';
    final body = jsonEncode({
      'summary': task['status'] == 'Completed'
          ? task['title'] + "(Completed)"
          : task['title'],
      'description': descriptionWithPriority,
      'start': {
        'dateTime': _formatDateTimeForGoogle(task['start'] as Timestamp)
      },
      'end': {'dateTime': _formatDateTimeForGoogle(task['end'] as Timestamp)},
      'extendedProperties': {
        'private': {
          'status': task['status'] == 'Completed' ? 'completed' : 'To Do'
        }
      },
    });

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
// removed debug statement
      return data['id'];
    } else {
      debugPrint(
          'Failed to add event to Google: ${response.statusCode} - ${response.body}');
      return null;
    }
  }

  Future<void> updateGoogleEvent(
      String googleEventId, Map<String, dynamic> task) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;
    final url =
        Uri.parse('$_baseUrl/calendars/$_calendarId/events/$googleEventId');

    String title = task['title'] as String;
    if (task['status'] == 'Completed') {
      if (!title.endsWith(' (Completed)')) {
        title += ' (Completed)';
      }
    } else {
      title = title.replaceAll(' (Completed)', '');
    }

    final descriptionWithPriority =
        '${task['description'] ?? ''}\nPriority - ${task['priority'] ?? 'Medium'}';
    final body = jsonEncode({
      'summary': title,
      'description': descriptionWithPriority,
      'start': {
        'dateTime': _formatDateTimeForGoogle(task['start'] as Timestamp)
      },
      'end': {'dateTime': _formatDateTimeForGoogle(task['end'] as Timestamp)},
      'extendedProperties': {
        'private': {
          'status': task['status'] == 'Completed' ? 'completed' : 'To Do'
        }
      },
    });

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
// removed debug statement
    } else {
      debugPrint(
          'Failed to update Google Event: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> deleteGoogleEvent(String googleEventId) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;
    final url =
        Uri.parse('$_baseUrl/calendars/$_calendarId/events/$googleEventId');
// removed debug statement
    final response = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 204) {
// removed debug statement
    } else if (response.statusCode == 404) {
// removed debug statement
    } else {
      debugPrint(
          'Failed to delete Google Event: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> syncFromGoogle(String userId) async {
// removed debug statement
    try {
      final googleEvents = await fetchGoogleEvents();
      final firestoreTasks = await _taskService.getTasksSnapshot(userId);
// removed debug statement
      final validEvents = googleEvents.where((e) {
        final isValid = (e['summary']?.toString().trim().isNotEmpty ?? false) &&
            e['start']?['dateTime'] != null &&
            e['end']?['dateTime'] != null &&
            !_taskService.isRecentlyDeleted(e['id']);
        debugPrint(
            'Event ${e['id']} - Title: ${e['summary']}, Valid: $isValid');
        return isValid;
      }).toList();

      // Filter out events older than 1 year
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: 365)); // 1 year ago
      final filteredEvents = validEvents.where((e) {
        final startTime = DateTime.parse(e['start']['dateTime']);
        final isRecentEnough = startTime.isAfter(cutoffDate);
        if (!isRecentEnough) {
          debugPrint(
              'Skipping past event: ${e['summary']} (Start: ${e['start']['dateTime']})');
        }
        return isRecentEnough;
      }).toList();

      for (var gEvent in filteredEvents) {
        final existingTask =
            await _taskService.findTaskByGoogleEventId(userId, gEvent['id']);
        final descriptionParts =
            (gEvent['description'] ?? '').split('\nPriority - ');
        final description = descriptionParts[0].trim();
        final priority =
            descriptionParts.length > 1 ? descriptionParts[1] : 'Medium';

        final taskData = {
          'title': gEvent['summary'],
          'description': description,
          'priority': priority,
          'start': _parseGoogleDateTime(gEvent['start']['dateTime']),
          'end': _parseGoogleDateTime(gEvent['end']['dateTime']),
          'status':
              gEvent['extendedProperties']?['private']?['status'] == 'completed'
                  ? 'Completed'
                  : 'To Do',
          'googleEventId': gEvent['id'],
          'completedAt': gEvent['extendedProperties']?['private']?['status'] ==
                      'completed' &&
                  existingTask?['completedAt'] != null
              ? existingTask!['completedAt']
              : null,
          'notificationSent': existingTask?['notificationSent'] ?? false,
        };

        if (existingTask == null) {
          await _taskService.addTask(userId, taskData);
        } else if (_tasksDiffer(existingTask, taskData)) {
          await _taskService.updateTask(userId, existingTask['id'], taskData);
        }
      }

      final googleEventIds =
          filteredEvents.map((e) => e['id'] as String).toSet();
      for (var firestoreTask in firestoreTasks) {
        final googleEventId = firestoreTask['googleEventId'] as String?;
        if (googleEventId != null && !googleEventIds.contains(googleEventId)) {
          await _taskService.deleteTask(userId, firestoreTask['id']);
        }
      }
// removed debug statement
    } catch (e) {
// removed debug statement
    }
  }

  bool _tasksDiffer(
      Map<String, dynamic> existing, Map<String, dynamic> newTask) {
    return existing['title'] != newTask['title'] ||
        existing['description'] != newTask['description'] ||
        existing['priority'] != newTask['priority'] ||
        (existing['start'] as Timestamp).seconds !=
            (newTask['start'] as Timestamp).seconds ||
        (existing['end'] as Timestamp).seconds !=
            (newTask['end'] as Timestamp).seconds ||
        existing['status'] != newTask['status'] ||
        ((existing['completedAt'] != null && newTask['completedAt'] != null) &&
            (existing['completedAt'] as Timestamp).seconds !=
                (newTask['completedAt'] as Timestamp).seconds);
  }
}
