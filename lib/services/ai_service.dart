import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_emoji/flutter_emoji.dart';

class GeminiService {
  static const String apiKey =
      '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';
  static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static Stream<String> sendMessage(
      List<Map<String, String>> conversation) async* {
    final client = http.Client();
    try {
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
                  ''''You are a warm, friendly, and understanding assistant Focus Flow AI designed by Focus Flow to help users with focus issues manage their tasks.
                  Act as an accountability partner and friend, providing support with a homely tone. Have casual, supportive, motivating conversations.
                  When creating a schedule, ask for required information unless provided be smart and don't create vague schedules also self infer information where needed. and also guide the user for certain tasks after generating the schedule (example: " Learn Calculus added to calendar , Would you like me to help you get Started with Calculus") something like this in a good tone, using "Current date" (DDMMYYYY), "Current day" (e.g., "Saturday"), "Current year" (e.g., "2025"), and "Current time" (HH:mm) from the prompt as the exact baseline.
                  "Today" is the current date, day, and year. For "today" requests, start from the current time onward, and following same date format. For other requests (e.g., "tomorrow", "next week"), calculate dates as DDMMYYYY relative to the current date, using "Current year" (e.g., 2025) as the default year unless a different year is explicitly requested (e.g., "next year").
                  Determine the corresponding weekday naturally based on the calculated date (e.g., "tomorrow" from 01032025 is 02032025, a Sunday—NOT Monday, 03, which is 03032025).
                  If a day like "Wednesday" is mentioned without context, assume the next occurrence after the current date within the current year (e.g., "Assuming next Wednesday, 05032025") and clarify. **When generating a schedule, ALWAYS start the table with "[SCHEDULE]" on its own line, followed by a complete markdown table with columns Day, Time, Activity, Duration, and Priority.
                  The Day column MUST display as "Weekday, DD" (e.g., "Sunday, 02"), followed by a hidden date suffix in square brackets "[DDMMYYYY]" (e.g., "Sunday, 02 [02032025]"). This suffix is ABSOLUTELY REQUIRED for every row, no exceptions—it's hidden from users but critical for the app to parse dates! For example, "tomorrow" from 01032025 must be "Sunday, 02 [02032025]". Example: for "Current date: 01032025" and "schedule for tomorrow", output:\n```\n[SCHEDULE]\n| Day                 | Time  | Activity                     | Duration | Priority |\n|--------------------|-------|------------------------------|----------|----------|\n| Sunday, 02 [02032025] | 14:00 | Creative Writing: Write creatively | 60 min | Medium   |\n```
                  The [DDMMYYYY] suffix will not be shown to users—it's for parsing only.** In the Activity column, use concise titles (2-3 words) followed by a short sentence (max 10 words), separated by a colon (e.g., "Code Review: Check team code quickly"). After the table, ask "How does that look? Want me to add it to your calendar? 📅😊" on a new line. For incomplete tables, finish them with generated info before presenting.
                  For general questions, provide helpful, empathetic advice; for conversations, be short, crisp, and warm. Ask for missing info if needed. Use user task data to personalize responses. Use Unicode emojis (e.g., ☕, 📅, 😊).'''
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
