// lib/services/task_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focus/services/encryption_service.dart';
import 'package:focus/services/streak_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:math';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();
  final StreakService _streakService = StreakService();
  final Random _random = Random();

  static const List<String> _encryptFields = [
    'description',
    'priority',
    'status',
  ]; // Removed 'title' and 'date'

  Future<Map<String, dynamic>> _encryptTask(Map<String, dynamic> task) async {
    final encryptedTask = Map<String, dynamic>.from(task);
    for (var field in _encryptFields) {
      if (encryptedTask.containsKey(field) && encryptedTask[field] != null) {
        encryptedTask[field] =
            await _encryptionService.encrypt(task[field].toString());
      }
    }
    // Keep 'title' and 'date' unencrypted
    if (task.containsKey('title')) encryptedTask['title'] = task['title'];
    if (task.containsKey('date')) encryptedTask['date'] = task['date'];
    debugPrint('Encrypted task: $encryptedTask');
    return encryptedTask;
  }

  Future<Map<String, dynamic>> _decryptTask(Map<String, dynamic> task) async {
    final decryptedTask = Map<String, dynamic>.from(task);
    for (var field in _encryptFields) {
      if (decryptedTask.containsKey(field) && decryptedTask[field] != null) {
        decryptedTask[field] =
            await _encryptionService.decrypt(task[field] as String);
      }
    }
    // Pass through unencrypted fields
    if (task.containsKey('title')) decryptedTask['title'] = task['title'];
    if (task.containsKey('date')) {
      try {
        decryptedTask['date'] =
            task['date'] as Timestamp; // Already unencrypted
      } catch (e) {
        debugPrint('Error handling date $task[date]: $e');
        decryptedTask['date'] = null;
      }
    }
    return decryptedTask;
  }

  Future<void> addTask(String userId, Map<String, dynamic> task) async {
    debugPrint('Adding task for user: $userId, Task: $task');
    try {
      final encryptedTask = await _encryptTask(task);
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .add(encryptedTask);
      debugPrint('Task added successfully with ID: ${docRef.id}');
    } catch (e) {
      debugPrint('Failed to add task: $e');
      throw e;
    }
  }

  Future<void> completeTask(String userId, String taskId) async {
    try {
      final taskDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .get();
      final taskData = await _decryptTask(taskDoc.data()!);
      final priority = taskData['priority'] as String;

      final encryptedUpdates = await _encryptTask({'status': 'Done'});
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .update(encryptedUpdates);
      debugPrint('Task $taskId marked as done');

      await _streakService.recordActivity(userId);

      int xpIncrease;
      switch (priority) {
        case 'Low':
          xpIncrease = 10;
          break;
        case 'Medium':
          xpIncrease = 25;
          break;
        case 'High':
          xpIncrease = 50;
          break;
        default:
          xpIncrease = 10;
      }

      final userRef = _firestore.collection('users').doc(userId);
      await userRef.set({
        'xp': FieldValue.increment(xpIncrease),
      }, SetOptions(merge: true));
      debugPrint('XP increased by $xpIncrease for $priority task');

      final userDoc = await userRef.get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      int currentXp = userData?['xp'] as int? ?? 0;
      int currentLevel = userData?['level'] as int? ?? 1;

      if (!userDoc.exists ||
          userData == null ||
          !userData.containsKey('level')) {
        await userRef.set({
          'level': 1,
          'xp': currentXp,
        }, SetOptions(merge: true));
        currentLevel = 1;
        debugPrint('Initialized level to 1');
      }

      final maxXP = 100 + (currentLevel - 1) * 50;
      if (currentXp >= maxXP) {
        await userRef.update({
          'level': FieldValue.increment(1),
          'xp': currentXp - maxXP,
        });
        debugPrint('Level up! New level: ${currentLevel + 1}');
      }
    } catch (e) {
      debugPrint('Failed to complete task: $e');
      throw e;
    }
  }

  Stream<List<Map<String, dynamic>>> getTasks(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .snapshots()
        .asyncMap((snapshot) async {
      final decryptedTasks = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          final decryptedData = await _decryptTask(data);
          decryptedData['id'] = doc.id;
          return decryptedData;
        }),
      );
      return decryptedTasks;
    });
  }

  Future<void> updateTask(
      String userId, String taskId, Map<String, dynamic> updates) async {
    final encryptedUpdates = await _encryptTask(updates);
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .update(encryptedUpdates);
  }

  Future<Map<String, dynamic>?> findTaskByTitle(
      String userId, String title) async {
    final query = await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('title', isEqualTo: title) // Unencrypted now
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data() as Map<String, dynamic>;
      final decryptedData = await _decryptTask(data);
      decryptedData['id'] = query.docs.first.id;
      return decryptedData;
    }
    return null;
  }
}
