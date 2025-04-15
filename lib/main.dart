import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:focus/pages/login_screen.dart';

import 'package:focus/pages/friends_page.dart';
import 'package:focus/pages/survey_screen.dart';
import 'package:focus/pages/home_screen.dart';
import 'package:focus/pages/calendar_task_page.dart';
import 'package:focus/pages/chat_page.dart';
import 'package:focus/pages/setting_screen.dart';

import 'package:focus/theme.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:focus/widgets/navigation_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Background message: ${message.notification?.title}');
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (kDebugMode) {
        print('Local notification tapped: ${response.payload}');
      }
    },
  );

  // Create Android notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'focusflow_channel',
    'FocusFlow Notifications',
    importance: Importance.max,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver analyticsObserver =
      FirebaseAnalyticsObserver(analytics: analytics);

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final prefs = await SharedPreferences.getInstance();
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await prefs.setBool('is_fresh_start_${user.uid}', true);
  }

  runApp(
    MyApp(analyticsObserver: analyticsObserver, navigatorKey: navigatorKey),
  );
}

void _handleNotificationTap(
    RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
  final data = message.data;
  final type = data['type'];

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
// removed debug statement
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
      case 'custom_notification':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FocusFlowHome()),
        );
        break;
      default:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FocusFlowHome()),
        );
    }
  });
}

class MyApp extends StatefulWidget {
  final FirebaseAnalyticsObserver analyticsObserver;
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({
    required this.analyticsObserver,
    required this.navigatorKey,
    super.key,
  });

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    await FirebaseMessaging.instance.requestPermission();
// removed debug statement
    NotificationSettings settings =
        await FirebaseMessaging.instance.getNotificationSettings();
// removed debug statement
    await FirebaseMessaging.instance.subscribeToTopic('all_users');
// removed debug statement
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        await FirebaseMessaging.instance.subscribeToTopic(user.uid);
// removed debug statement
      } else {
// removed debug statement
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
// removed debug statement
// removed debug statement
      if (message.notification != null) {
// removed debug statement
        // Display foreground notification
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
          'focusflow_channel',
          'FocusFlow Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
        const NotificationDetails platformDetails =
            NotificationDetails(android: androidDetails);
        flutterLocalNotificationsPlugin.show(
          message.messageId.hashCode,
          message.notification!.title,
          message.notification!.body,
          platformDetails,
        );
      }
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print(
            'App opened from terminated state: ${message.notification?.title}');
        _handleNotificationTap(message, widget.navigatorKey);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
// removed debug statement
      _handleNotificationTap(message, widget.navigatorKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      navigatorObservers: [widget.analyticsObserver],
      debugShowCheckedModeBanner: false,
      title: 'FocusFlow',
      theme: FocusFlowTheme.darkTheme,
      home: authWrapper(),
    );
  }
}

Widget authWrapper() {
  return StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, authSnapshot) {
      debugPrint(
          'Auth state: ${authSnapshot.connectionState}, hasData: ${authSnapshot.hasData}');
      if (authSnapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!authSnapshot.hasData) {
// removed debug statement
        return const LoginPage();
      }
      final userId = authSnapshot.data!.uid;
// removed debug statement
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('preferences')
            .doc('survey')
            .snapshots(),
        builder: (context, surveySnapshot) {
          debugPrint(
              'Survey snapshot state: ${surveySnapshot.connectionState}, hasData: ${surveySnapshot.hasData}, exists: ${surveySnapshot.data?.exists}, error: ${surveySnapshot.error}');

          // Wait until the survey stream is active
          if (surveySnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          // Handle errors
          if (surveySnapshot.hasError) {
// removed debug statement
            return const Scaffold(
                body: Center(child: Text('Error loading survey data')));
          }

          // If no survey document exists or 'completed' isn’t true, show SurveyScreen
          final surveyData =
              surveySnapshot.hasData && surveySnapshot.data!.exists
                  ? surveySnapshot.data!.data() as Map<String, dynamic>?
                  : null;
          final surveyCompleted = surveyData?['completed'] as bool? ?? false;

          debugPrint(
              'Survey document exists: ${surveySnapshot.hasData && surveySnapshot.data!.exists}, completed: $surveyCompleted');

          if (!surveyCompleted) {
            debugPrint(
                'Survey not completed for user $userId, showing SurveyScreen');
            return SurveyScreen(userId: userId);
          }

          debugPrint(
              'Survey completed for user $userId, showing MainAppWrapper');
          return const NavigationWrapper();
        },
      );
    },
  );
}

class MainAppWrapper extends StatefulWidget {
  const MainAppWrapper({super.key});

  @override
  _MainAppWrapperState createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> {
  int _selectedIndex = 0;
  bool isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _setupConnectivityMonitoring();
  }

  void _setupConnectivityMonitoring() async {
    await _updateConnectivityStatus();

    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          (List<ConnectivityResult> results) {
// removed debug statement
        _handleConnectivityChange(results);
      }, onError: (e) {
// removed debug statement
        _startFallbackTimer();
      });
    } catch (e) {
// removed debug statement
      _startFallbackTimer();
    }
  }

  void _startFallbackTimer() {
    if (_fallbackTimer == null || !_fallbackTimer!.isActive) {
      _fallbackTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted) {
          _fallbackConnectivityCheck();
// removed debug statement
        }
      });
    }
  }

  Future<void> _updateConnectivityStatus() async {
    try {
      final results = await Connectivity().checkConnectivity();
// removed debug statement
      await _handleConnectivityChange(results);
    } catch (e) {
// removed debug statement
      _fallbackConnectivityCheck();
    }
  }

  Future<bool> _checkActualInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
  }

  Future<void> _fallbackConnectivityCheck() async {
    bool hasInternet = await _checkActualInternet();
    if (mounted && isOffline != !hasInternet) {
      setState(() {
        isOffline = !hasInternet;
        debugPrint(
            'Fallback check - Has internet: $hasInternet, Is offline: $isOffline');
      });
    }
  }

  Future<void> _handleConnectivityChange(
      List<ConnectivityResult> results) async {
    if (!mounted) return;

    bool hasConnection = results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);

    bool hasInternet = hasConnection ? await _checkActualInternet() : false;

    if (mounted && isOffline != !hasInternet) {
      setState(() {
        isOffline = !hasInternet;
// removed debug statement
// removed debug statement
// removed debug statement
// removed debug statement
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
// removed debug statement
      return const LoginPage();
    }

    final List<Widget> pages = [
      const FocusFlowHome(),
      CalendarTaskPage(userId: user.uid),
      ChatPage(userId: user.uid),
      const FriendsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: true,
        child: Stack(
          children: [
            pages[_selectedIndex],
            if (isOffline)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 80, color: Colors.red),
                      const SizedBox(height: 10),
                      const Text(
                        "No Internet Connection",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Some features may be unavailable.",
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _updateConnectivityStatus,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today), label: 'Tasks'),
            BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friends'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.white70,
          backgroundColor: Colors.black.withOpacity(0.9),
          type: BottomNavigationBarType.fixed,
          elevation: 10,
          showUnselectedLabels: true,
          selectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
