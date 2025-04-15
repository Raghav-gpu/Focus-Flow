import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'friend_service.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _challengesCollection = 'challenges';

  // Create a new challenge (unchanged)
  Future<void> createChallenge(
    String senderId,
    String receiverId,
    String title, // Add title parameter
    String description,
    int durationDays,
  ) async {
    try {
      final now = DateTime.now();
      await _firestore.collection(_challengesCollection).add({
        'senderId': senderId,
        'receiverId': receiverId,
        'title': title, // Store title
        'description': description,
        'durationDays': durationDays,
        'startDate': now.toIso8601String(),
        'endDate': now.add(Duration(days: durationDays)).toIso8601String(),
        'status': 'pending',
        'senderProgress': 0,
        'receiverProgress': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'winner': null,
      });
      debugPrint(
          'Challenge created: senderId=$senderId, receiverId=$receiverId, title=$title, description=$description');
    } catch (e) {
// removed debug statement
      rethrow;
    }
  }

  // Accept a challenge (unchanged)
  Future<void> acceptChallenge(String challengeId) async {
    try {
      await _firestore
          .collection(_challengesCollection)
          .doc(challengeId)
          .update({
        'status': 'active',
      });
// removed debug statement
    } catch (e) {
// removed debug statement
      rethrow;
    }
  }

  // Decline a challenge (unchanged)
  Future<void> declineChallenge(String challengeId) async {
    try {
      await _firestore
          .collection(_challengesCollection)
          .doc(challengeId)
          .delete();
// removed debug statement
    } catch (e) {
// removed debug statement
      rethrow;
    }
  }

  // Exit a challenge (unchanged)
  Future<void> exitChallenge(String challengeId, String userId) async {
    try {
      final challengeDoc = await _firestore
          .collection(_challengesCollection)
          .doc(challengeId)
          .get();
      if (challengeDoc.exists) {
        final challengeData = challengeDoc.data() as Map<String, dynamic>;
        final senderId = challengeData['senderId'] as String;
        final receiverId = challengeData['receiverId'] as String;
        final opponentId = userId == senderId ? receiverId : senderId;

        await _firestore
            .collection(_challengesCollection)
            .doc(challengeId)
            .update({
          'status': 'exited',
          'winner': opponentId,
          'exitedBy': userId,
        });
        debugPrint(
            'Challenge exited: challengeId=$challengeId, exitedBy=$userId, winner=$opponentId');
      }
    } catch (e) {
// removed debug statement
      rethrow;
    }
  }

  // Complete a challenge (updated)
  Future<void> completeChallenge(String challengeId) async {
    try {
      final challengeDoc = await _firestore
          .collection(_challengesCollection)
          .doc(challengeId)
          .get();
      if (challengeDoc.exists) {
        final challengeData = challengeDoc.data() as Map<String, dynamic>;
        final senderProgress = challengeData['senderProgress'] as int? ?? 0;
        final receiverProgress = challengeData['receiverProgress'] as int? ?? 0;
        final senderId = challengeData['senderId'] as String;
        final receiverId = challengeData['receiverId'] as String;
        final endDateString = challengeData['endDate'] as String?;
        final endDate = endDateString != null
            ? DateTime.parse(endDateString)
            : DateTime.now();
        final currentStatus = challengeData['status'] as String? ?? 'pending';

        if (DateTime.now().isAfter(endDate) &&
            currentStatus != 'completed' &&
            currentStatus != 'exited') {
          String? winner;
          if (senderProgress > receiverProgress) {
            winner = senderId;
          } else if (receiverProgress > senderProgress) {
            winner = receiverId;
          } else {
            winner = 'tie';
          }

          // Update challenge status and winner
          await _firestore
              .collection(_challengesCollection)
              .doc(challengeId)
              .update({
            'status': 'completed',
            'winner': winner,
          });

          // Award 100 XP to the winner if there is one (not a tie)
          if (winner != 'tie') {
            await _firestore.collection('users').doc(winner).update({
              'xp': FieldValue.increment(100),
            });
// removed debug statement
          }

          debugPrint(
              'Challenge completed: challengeId=$challengeId, winner=$winner');
        }
      }
    } catch (e) {
// removed debug statement
      rethrow;
    }
  }

  // Check if user can submit a photo today (updated)
  Future<bool> canSubmitPhoto(String userId, String challengeId) async {
    try {
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day); // Midnight today
      final endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1)); // 23:59:59 today

      final submissionsSnapshot = await _firestore
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection('submissions')
          .where('userId', isEqualTo: userId)
          .where('timestamp',
              isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('timestamp', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (submissionsSnapshot.docs.isEmpty) {
        debugPrint(
            'No submissions today for challengeId=$challengeId, userId=$userId. Can submit.');
        return true; // No submissions today, allow one
      }

      final latestSubmission = submissionsSnapshot.docs.first.data();
      final verified = latestSubmission['verified'];

      // If the latest submission is pending or approved, block further submissions today
      // Allow only if rejected
      final canSubmit = verified == false; // false means rejected
      debugPrint(
          'Latest submission for challengeId=$challengeId, userId=$userId: verified=$verified, canSubmit=$canSubmit');
      return canSubmit;
    } catch (e) {
// removed debug statement
      return false; // Default to false on error to prevent accidental submissions
    }
  }

  // Submit a photo for a challenge (updated)
  Future<void> submitPhoto(
      String userId, String challengeId, XFile photo) async {
    try {
      final canSubmit = await canSubmitPhoto(userId, challengeId);
      if (!canSubmit) {
        throw Exception(
            'You can only submit one photo per day per challenge unless the previous one is rejected.');
      }

      final storageRef = _storage.ref().child(
          'challenges/$challengeId/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final Uint8List bytes = await photo.readAsBytes();
      final UploadTask uploadTask = storageRef.putData(bytes);
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      final String downloadURL = await snapshot.ref.getDownloadURL();

      final submissionData = {
        'userId': userId,
        'photoUrl': downloadURL,
        'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'timestamp':
            DateTime.now().toIso8601String(), // Use ISO string for consistency
        'verified': null, // Pending verification
      };

      final submissionRef = await _firestore
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection('submissions')
          .add(submissionData);
      debugPrint(
          'Photo submitted: challengeId=$challengeId, submissionId=${submissionRef.id}, data=$submissionData');
    } catch (e) {
// removed debug statement
      rethrow;
    }
  }

  // Verify a submitted photo (unchanged)
  Future<void> verifyPhoto(
      String challengeId, String submissionId, bool isVerified) async {
    try {
      // Update the submission's verified status
      await _firestore
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection('submissions')
          .doc(submissionId)
          .update({'verified': isVerified});
      debugPrint(
          'Photo verified: challengeId=$challengeId, submissionId=$submissionId, verified=$isVerified');

      // If approved, increment the user's progress
      if (isVerified) {
        final submissionDoc = await _firestore
            .collection(_challengesCollection)
            .doc(challengeId)
            .collection('submissions')
            .doc(submissionId)
            .get();
        final userId = submissionDoc.data()!['userId'] as String;

        final challengeDoc = await _firestore
            .collection(_challengesCollection)
            .doc(challengeId)
            .get();
        if (challengeDoc.exists) {
          final challengeData = challengeDoc.data() as Map<String, dynamic>;
          final senderId = challengeData['senderId'] as String;
          final receiverId = challengeData['receiverId'] as String;

          final fieldToUpdate =
              userId == senderId ? 'senderProgress' : 'receiverProgress';
          await _firestore
              .collection(_challengesCollection)
              .doc(challengeId)
              .update({
            fieldToUpdate: FieldValue.increment(1),
          });
// removed debug statement
        }
      }
    } catch (e) {
// removed debug statement
      rethrow;
    }
  }

  // Get all challenges for a user (unchanged)
  Stream<List<Map<String, dynamic>>> getChallenges(String userId) {
    return _firestore
        .collection(_challengesCollection)
        .where(Filter.or(
          Filter('senderId', isEqualTo: userId),
          Filter('receiverId', isEqualTo: userId),
        ))
        .snapshots()
        .map((snapshot) {
      final challenges =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      return challenges;
    });
  }

  // Get submissions (unchanged)
  Stream<List<Map<String, dynamic>>> getSubmissions(String challengeId) {
    return _firestore
        .collection(_challengesCollection)
        .doc(challengeId)
        .collection('submissions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // Get pending verifications (unchanged)
  Stream<List<Map<String, dynamic>>> getPendingVerifications(String userId) {
    return _firestore
        .collection(_challengesCollection)
        .where('status', isEqualTo: 'active')
        .where(Filter.or(
          Filter('senderId', isEqualTo: userId),
          Filter('receiverId', isEqualTo: userId),
        ))
        .snapshots()
        .asyncMap((challengeSnapshot) async {
      final verifications = <Map<String, dynamic>>[];
      for (final challengeDoc in challengeSnapshot.docs) {
        final challengeId = challengeDoc.id;
        final challengeData = challengeDoc.data();
        final senderId = challengeData['senderId'] as String;
        final receiverId = challengeData['receiverId'] as String;
        final opponentId = userId == senderId ? receiverId : senderId;

        final submissions = await _firestore
            .collection(_challengesCollection)
            .doc(challengeId)
            .collection('submissions')
            .where('userId', isEqualTo: opponentId)
            .where('verified', isNull: true) // Only pending submissions
            .get();

        for (final submissionDoc in submissions.docs) {
          final senderName =
              await FriendService().getUsername(opponentId) ?? 'Unknown';
          final data = submissionDoc.data();
          verifications.add({
            'challengeId': challengeId,
            'submissionId': submissionDoc.id,
            'challengeTitle': challengeData['description'] ?? 'No Title',
            'senderId': opponentId,
            'senderName': senderName,
            'photoUrl': data['photoUrl'],
            'date': data['date'],
          });
        }
      }
// removed debug statement
      return verifications;
    });
  }

  // Get verification details (unchanged)
  Future<Map<String, dynamic>> getVerificationDetails(
      String challengeId, String submissionId) async {
    final challengeDoc = await _firestore
        .collection(_challengesCollection)
        .doc(challengeId)
        .get();
    final submissionDoc = await _firestore
        .collection(_challengesCollection)
        .doc(challengeId)
        .collection('submissions')
        .doc(submissionId)
        .get();

    final senderId = challengeDoc.data()!['senderId'] as String;
    final senderName = await FriendService().getUsername(senderId) ?? 'Unknown';

    return {
      'challengeId': challengeId,
      'submissionId': submissionId,
      'challengeTitle': challengeDoc.data()!['description'] ?? 'No Title',
      'senderId': senderId,
      'senderName': senderName,
      'photoUrl': submissionDoc.data()!['photoUrl'],
      'date': submissionDoc.data()!['date'],
    };
  }

  // Get verified submissions (unchanged)
  Stream<List<Map<String, dynamic>>> getVerifiedSubmissions(
      String challengeId) {
    return _firestore
        .collection(_challengesCollection)
        .doc(challengeId)
        .collection('submissions')
        .where('verified', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> removeChallenge(String challengeId) async {
    try {
      await _firestore
          .collection(_challengesCollection)
          .doc(challengeId)
          .delete();
// removed debug statement
    } catch (e) {
// removed debug statement
      rethrow;
    }
  }
}
