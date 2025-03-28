// lib/pages/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:focus/pages/calendar_task_page.dart';
import 'package:focus/pages/chat_page.dart';
import 'package:focus/pages/friends_page.dart'; // Add this import
import 'package:focus/pages/setting_screen.dart';
import 'package:focus/services/streak_service.dart';
import 'package:focus/widgets/generate_schedule_card.dart';
import 'package:focus/widgets/progress_bar.dart';
import 'package:focus/widgets/top_tasks.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class FocusFlowHome extends StatefulWidget {
  @override
  _FocusFlowHomeState createState() => _FocusFlowHomeState();
}

class _FocusFlowHomeState extends State<FocusFlowHome> {
  final StreakService _streakService = StreakService();
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      // Subscribe to FCM topic
      FirebaseMessaging.instance.subscribeToTopic(user!.uid).then((_) {
        debugPrint('Successfully subscribed to topic: ${user!.uid}');
      }).catchError((error) {
        debugPrint('Error subscribing to topic: $error');
      });

      // Log FCM token
      FirebaseMessaging.instance.getToken().then((token) {
        debugPrint('FCM Token: $token');
      });

      // Handle app opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
            'App opened from notification: ${message.notification?.title}');
        // Optionally navigate to task details using message.data['taskId']
        if (message.data['taskId'] != null) {
          // Navigator.push(context, ...); // Add navigation logic if needed
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/focushomepagebg1.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (user!.photoURL != null)
                        CircleAvatar(
                          backgroundImage: NetworkImage(user!.photoURL!),
                          radius: screenWidth * 0.07,
                        )
                      else
                        Image.asset(
                          'assets/images/icon.png',
                          width: screenWidth * 0.12,
                          height: screenWidth * 0.12,
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(screenWidth * 0.02),
                          child: XPBar(userId: user!.uid),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hello,",
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontSize: screenWidth * 0.09,
                            color: Theme.of(context).hintColor,
                            height: 0.9),
                      ),
                      Text(
                        user!.displayName?.split(" ")[0] ?? "User",
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontSize: screenWidth * 0.15,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      FutureBuilder<int>(
                        future: _streakService.calculateStreak(user!.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.03,
                                  vertical: screenHeight * 0.01),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.blueAccent,
                                    width: screenWidth * 0.005),
                              ),
                              child: const CircularProgressIndicator(),
                            );
                          }
                          final streak = snapshot.data ?? 0;
                          return Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.03,
                                vertical: screenHeight * 0.01),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.blueAccent,
                                  width: screenWidth * 0.005),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department,
                                    color: Colors.orangeAccent,
                                    size: screenWidth * 0.05),
                                SizedBox(width: screenWidth * 0.015),
                                Text(
                                  "$streak-Day Streak",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .copyWith(
                                          fontSize: screenWidth * 0.05,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTaskSection(context, user!.uid)),
                          SizedBox(width: screenWidth * 0.08),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) =>
                                      ChatPage(userId: user!.uid),
                                ),
                              );
                            },
                            child: GenerateScheduleCard(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBottomIcon(context, Icons.settings, SettingsPage()),
                      _buildBottomIcon(context, Icons.task_alt,
                          CalendarTaskPage(userId: user!.uid)),
                      _buildBottomIcon(
                          context, Icons.chat, ChatPage(userId: user!.uid)),
                      _buildBottomIcon(context, Icons.people,
                          const FriendsPage()), // Added Friends icon
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSection(BuildContext context, String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoTasksCard(context);
        }
        return CompactTaskList(userId: userId);
      },
    );
  }

  Widget _buildNoTasksCard(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => CalendarTaskPage(
                userId: FirebaseAuth.instance.currentUser!.uid),
          ),
        );
      },
      child: Container(
        height: screenHeight * 0.25,
        width: screenWidth * 0.375,
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blueAccent, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withOpacity(1),
              spreadRadius: 1,
              blurRadius: 20,
            ),
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.87),
              spreadRadius: -2,
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_task,
                color: Colors.white70, size: screenWidth * 0.1),
            SizedBox(height: screenHeight * 0.01),
            Text(
              "No Tasks Yet!",
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              "Tap here to add some tasks",
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: screenWidth * 0.04, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIcon(BuildContext context, IconData icon, Widget page) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => page),
        );
      },
      child: Icon(
        icon,
        color: Colors.white70,
        size: MediaQuery.of(context).size.width * 0.08,
      ),
    );
  }
}
