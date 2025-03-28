// lib/services/challenge_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new challenge
  Future<void> createChallenge(
    String senderId,
    String receiverId,
    String description,
    int durationDays,
  ) async {
    try {
      final challengeData = {
        'senderId': senderId,
        'receiverId': receiverId,
        'description': description,
        'durationDays': durationDays,
        'startDate': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, active, completed, abandoned
        'senderProgress': 0,
        'receiverProgress': 0,
        'winner': null,
      };

      await _firestore.collection('challenges').add(challengeData);
      debugPrint('Challenge created: $description');
    } catch (e) {
      debugPrint('Error creating challenge: $e');
      rethrow;
    }
  }

  // Accept a challenge
  Future<void> acceptChallenge(String challengeId) async {
    try {
      await _firestore
          .collection('challenges')
          .doc(challengeId)
          .update({'status': 'active'});
      debugPrint('Challenge accepted: $challengeId');
    } catch (e) {
      debugPrint('Error accepting challenge: $e');
      rethrow;
    }
  }

  // Submit a daily photo for verification
  Future<void> submitPhoto(
      String userId, String challengeId, XFile photo) async {
    try {
      final file = File(photo.path);
      final ref = _storage.ref().child(
          'challenge_photos/$challengeId/$userId/${DateTime.now().toIso8601String()}');
      await ref.putFile(file);
      final photoUrl = await ref.getDownloadURL();

      final today =
          DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      await _firestore
          .collection('challenges')
          .doc(challengeId)
          .collection('submissions')
          .add({
        'userId': userId,
        'photoUrl': photoUrl,
        'date': today,
        'verified': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('Photo submitted for $challengeId by $userId');
    } catch (e) {
      debugPrint('Error submitting photo: $e');
      rethrow;
    }
  }

  // Verify a friend's photo submission
  Future<void> verifyPhoto(
      String challengeId, String submissionId, bool isVerified) async {
    try {
      await _firestore
          .collection('challenges')
          .doc(challengeId)
          .collection('submissions')
          .doc(submissionId)
          .update({'verified': isVerified});

      if (isVerified) {
        final submissionDoc = await _firestore
            .collection('challenges')
            .doc(challengeId)
            .collection('submissions')
            .doc(submissionId)
            .get();
        final userId = submissionDoc['userId'] as String;

        final challengeDoc =
            await _firestore.collection('challenges').doc(challengeId).get();
        final senderId = challengeDoc['senderId'] as String;
        final fieldToUpdate =
            userId == senderId ? 'senderProgress' : 'receiverProgress';

        await _firestore
            .collection('challenges')
            .doc(challengeId)
            .update({fieldToUpdate: FieldValue.increment(1)});
      }
      debugPrint('Photo verification updated: $submissionId - $isVerified');
    } catch (e) {
      debugPrint('Error verifying photo: $e');
      rethrow;
    }
  }

  // Check challenge status and update XP
  Future<void> checkChallengeStatus(String challengeId) async {
    try {
      final challengeDoc =
          await _firestore.collection('challenges').doc(challengeId).get();
      final data = challengeDoc.data()!;
      final startDate = (data['startDate'] as Timestamp).toDate();
      final durationDays = data['durationDays'] as int;
      final senderId = data['senderId'] as String;
      final receiverId = data['receiverId'] as String;
      final senderProgress = data['senderProgress'] as int;
      final receiverProgress = data['receiverProgress'] as int;

      final daysElapsed = DateTime.now().difference(startDate).inDays;
      if (daysElapsed >= durationDays) {
        String? winner;
        if (senderProgress > receiverProgress) {
          winner = senderId;
        } else if (receiverProgress > senderProgress) {
          winner = receiverId;
        } // Tie = no winner

        await _firestore.collection('challenges').doc(challengeId).update({
          'status': 'completed',
          'winner': winner,
        });

        if (winner != null) {
          await _updateXP(winner, senderId == winner ? receiverId : senderId);
        }
      }
    } catch (e) {
      debugPrint('Error checking challenge status: $e');
      rethrow;
    }
  }

  Future<void> _updateXP(String winnerId, String loserId) async {
    const xpBoost = 50;
    const xpLoss = 10;

    await _firestore.collection('users').doc(winnerId).update({
      'xp': FieldValue.increment(xpBoost),
    });
    await _firestore.collection('users').doc(loserId).update({
      'xp': FieldValue.increment(-xpLoss),
    });
    debugPrint('XP updated: $winnerId +$xpBoost, $loserId -$xpLoss');
  }

  // Get active challenges for a user
  Stream<List<Map<String, dynamic>>> getChallenges(String userId) {
    return _firestore
        .collection('challenges')
        .where(Filter.or(
          Filter('senderId', isEqualTo: userId),
          Filter('receiverId', isEqualTo: userId),
        ))
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Get submissions for a challenge
  Stream<List<Map<String, dynamic>>> getSubmissions(String challengeId) {
    return _firestore
        .collection('challenges')
        .doc(challengeId)
        .collection('submissions')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }
}
