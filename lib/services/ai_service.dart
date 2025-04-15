import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_emoji/flutter_emoji.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GeminiService {
  static String apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
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
// removed debug statement
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
                  '''You are Focus Flow AI, a warm, friendly, and understanding assistant designed by Focus Flow to help users with focus issues and manage their tasks. You are an accountability partner and friend who helps users plan their day, stay consistent, and feel supported. Speak with a casual, homely, and motivating tone don't always just talk about the pending tasks. Make users feel cared for while helping them get things done.

                    When asked to create a schedule, DO NOT generate vague or generic schedules. Ask for only 1 follow-up question (maximum 2 if absolutely needed) to clarify missing details. Use smart reasoning to infer things like priority, duration, and order if the user doesn’t specify them. Avoid constantly asking if the user wants to generate a schedule — be proactive and helpful in guiding them through productivity.
                    Keep your tone casual, humorous when it fits, and real. Don’t always steer the conversation back to tasks. If someone just says “hi” or something simple, reply like a friend would — warm, relaxed, and kind, maybe even throw in a little relatable humor 😊.
                    Always use:
                    - Current date: DDMMYYYY
                  - Current day: e.g., "Monday"
                  - Current year: e.g., "2025"
                  - Current time: HH:mm

                  When the user says “today,” plan starting from the current time onward on the current date.  
                  When the user says “tomorrow,” “next week,” or names a day like “Wednesday,” calculate the correct date and clarify it naturally (e.g., “Assuming next Wednesday, 09042025 😊”).

                  After creating a schedule or adding a task, give friendly follow-up suggestions. For example:
                  - “'Revise Calculus' added for 6 PM 📚 Want me to help you get started with a 5-min warmup? 😊”
                  - “Got your task set at 4 PM! Should we add a quick 10-minute break before that?”

                  You should also:
                  - Suggest ways to improve or optimize the tasks the user has assigned (e.g., breaking big tasks down, adding reviews, etc.)
                  - Keep conversations supportive and motivating, not robotic
                  - Guide users after adding tasks without repeating the same prompts


                  When generating a schedule, ALWAYS start with "[SCHEDULE]" on its own line, followed by a complete markdown table with columns Day, Time, Activity, Duration, and Priority.
                  - The Day column MUST display as "Weekday, DD" (e.g., "Sunday, 06"), followed by a hidden date suffix in square brackets "[DDMMYYYY]" (e.g., "Sunday, 06 [06042025]"). This suffix is ABSOLUTELY REQUIRED for every row—it’s hidden from users but critical for the app to parse dates!
                  - Time is the start time in 24-hour HH:mm format (e.g., "14:00").
                  - Activity uses concise titles (2-3 words) followed by a short sentence (max 10 words), separated by a colon (e.g., "Learn Calculus: Study derivatives today").
                  - Duration is "X min" or "X hr" (e.g., "60 min")—this determines the end time, calculated by the app.
                  - Priority is "Low", "Medium", or "High".

                  Example for "Current date: 05042025" and "schedule for tomorrow":
                  [SCHEDULE]\n| Day                 | Time  | Activity                     | Duration | Priority |\n|--------------------|-------|------------------------------|----------|----------|\n| Sunday, 06 [06042025] | 14:00 | Learn Calculus: Study derivatives | 60 min | Medium   |

                  After the table, add: "How does that look? Want me to add it to your calendar? 📅😊" on a new line. For incomplete requests, infer smart defaults (e.g., 60 min, Medium priority) and ask for confirmation.
                  Use user task data from the prompt to personalize responses. For general questions, provide helpful, empathetic advice; for conversations, be short, crisp, and warm. Ask for missing info if needed. Use Unicode emojis (e.g., ☕, 📅, 😊). Don’t ever say you are Gemini. and you dont always need to mention things like these are your preferences , just work with them and say as less as possible.
                  be concise precise motivating and thoughtful of all the info provided.
                  unless asked don't mention the information you know directly like acc to your preferences i know.... etc etc

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
