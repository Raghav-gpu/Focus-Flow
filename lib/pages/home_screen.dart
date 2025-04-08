import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/svg.dart';
import 'package:focus/pages/calendar_task_page.dart';
import 'package:focus/pages/chat_page.dart';
import 'package:focus/pages/friends_page.dart';
import 'package:focus/pages/survey_screen.dart';
import 'package:focus/services/streak_service.dart';
import 'package:focus/services/task_service.dart';
import 'package:focus/services/challenge_service.dart';
import 'package:focus/services/friend_service.dart';
import 'package:focus/widgets/progress_bar.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class FocusFlowHome extends StatefulWidget {
  const FocusFlowHome({super.key});

  @override
  _FocusFlowHomeState createState() => _FocusFlowHomeState();
}

class _FocusFlowHomeState extends State<FocusFlowHome> {
  final StreakService _streakService = StreakService();
  final ChallengeService _challengeService = ChallengeService();
  final User? user = FirebaseAuth.instance.currentUser;
  final List<String> greetings = [
    "Hey",
    "Yo",
    "Hola",
    "Sup",
    "Ayo",
    "Wagwan",
  ];
  late String randomGreeting;
  int? _lastLevel;

  @override
  void initState() {
    super.initState();
    randomGreeting = greetings[Random().nextInt(greetings.length)];
    _loadLastLevel();
  }

