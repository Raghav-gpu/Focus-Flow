// lib/services/streak_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class StreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Record activity when a task is completed
  Future<void> recordActivity(String userId) async {
    final today = DateTime.now();
    final dateKey = DateTime(today.year, today.month, today.day)
        .toIso8601String()
        .split('T')[0];
    final activityRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('activity')
        .doc(dateKey);

    try {
      await activityRef.set({
        'date':
            Timestamp.fromDate(DateTime(today.year, today.month, today.day)),
        'tasksCompleted': FieldValue.increment(1),
      }, SetOptions(merge: true));
      debugPrint('Activity recorded for $dateKey');
    } catch (e) {
      debugPrint('Failed to record activity: $e');
      throw e;
    }
  }

  // Calculate the current streak
  Future<int> calculateStreak(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activitySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('activity')
        .orderBy('date', descending: true)
        .get();

    if (activitySnapshot.docs.isEmpty) return 0;

    int streak = 0;
    DateTime? previousDate;

    for (var doc in activitySnapshot.docs) {
      final activityDate = (doc['date'] as Timestamp).toDate();
      final normalizedDate =
          DateTime(activityDate.year, activityDate.month, activityDate.day);

      if (previousDate == null) {
        // First entry (most recent)
        if (normalizedDate.isAtSameMomentAs(today) ||
            normalizedDate
                .isAtSameMomentAs(today.subtract(Duration(days: 1)))) {
          streak = 1;
        } else {
          break; // No activity today or yesterday, streak ends
        }
      } else {
        // Check if consecutive
        final expectedDate = previousDate.subtract(Duration(days: 1));
        if (normalizedDate.isAtSameMomentAs(expectedDate)) {
          streak++;
        } else {
          break; // Gap found, streak ends
        }
      }
      previousDate = normalizedDate;
    }

    debugPrint('Calculated streak for $userId: $streak');
    return streak;
  }

  // Stream for real-time streak updates (optional)
  Stream<int> streakStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('activity')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return 0;

      int streak = 0;
      DateTime? previousDate;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (var doc in snapshot.docs) {
        final activityDate = (doc['date'] as Timestamp).toDate();
        final normalizedDate =
            DateTime(activityDate.year, activityDate.month, activityDate.day);

        if (previousDate == null) {
          if (normalizedDate.isAtSameMomentAs(today) ||
              normalizedDate
                  .isAtSameMomentAs(today.subtract(Duration(days: 1)))) {
            streak = 1;
          } else {
            break;
          }
        } else {
          final expectedDate = previousDate.subtract(Duration(days: 1));
          if (normalizedDate.isAtSameMomentAs(expectedDate)) {
            streak++;
          } else {
            break;
          }
        }
        previousDate = normalizedDate;
      }
      return streak;
    });
  }
}
