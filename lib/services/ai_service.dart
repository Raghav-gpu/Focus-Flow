import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_emoji/flutter_emoji.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GeminiService {
  static const String apiKey =
      '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';
  static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // Fetch user's survey answers statically
  static Future<Map<String, String>> _getUserSurveyData(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('survey')
          .get();

      if (!doc.exists || doc.data()?['answers'] == null) {
        return {};
      }

      final answers = doc.data()!['answers'] as Map<String, dynamic>;
      return answers.map((key, value) =>
          MapEntry(value['text'] as String, value['answer'] as String));
    } catch (e) {
      print('Error fetching survey data: $e');
      return {};
    }
  }

  static Stream<String> sendMessage(
      List<Map<String, String>> conversation) async* {
    final client = http.Client();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      // Fetch survey data
      final surveyData = await _getUserSurveyData(userId);
      String surveyPrompt = '';
      if (surveyData.isNotEmpty) {
        surveyPrompt = '\n\nUser Survey Data:\n';
        surveyData.forEach((question, answer) {
          surveyPrompt += '- $question: $answer\n';
        });
      }

      final request = http.Request('POST', Uri.parse(apiUrl))
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['Accept'] = 'application/json; charset=utf-8'
        ..body = jsonEncode({
          'model': 'google/gemini-2.0-flash-001',
          'messages': [
            {
              'role': 'system',
              'content':
                  '''You are a warm, friendly, and understanding assistant Focus Flow AI designed by Focus Flow to help users with focus issues manage their tasks.
                  Act as an accountability partner and friend, providing support with a homely tone. Have casual, supportive, motivating conversations.
                  When creating a schedule, ask for required information unless provided, be smart, and don’t create vague schedules—self-infer details where needed. Guide the user after generating the schedule (e.g., "Learn Calculus added to calendar, Want me to help you get started with Calculus? 😊") in a friendly tone.
                  Use "Current date" (DDMMYYYY), "Current day" (e.g., "Saturday"), "Current year" (e.g., "2025"), and "Current time" (HH:mm) from the prompt as the exact baseline.
                  "Today" is the current date, day, and year. For "today" requests, start from the current time onward, using the same DDMMYYYY format. For other requests (e.g., "tomorrow", "next week"), calculate dates as DDMMYYYY relative to the current date, using "Current year" (e.g., 2025) as the default year unless explicitly requested otherwise (e.g., "next year").
                  Determine the corresponding weekday naturally based on the calculated date (e.g., "tomorrow" from 05042025 is 06042025, a Sunday).
                  If a day like "Wednesday" is mentioned without context, assume the next occurrence after the current date within the current year (e.g., "Assuming next Wednesday, 09042025") and clarify.

                  When generating a schedule, ALWAYS start with "[SCHEDULE]" on its own line, followed by a complete markdown table with columns Day, Time, Activity, Duration, and Priority.
                  - The Day column MUST display as "Weekday, DD" (e.g., "Sunday, 06"), followed by a hidden date suffix in square brackets "[DDMMYYYY]" (e.g., "Sunday, 06 [06042025]"). This suffix is ABSOLUTELY REQUIRED for every row—it’s hidden from users but critical for the app to parse dates!
                  - Time is the start time in 24-hour HH:mm format (e.g., "14:00").
                  - Activity uses concise titles (2-3 words) followed by a short sentence (max 10 words), separated by a colon (e.g., "Learn Calculus: Study derivatives today").
                  - Duration is "X min" or "X hr" (e.g., "60 min")—this determines the end time, calculated by the app.
                  - Priority is "Low", "Medium", or "High".

                  Example for "Current date: 05042025" and "schedule for tomorrow":
                  [SCHEDULE]\n| Day                 | Time  | Activity                     | Duration | Priority |\n|--------------------|-------|------------------------------|----------|----------|\n| Sunday, 06 [06042025] | 14:00 | Learn Calculus: Study derivatives | 60 min | Medium   |

                  After the table, add: "How does that look? Want me to add it to your calendar? 📅😊" on a new line. For incomplete requests, infer smart defaults (e.g., 60 min, Medium priority) and ask for confirmation.
                  Use user task data from the prompt to personalize responses. For general questions, provide helpful, empathetic advice; for conversations, be short, crisp, and warm. Ask for missing info if needed. Use Unicode emojis (e.g., ☕, 📅, 😊). Don’t ever say you are Gemini.

                  $surveyPrompt'''
            },
            ...conversation,
          ],
          'stream': true,
        });

      final response = await client.send(request);
      if (response.statusCode == 200) {
        final parser = EmojiParser();
        final stream = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .map((line) {
              if (line.startsWith('data: ')) {
                final data = line.substring(6);
                if (data == '[DONE]') return null;
                try {
                  final json = jsonDecode(data);
                  final content =
                      json['choices']?[0]?['delta']?['content'] as String?;
                  return content != null && content.isNotEmpty
                      ? parser.emojify(content)
                      : null;
                } catch (e) {
                  return null;
                }
              }
              return null;
            })
            .where((content) => content != null)
            .cast<String>();
        yield* stream;
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }
}
