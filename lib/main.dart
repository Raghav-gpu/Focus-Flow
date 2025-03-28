import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; // Add Analytics import
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:focus/pages/SetUsernameScreen.dart';
import 'package:focus/pages/login_screen.dart';
import 'package:focus/pages/main_screen.dart';
import 'package:focus/pages/sign_up_screen.dart';
import 'package:focus/pages/friends_page.dart';
import 'package:focus/services/firebase_auth_methods.dart';
import 'package:focus/services/notification_service.dart';
import 'package:focus/theme.dart';
import 'package:flutter/foundation.dart' show debugPrint;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.notification?.title}');
  // FCM handles display in background/terminated states
}

Future<void> showNotification(RemoteMessage message) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
    debugPrint('Notification tapped with payload: ${response.payload}');
  });

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'focusflow_channel',
    'FocusFlow Notifications',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    showWhen: true,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  final notificationId = (message.data['challengeId'] ??
          message.data['requestId'] ??
          message.data['date'] ??
          '0')
      .hashCode;

  await flutterLocalNotificationsPlugin.show(
    notificationId,
    message.notification?.title ?? 'No Title',
    message.notification?.body ?? 'No Body',
    platformChannelSpecifics,
    payload: jsonEncode(message.data),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Firebase Analytics
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver analyticsObserver =
      FirebaseAnalyticsObserver(analytics: analytics);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final notificationService = NotificationService();
  await notificationService.initialize();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
    if (message.notification != null) {
      showNotification(message);
    }
  });

  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      debugPrint(
          'App opened from terminated state: ${message.notification?.title}');
      _handleNotificationTap(message);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('App opened from background: ${message.notification?.title}');
    _handleNotificationTap(message);
  });

  runApp(MyApp(analyticsObserver: analyticsObserver));
}

void _handleNotificationTap(RemoteMessage message) {
  final data = message.data;
  final type = data['type'];
  final navigatorKey = GlobalKey<NavigatorState>();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'friend_request':
      case 'friend_accepted':
      case 'friend_rejected':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const FriendsPage(initialTabIndex: 0)),
        );
        break;
      case 'challenge_sent':
      case 'challenge_accepted':
      case 'challenge_declined':
      case 'photo_submitted':
      case 'photo_verified':
      case 'photo_declined':
      case 'challenge_won':
      case 'challenge_lost':
      case 'challenge_tied':
      case 'challenge_exited':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const FriendsPage(initialTabIndex: 1)),
        );
        break;
      case 'daily_tip':
      case 'task_reminder':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
        break;
      default:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
    }
  });
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final FirebaseAnalyticsObserver analyticsObserver;

  MyApp({required this.analyticsObserver});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'FocusFlow',
      theme: FocusFlowTheme.darkTheme,
      home: AuthWrapper(),
      navigatorObservers: [analyticsObserver], // Enable screen tracking
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignUpScreen(),
        '/home': (context) => const MainScreen(),
        '/friends': (context) => const FriendsPage(initialTabIndex: 0),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          FirebaseMessaging.instance.subscribeToTopic(user.uid);
          return FutureBuilder<String?>(
            future: _authService.getUsername(user.uid),
            builder: (context, usernameSnapshot) {
              if (usernameSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (usernameSnapshot.data == null) {
                return SetUsernameScreen();
              }
              return const MainScreen();
            },
          );
        }
        return LoginPage();
      },
    );
  }
}