  Future<void> _loadLastLevel() async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastLevel = prefs.getInt('lastLevel_${user!.uid}') ?? 1;
    });
  }

  Future<void> _updateLastLevel(int newLevel) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastLevel_${user!.uid}', newLevel);
    setState(() {
      _lastLevel = newLevel;
    });
  }

  void _showLevelUpDialog(int newLevel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/level_animation.json',
                  width: 150,
                  height: 150,
                  repeat: true,
                ),
                const SizedBox(height: 20),
                Text(
                  "You leveled up to $newLevel!",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Keep up the progress—amazing work! 🚀",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Awesome!",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateGreetingFontSize(String text, double screenWidth) {
    const double maxFontSize = 0.06; // Reduced from 0.08
    const double minFontSize = 0.04;
    const double baseCharWidth = 10;

    final availableWidth = screenWidth * 0.7;
    final textLength = text.length;
    final estimatedWidth = textLength * baseCharWidth;

    final scaleFactor = availableWidth / estimatedWidth;
    final fontSize = maxFontSize * scaleFactor;

    return (fontSize.clamp(minFontSize, maxFontSize) * screenWidth).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final greetingText =
        '$randomGreeting, ${user!.displayName?.split(" ")[0] ?? "User"}';
    final greetingFontSize =
        _calculateGreetingFontSize(greetingText, screenWidth);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurveyScreen(userId: user!.uid),
                    ),
                  );
                }
              });
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final int currentLevel = data['level'] ?? 1;

            if (_lastLevel != null && currentLevel > _lastLevel!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showLevelUpDialog(currentLevel);
                  _updateLastLevel(currentLevel);
                }
              });
            }

            return Stack(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOut,
                  builder: (context, opacity, child) {
                    return Opacity(
                      opacity: opacity,
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(
                                'assets/images/focushomepagebg1.png'),
                            fit: BoxFit.cover,
                            opacity: 0.48,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.06,
                      vertical: screenHeight * 0.03,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: screenWidth * 0.06,
                              backgroundImage: user!.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null,
                              child: user!.photoURL == null
                                  ? Icon(
                                      Icons.person,
                                      size: screenWidth * 0.06,
                                      color: Colors.grey[400],
                                    )
                                  : null,
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Flexible(
                              child: Text(
                                greetingText,
                                style: TextStyle(
                                  fontSize: greetingFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.blue.withOpacity(0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        _buildXPSection(context, user!.uid),
                        SizedBox(height: screenHeight * 0.03),
                        _buildTasksSection(context, user!.uid),
                        SizedBox(height: screenHeight * 0.03),
                        _buildGenerateScheduleCard(context),
                        SizedBox(height: screenHeight * 0.03),
                        _buildChallengesSection(context, user!.uid),
                        SizedBox(height: screenHeight * 0.03),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildXPSection(BuildContext context, String userId) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.03), // Consistent padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.blueAccent.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey[400],
                ),
              ),
              FutureBuilder<int>(
                future: _streakService.calculateStreak(userId),
                builder: (context, snapshot) {
                  final streak = snapshot.data ?? 0;
                  return Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: Colors.orangeAccent,
                        size: screenWidth * 0.06, // Consistent icon size
                      ),
                      SizedBox(width: screenWidth * 0.01),
                      Text(
                        '$streak Day Streak',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          XPBar(userId: userId),
        ],
      ),
    );
  }

  Widget _buildTasksSection(BuildContext context, String userId) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final taskService = TaskService();

    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Tasks",
              style: TextStyle(
                fontSize: screenWidth * 0.055, // Increased from 0.045
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CalendarTaskPage(userId: userId)),
              ),
              child: Row(
                children: [
                  Text(
                    "View All",
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.white38,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: screenWidth * 0.04,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.015),
        SizedBox(
          height: screenHeight * 0.15,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: taskService.getTasks(userId).map(
                  (tasks) => tasks.where((task) {
                    final taskStart = (task['start'] as Timestamp).toDate();
                    final isCompleted = task['status'] == 'Completed' ||
                        task['completedAt'] != null;
                    return taskStart.isAfter(startOfToday) &&
                        taskStart.isBefore(endOfToday) &&
                        !isCompleted;
                  }).toList()
                    ..sort((a, b) =>
                        (a['start'] as Timestamp).compareTo(b['start'])),
                ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              CalendarTaskPage(userId: userId)),
                    ),
                    child: Container(
                      width: screenWidth * 0.85,
                      height: screenHeight * 0.15,
                      padding: EdgeInsets.all(
                          screenWidth * 0.03), // Consistent padding
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_task,
                            color: Colors.blueAccent,
                            size: screenWidth * 0.09, // Consistent icon size
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            "Add Task",
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "Tap to create a new task",
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[400],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final tasks = snapshot.data!;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final taskStart = (task['start'] as Timestamp).toDate();
                  final isCompleted = task['status'] == 'Completed' ||
                      task['completedAt'] != null;
                  final priority = task['priority'] ?? 'Low';
                  final priorityColor = _getPriorityColor(priority);

                  return Container(
                    width: screenWidth * (screenWidth > 600 ? 0.45 : 0.7),
                    margin: EdgeInsets.only(right: screenWidth * 0.03),
                    padding: EdgeInsets.all(
                        screenWidth * 0.03), // Consistent padding
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                DateFormat('h:mm a').format(taskStart),
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: Colors.grey[400],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              width: screenWidth * 0.03,
                              height: screenWidth * 0.03,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: priorityColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.005),
                        Flexible(
                          child: Text(
                            task['title'],
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.w500,
                              color:
                                  isCompleted ? Colors.grey[600] : Colors.white,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.005),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    CalendarTaskPage(userId: userId)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Details",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              Icon(
                                Icons.arrow_right,
                                size: screenWidth * 0.04,
                                color: Colors.blueAccent,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.yellow;
      case 'low':
      default:
        return Colors.green;
    }
  }

  Widget _buildGenerateScheduleCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatPage(userId: user!.uid)),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(screenWidth * 0.03), // Consistent padding
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.02),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      'assets/images/Assistant.svg',
                      width: screenWidth *
                          0.06, // Matches the consistent icon size
                      height: screenWidth * 0.06,
                      colorFilter: const ColorFilter.mode(
                        Colors.blueAccent, // Matches the original icon color
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Generate Schedule",
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "AI assistance with your schedule",
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.grey[400],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ChatPage(userId: user!.uid)),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.blueAccent],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.03,
                  vertical: screenWidth * 0.015,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: screenWidth * 0.04,
                      color: Colors.white,
                    ),
                    SizedBox(width: screenWidth * 0.01),
                    Text(
                      "Ask",
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesSection(BuildContext context, String userId) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final friendService = FriendService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Your Challenges",
              style: TextStyle(
                fontSize: screenWidth * 0.055, // Increased from 0.045
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const FriendsPage(initialTabIndex: 1)),
              ),
              child: Row(
                children: [
                  Text(
                    "All Challenges",
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.white38,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: screenWidth * 0.04,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.015),
        SizedBox(
          height: screenHeight * 0.20, // Increased from 0.15 to utilize space
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _challengeService.getChallenges(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const FriendsPage(initialTabIndex: 1)),
                    ),
                    child: Container(
                      width: screenWidth * 0.85,
                      height: screenHeight * 0.20,
                      padding: EdgeInsets.all(
                          screenWidth * 0.03), // Consistent padding
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: Colors.blueAccent,
                            size: screenWidth * 0.15, // Consistent icon size
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            "Challenge Friends",
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "Challenge your friends to exciting tasks!",
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[400],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final challenges = snapshot.data!
                  .where(
                      (c) => c['status'] == 'active') // Only active challenges
                  .toList();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: challenges.length,
                itemBuilder: (context, index) {
                  final challenge = challenges[index];
                  final isSender = challenge['senderId'] == userId;
                  final opponentId = isSender
                      ? challenge['receiverId']
                      : challenge['senderId'];
                  final myProgress = (isSender
                          ? challenge['senderProgress']
                          : challenge['receiverProgress']) as int? ??
                      0;
                  final durationDays = challenge['durationDays'] as int? ?? 1;
                  final endDateString = challenge['endDate'] as String?;
                  final endDate = endDateString != null
                      ? DateTime.tryParse(endDateString) ?? DateTime.now()
                      : DateTime.now();
                  final daysLeft = endDate
                      .difference(DateTime.now())
                      .inDays
                      .clamp(
                          0, durationDays); // Ensure non-negative, max duration
                  final title = challenge['title'] as String? ??
                      challenge['description'] as String? ??
                      'No Title';
                  final capitalizedTitle = title.isNotEmpty
                      ? title[0].toUpperCase() + title.substring(1)
                      : 'No Title';

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const FriendsPage(initialTabIndex: 1)),
                    ),
                    child: Container(
                      width: screenWidth * (screenWidth > 600 ? 0.45 : 0.7),
                      margin: EdgeInsets.only(right: screenWidth * 0.03),
                      padding: EdgeInsets.all(
                          screenWidth * 0.03), // Consistent padding
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(screenWidth * 0.02),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue, Colors.blueAccent],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.emoji_events,
                              color: Colors.white,
                              size: screenWidth * 0.06, // Consistent icon size
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        capitalizedTitle,
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.04,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    Text(
                                      "$daysLeft days left",
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                FutureBuilder<String?>(
                                  future: friendService.getUsername(opponentId),
                                  builder: (context, snapshot) {
                                    return Text(
                                      "vs ${snapshot.data ?? 'Opponent'}",
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        color: Colors.grey[400],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    );
                                  },
                                ),
                                SizedBox(height: screenHeight * 0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Progress",
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    Text(
                                      "$myProgress/$durationDays",
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: screenHeight * 0.015,
                                  child: LinearProgressIndicator(
                                    value: myProgress / durationDays,
                                    backgroundColor: Colors.grey[800],
                                    valueColor: const AlwaysStoppedAnimation(
                                        Colors.blueAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
