import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lottie/lottie.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, String> message;
  final Function(List<Map<String, dynamic>>, String) onAddToCalendar;
  final Function(String, String, String, String) onEditTask;
  final String userId;
  final bool isAddingSchedule; // Added for loading state
  final bool isScheduleAdded; // Added to track completion

  const MessageBubble({
    Key? key,
    required this.message,
    required this.onAddToCalendar,
    required this.onEditTask,
    required this.userId,
    required this.isAddingSchedule,
    required this.isScheduleAdded,
  }) : super(key: key);

  List<Map<String, dynamic>> parseSchedule(String scheduleText) {
// removed debug statement
    final lines = scheduleText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final tableStartIndex =
        lines.indexWhere((line) => line.contains('[SCHEDULE]'));
// removed debug statement
    if (tableStartIndex == -1) {
// removed debug statement
      return [];
    }

    final tableLines = lines
        .sublist(tableStartIndex + 1)
        .takeWhile((line) => line.contains('|') || line.trim().isEmpty)
        .where((line) => line.contains('|'))
        .toList();
// removed debug statement
    if (tableLines.length < 3) {
// removed debug statement
      return [];
    }

    final dataLines = tableLines.skip(2).toList();
// removed debug statement
    return dataLines.map((line) {
      final cells = line.split('|').map((cell) => cell.trim()).toList();
// removed debug statement
      DateTime? parsedDate;
      String dayText = cells.length > 1 ? cells[1] : '';
      final dateMatch = RegExp(r'\[(\d{8})\]').firstMatch(dayText);
      if (dateMatch != null) {
        final dateStr = dateMatch.group(1)!;
        try {
          final day = int.parse(dateStr.substring(0, 2));
          final month = int.parse(dateStr.substring(2, 4));
          final year = int.parse(dateStr.substring(4, 8));
          parsedDate = DateTime(year, month, day);
// removed debug statement
        } catch (e) {
// removed debug statement
        }
        dayText = dayText.replaceAll(RegExp(r'\s*\[\d{8}\]'), '').trim();
      }

      return {
        'day': dayText,
        'time': cells.length > 2 ? cells[2] : '',
        'activity': cells.length > 3 ? cells[3] : '',
        'duration': cells.length > 4 ? cells[4] : '',
        'priority': cells.length > 5 ? cells[5] : '',
        'date': parsedDate,
      };
    }).toList();
  }

  Map<String, String> parseEdit(String editText) {
// removed debug statement
    final lines = editText.split('\n');
    final task = lines[0].split(': ')[1];
    final time = lines[1].split(': ')[1];
    final priority = lines[2].split(': ')[1];
    return {'task': task, 'time': time, 'priority': priority};
  }

  Widget buildScheduleTable(List<Map<String, dynamic>> scheduleRows) {
// removed debug statement
    if (scheduleRows.isEmpty) {
// removed debug statement
      return const Text('No schedule data found!',
          style: TextStyle(color: Colors.white));
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border:
              TableBorder.all(color: Colors.white.withOpacity(0.5), width: 1),
          columnWidths: const {
            0: FixedColumnWidth(120),
            1: FixedColumnWidth(140),
            2: FixedColumnWidth(240),
            3: FixedColumnWidth(100),
            4: FixedColumnWidth(100),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4)),
              children: [
                _tableCell('Day', isHeader: true),
                _tableCell('Time', isHeader: true),
                _tableCell('Activity', isHeader: true),
                _tableCell('Duration', isHeader: true),
                _tableCell('Priority', isHeader: true),
              ],
            ),
            ...scheduleRows
                .map((row) => TableRow(
                      decoration: row['day']!.isNotEmpty
                          ? null
                          : BoxDecoration(
                              color: Colors.black.withOpacity(0.05)),
                      children: [
                        _tableCell(row['day'] ?? ''),
                        _tableCell(row['time'] ?? ''),
                        _tableCell(row['activity'] ?? ''),
                        _tableCell(row['duration'] ?? ''),
                        _tableCell(row['priority'] ?? ''),
                      ],
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  TextSpan _parseMarkdown(String text) {
    final spans = <TextSpan>[];
    final parts = text.split(RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*)'));

    for (final part in parts) {
      if (part.isEmpty) continue;
      if (part.startsWith('**') && part.endsWith('**')) {
        spans.add(TextSpan(
          text: part.substring(2, part.length - 2),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (part.startsWith('*') && part.endsWith('*')) {
        spans.add(TextSpan(
          text: part.substring(1, part.length - 1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: part,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ));
      }
    }

    return TextSpan(children: spans);
  }

  Widget _buildFormattedText(String text) {
    String cleanedText = text.trim();
    if (cleanedText.startsWith('```markdown')) {
      cleanedText = cleanedText.substring(11);
    }
    if (cleanedText.endsWith('```')) {
      cleanedText = cleanedText.substring(0, cleanedText.length - 3);
    }
    cleanedText = cleanedText.trim();

    final lines = cleanedText.split('\n');
    final children = <Widget>[];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        children.add(const SizedBox(height: 4));
        continue;
      }
      if (trimmedLine.startsWith('-') || trimmedLine.startsWith('*')) {
        final content = trimmedLine.substring(1).trim();
        children.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            Expanded(
              child: RichText(
                text: _parseMarkdown(content),
              ),
            ),
          ],
        ));
      } else if (!trimmedLine.contains('|')) {
        children.add(RichText(
          text: _parseMarkdown(trimmedLine),
        ));
      }
      if (line != lines.last) {
        children.add(const SizedBox(height: 4));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message['sender'] == 'user';
    final time = DateTime.parse(message['time']!);
    final text = message['text']!;
    final screenWidth = MediaQuery.of(context).size.width;
    debugPrint(
        'Building message bubble: sender=${message['sender']}, text=$text');

    Widget content;
    if (isUser) {
// removed debug statement
      content = _buildFormattedText(text);
    } else {
// removed debug statement
      // Show "Thinking..." if text is empty (initial AI message state)
      if (text.isEmpty) {
        content = const Text(
          'Thinking...',
          style: TextStyle(
            color: Colors.grey, // Greyish color
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        );
      } else if (text.contains('[SCHEDULE]')) {
// removed debug statement
        final preScheduleText =
            text.substring(0, text.indexOf('[SCHEDULE]')).trim();
        final scheduleText = text.substring(text.indexOf('[SCHEDULE]')).trim();
        final scheduleRows = parseSchedule(scheduleText);
        final postScheduleText = scheduleText.contains('How does that look?')
            ? scheduleText
                .substring(scheduleText.indexOf('How does that look?'))
                .trim()
            : '';
// removed debug statement
// removed debug statement
// removed debug statement
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preScheduleText.isNotEmpty) ...[
              _buildFormattedText(preScheduleText),
              const SizedBox(height: 8),
            ],
            const Text('Suggested Schedule:',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            buildScheduleTable(scheduleRows),
            const SizedBox(height: 8),
            if (!isScheduleAdded) // Only show if not added
              isAddingSchedule
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Lottie.asset(
                            'assets/animations/loading_animation.json',
                            fit: BoxFit.contain,
                            repeat: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Adding...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: () => onAddToCalendar(scheduleRows, userId),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.8)),
                      child: const Text('Add to Calendar'),
                    ),
            if (postScheduleText.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildFormattedText(postScheduleText),
            ],
          ],
        );
      } else if (text.startsWith('[EDIT]')) {
// removed debug statement
        final editText = text.substring(6).trim();
        final editDetails = parseEdit(editText);
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormattedText(editText),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => onEditTask(editDetails['task']!,
                  editDetails['time']!, editDetails['priority']!, userId),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.8)),
              child: const Text('Confirm Edit'),
            ),
          ],
        );
      } else {
// removed debug statement
        content = _buildFormattedText(text);
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: isUser ? screenWidth * 0.6 : screenWidth * 0.9,
      ),
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser
            ? Colors.blue.withOpacity(0.2)
            : Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isUser
                ? Colors.blue.withOpacity(0.3)
                : Colors.blue.withOpacity(0.5),
            spreadRadius: isUser ? 1 : 2,
            blurRadius: isUser ? 8 : 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [content],
      ),
    );
  }
}
