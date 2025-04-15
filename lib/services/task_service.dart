import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focus/services/encryption_service.dart';
import 'package:focus/services/google_tasks_service.dart'; // Adjust if needed
import 'package:focus/services/streak_service.dart';
import 'package:focus/services/firebase_auth_methods.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();
  final StreakService _streakService = StreakService();
  final AuthService _authService = AuthService();
  final Random _random = Random();
  GoogleCalendarService? _googleCalendarService;
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isSyncSuspended = false;
  bool _isUpdating = false;
  final Set<String> _recentlyDeletedGoogleEventIds = {};
  static const int _syncInterval = 300; // 5 minutes
  static const int _syncSuspensionDurationSeconds = 30;

  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;

  TaskService._internal() {
    _initGoogleCalendarService();
    _startPeriodicSync();
  }

  bool isRecentlyDeleted(String googleEventId) {
    debugPrint(
        'Checking if $googleEventId is recently deleted: ${_recentlyDeletedGoogleEventIds.contains(googleEventId)}');
    return _recentlyDeletedGoogleEventIds.contains(googleEventId);
  }

  Future<void> _initGoogleCalendarService() async {
    try {
      final accessToken = await _authService.getGoogleAccessToken();
      if (accessToken != null) {
        _googleCalendarService = GoogleCalendarService(_authService, this);
// removed debug statement
        final user = _authService.getCurrentUser();
        if (user != null) await syncFromGoogle(user.uid); // Silent initial sync
      } else {
        debugPrint(
            'No access token available, GoogleCalendarService not initialized');
      }
    } catch (e) {
// removed debug statement
      _googleCalendarService = null;
    }
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer =
        Timer.periodic(Duration(seconds: _syncInterval), (timer) async {
      if (_isSyncing || _isSyncSuspended || _isUpdating) {
        debugPrint(
            'Sync skipped - ${_isSyncing ? "already in progress" : _isSyncSuspended ? "suspended" : "updating"}');
        return;
      }
      final user = _authService.getCurrentUser();
      if (user != null && _googleCalendarService != null) {
// removed debug statement
        await syncFromGoogle(user.uid); // Silent periodic sync
      }
    });
  }

  Future<void> _debouncedSync(String userId) async {
    if (_isSyncing || _isSyncSuspended || _isUpdating) return;
    _isSyncing = true;
    try {
      await syncFromGoogle(userId);
    } finally {
      _isSyncing = false;
    }
  }

  Future<Map<String, dynamic>> _encryptTask(Map<String, dynamic> task) async {
    final encryptedTask = Map<String, dynamic>.from(task);
    for (var field in _encryptFields) {
      if (encryptedTask.containsKey(field) && encryptedTask[field] != null) {
        final value = encryptedTask[field].toString();
// removed debug statement
        try {
          if (value.trim().isNotEmpty) {
            encryptedTask[field] = await _encryptionService.encrypt(value);
          } else {
// removed debug statement
            encryptedTask[field] = value;
          }
        } catch (e) {
// removed debug statement
          encryptedTask[field] = value;
        }
      }
    }
    encryptedTask['title'] = task['title'];
    encryptedTask['start'] = task['start'];
    encryptedTask['end'] = task['end'];
    encryptedTask['googleEventId'] = task['googleEventId'];
    encryptedTask['completedAt'] = task['completedAt'];
    encryptedTask['status'] = task['status'];
// removed debug statement
    return encryptedTask;
  }

  Future<Map<String, dynamic>> _decryptTask(Map<String, dynamic> task) async {
    final decryptedTask = Map<String, dynamic>.from(task);
    for (var field in _encryptFields) {
      if (decryptedTask.containsKey(field) && decryptedTask[field] != null) {
        try {
          decryptedTask[field] =
              await _encryptionService.decrypt(task[field] as String);
        } catch (e) {
          debugPrint(
              'Failed to decrypt field "$field" for task ${task['id'] ?? 'unknown'}: $e');
          decryptedTask[field] = task[field];
        }
      }
    }
    decryptedTask['title'] = task['title'];
    if (task.containsKey('start') && task['start'] != null) {
      try {
        final utcStart = (task['start'] as Timestamp).toDate();
        decryptedTask['start'] = Timestamp.fromDate(utcStart.toLocal());
      } catch (e) {
// removed debug statement
        decryptedTask['start'] = null;
      }
    }
    if (task.containsKey('end') && task['end'] != null) {
      try {
        final utcEnd = (task['end'] as Timestamp).toDate();
        decryptedTask['end'] = Timestamp.fromDate(utcEnd.toLocal());
      } catch (e) {
// removed debug statement
        decryptedTask['end'] = null;
      }
    }
    decryptedTask['googleEventId'] = task['googleEventId'];
    if (task.containsKey('completedAt') && task['completedAt'] != null) {
      try {
        final utcCompleted = (task['completedAt'] as Timestamp).toDate();
        decryptedTask['completedAt'] =
            Timestamp.fromDate(utcCompleted.toLocal());
      } catch (e) {
        debugPrint(
            'Error handling completedAt for task ${task['id'] ?? 'unknown'}: $e');
        decryptedTask['completedAt'] = null;
      }
    } else {
      decryptedTask['completedAt'] = null;
    }
    decryptedTask['status'] = task['status'];
    return decryptedTask;
  }

  Future<void> addTask(String userId, Map<String, dynamic> task) async {
// removed debug statement
    if (task['title']?.toString().trim().isEmpty ?? true) {
// removed debug statement
      return;
    }
    if (task['start'] == null ||
        task['start'] is! Timestamp ||
        task['end'] == null ||
        task['end'] is! Timestamp) {
// removed debug statement
      return;
    }

    final startDate = (task['start'] as Timestamp).toDate();
    final endDate = (task['end'] as Timestamp).toDate();
    debugPrint(
        'Task start: ${DateFormat('yyyy-MM-dd HH:mm').format(startDate)}, end: ${DateFormat('yyyy-MM-dd HH:mm').format(endDate)}');

    final taskWithUTC = {
      ...task,
      'start': Timestamp.fromDate(startDate.toUtc()),
      'end': Timestamp.fromDate(endDate.toUtc()),
      'status': task['status'] ?? 'To Do',
      'priority': task['priority'] ?? 'Medium',
      'description': task['description'] ?? 'No Description',
      'notificationSent': task['notificationSent'] ?? false,
      'googleEventId': task['googleEventId'],
    };

    try {
// removed debug statement
      final encryptedTask = await _encryptTask(taskWithUTC);
// removed debug statement
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .add(encryptedTask);
      final taskId = docRef.id;
// removed debug statement
      if (_googleCalendarService == null) {
        await _initGoogleCalendarService();
      }
      if (_googleCalendarService != null &&
          taskWithUTC['googleEventId'] == null) {
        final decryptedTask = await _decryptTask(encryptedTask);
// removed debug statement
        final googleEventId =
            await _googleCalendarService!.addEventToGoogle(decryptedTask);
        if (googleEventId != null) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('tasks')
              .doc(taskId)
              .update({'googleEventId': googleEventId});
          debugPrint(
              'Task synced to Google Calendar with event ID: $googleEventId');
        }
      }
    } catch (e) {
// removed debug statement
      throw e;
    }
  }

  Future<void> completeTask(String userId, String taskId) async {
    if (_isUpdating) {
// removed debug statement
      return;
    }
    _isUpdating = true;
// removed debug statement
    try {
      final taskDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .get();
      if (!taskDoc.exists) {
// removed debug statement
        return;
      }

      final taskData = await _decryptTask(taskDoc.data()!);
      final priority = taskData['priority'] as String;
      final completedAt = Timestamp.now();

      final updates = {
        ...taskData,
        'status': 'Completed',
        'completedAt': completedAt,
      };

      final encryptedUpdates = await _encryptTask(updates);
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .set(encryptedUpdates, SetOptions(merge: true));

      if (_googleCalendarService != null && taskData['googleEventId'] != null) {
        final updatedTask = {
          ...taskData,
          'status': 'Completed',
          'completedAt': completedAt,
        };
        await _googleCalendarService!
            .updateGoogleEvent(taskData['googleEventId'], updatedTask);
        debugPrint(
            'Updated Google Calendar event: ${taskData['googleEventId']}');
      }

      await _streakService.recordActivity(userId);
      int xpIncrease = {'Low': 10, 'Medium': 25, 'High': 50}[priority] ?? 10;
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.set(
          {'xp': FieldValue.increment(xpIncrease)}, SetOptions(merge: true));

      final userDoc = await userRef.get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      int currentXp = userData?['xp'] as int? ?? 0;
      int currentLevel = userData?['level'] as int? ?? 1;

      if (!userDoc.exists ||
          userData == null ||
          !userData.containsKey('level')) {
        await userRef
            .set({'level': 1, 'xp': currentXp}, SetOptions(merge: true));
        currentLevel = 1;
      }

      final maxXP = 100 + (currentLevel - 1) * 50;
      if (currentXp >= maxXP) {
        await userRef.update({
          'level': FieldValue.increment(1),
          'xp': currentXp - maxXP,
        });
      }
    } catch (e) {
// removed debug statement
      throw e;
    } finally {
      _isUpdating = false;
    }
  }

  Future<void> updateTask(
      String userId, String taskId, Map<String, dynamic> updates) async {
    if (_isUpdating) {
// removed debug statement
      return;
    }
    _isUpdating = true;
// removed debug statement
    try {
      final taskDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .get();
      if (!taskDoc.exists) {
// removed debug statement
        return;
      }
      final taskData = await _decryptTask(taskDoc.data()!);
// removed debug statement
      if (updates.containsKey('status')) {
        if (updates['status'] == 'To Do') {
          updates['completedAt'] = null;
// removed debug statement
        } else if (updates['status'] == 'Completed') {
          updates['completedAt'] = Timestamp.now();
// removed debug statement
        }
      }

      final fullUpdates = {...taskData, ...updates};
// removed debug statement
      final encryptedUpdates = await _encryptTask(fullUpdates);
// removed debug statement
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .set(encryptedUpdates, SetOptions(merge: true));
// removed debug statement
      if (_googleCalendarService != null && taskData['googleEventId'] != null) {
        final updatedTask = {...taskData, ...updates};
// removed debug statement
        await _googleCalendarService!
            .updateGoogleEvent(taskData['googleEventId'], updatedTask);
        debugPrint(
            'Updated Google Calendar event: ${taskData['googleEventId']}');
      }
    } catch (e) {
// removed debug statement
      throw e;
    } finally {
      _isUpdating = false;
    }
  }

  Future<void> deleteTask(String userId, String taskId) async {
// removed debug statement
    _isSyncSuspended = true;
// removed debug statement
    try {
      final taskDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .get();
      if (!taskDoc.exists) {
// removed debug statement
        return;
      }

      final taskData = await _decryptTask(taskDoc.data()!);
      final googleEventId = taskData['googleEventId'] as String?;

      if (_googleCalendarService != null && googleEventId != null) {
        await _googleCalendarService!.deleteGoogleEvent(googleEventId);
        _recentlyDeletedGoogleEventIds.add(googleEventId);
// removed debug statement
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .delete();
// removed debug statement
    } catch (e) {
// removed debug statement
      rethrow;
    } finally {
      Timer(Duration(seconds: _syncSuspensionDurationSeconds), () {
        _isSyncSuspended = false;
// removed debug statement
      });
      if (_recentlyDeletedGoogleEventIds.isNotEmpty) {
        Timer(Duration(seconds: _syncSuspensionDurationSeconds * 2), () {
          _recentlyDeletedGoogleEventIds.clear();
// removed debug statement
        });
      }
    }
  }

  Stream<List<Map<String, dynamic>>> getTasks(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .snapshots()
        .debounceTime(Duration(milliseconds: 500))
        .asyncMap((snapshot) async {
      final decryptedTasks = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data();
          final decryptedData = await _decryptTask(data);
          decryptedData['id'] = doc.id;
          debugPrint(
              'Streaming task data for ID: ${doc.id} - Title: ${decryptedData['title']}, Status: ${decryptedData['status']}');
          return decryptedData;
        }),
      );
      return decryptedTasks;
    }).handleError((e) {
// removed debug statement
      return [];
    });
  }

  Future<List<Map<String, dynamic>>> getTasksSnapshot(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .get();
      return Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        data['id'] = doc.id;
        return await _decryptTask(data);
      }).toList());
    } catch (e) {
// removed debug statement
      return [];
    }
  }

  Future<Map<String, dynamic>?> findTaskByGoogleEventId(
      String userId, String googleEventId) async {
    final query = await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('googleEventId', isEqualTo: googleEventId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      final decryptedData = await _decryptTask(data);
      decryptedData['id'] = query.docs.first.id;
      return decryptedData;
    }
    return null;
  }

  Future<void> syncFromGoogle(String userId) async {
    if (_googleCalendarService == null) {
      await _initGoogleCalendarService();
    }
    if (_googleCalendarService != null && !_isSyncSuspended && !_isUpdating) {
// removed debug statement
      await _googleCalendarService!.syncFromGoogle(userId);
    } else {
      debugPrint(
          'Sync skipped: service not initialized, suspended, or updating');
    }
  }

  Future<void> triggerSync(String userId) async {
// removed debug statement
    await _initGoogleCalendarService();
    if (_googleCalendarService != null) {
      await syncFromGoogle(userId);
      await _syncToGoogle(userId);
    } else {
// removed debug statement
    }
  }

  Future<void> _syncToGoogle(String userId) async {
// removed debug statement
    if (_googleCalendarService == null) {
      await _initGoogleCalendarService();
    }
    if (_googleCalendarService == null) {
      debugPrint(
          'Cannot sync to Google: GoogleCalendarService not initialized');
      return;
    }
    try {
      final tasks = await getTasksSnapshot(userId);
      for (var task in tasks) {
        if (task['googleEventId'] == null) {
          final googleEventId =
              await _googleCalendarService!.addEventToGoogle(task);
          if (googleEventId != null) {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('tasks')
                .doc(task['id'])
                .update({'googleEventId': googleEventId});
            debugPrint(
                'Task ${task['id']} synced to Google with event ID: $googleEventId');
          }
        }
      }
    } catch (e) {
// removed debug statement
    }
  }

  void dispose() {
    _syncTimer?.cancel();
  }

  static const List<String> _encryptFields = [
    'description',
    'priority',
  ];
}
