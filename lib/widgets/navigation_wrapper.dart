import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focus/pages/home_screen.dart';
import 'package:focus/pages/calendar_task_page.dart';
import 'package:focus/pages/chat_page.dart';
import 'package:focus/pages/friends_page.dart';
import 'package:focus/pages/setting_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  _NavigationWrapperState createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
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

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
      onError: (e) {
        _startFallbackTimer();
      },
    );
  }

  void _startFallbackTimer() {
    if (_fallbackTimer == null || !_fallbackTimer!.isActive) {
      _fallbackTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted) _fallbackConnectivityCheck();
      });
    }
  }

  Future<void> _updateConnectivityStatus() async {
    final results = await Connectivity().checkConnectivity();
    await _handleConnectivityChange(results);
  }

  Future<bool> _checkActualInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fallbackConnectivityCheck() async {
    bool hasInternet = await _checkActualInternet();
    if (mounted && isOffline != !hasInternet) {
      setState(() => isOffline = !hasInternet);
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
      setState(() => isOffline = !hasInternet);
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
    if (user == null)
      return const SizedBox(); // Shouldn't happen, handled by authWrapper

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
                          color: Colors.white,
                        ),
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
