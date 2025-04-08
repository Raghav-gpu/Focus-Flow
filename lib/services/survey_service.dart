import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class SurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch active survey questions from Firestore
  Future<List<Map<String, dynamic>>> getSurveyQuestions() async {
    try {
      final querySnapshot = await _firestore
          .collection('survey_questions')
          .where('active', isEqualTo: true)
          .orderBy('order')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching survey questions: $e');
      return [];
    }
  }

  // Check if user has completed the survey
  Future<bool> hasCompletedSurvey(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('survey')
          .get();
      return doc.exists && (doc.data()?['completed'] ?? false);
    } catch (e) {
      debugPrint('Error checking survey completion: $e');
      return false;
    }
  }

  // Save a single answer to Firestore
  Future<void> saveAnswer(String userId, String questionId, String questionText,
      String answer) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('survey')
          .set({
        'answers': {
          questionId: {
            'text': questionText,
            'answer': answer,
          }
        },
      }, SetOptions(merge: true));
      debugPrint('Saved answer for $questionId: $answer');
    } catch (e) {
      debugPrint('Error saving answer: $e');
      throw e;
    }
  }

  // Mark survey as completed
  Future<void> completeSurvey(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('survey')
          .set({
        'completed': true,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Survey marked as completed for user: $userId');
    } catch (e) {
      debugPrint('Error completing survey: $e');
      throw e;
    }
  }
}
