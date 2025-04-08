import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focus/widgets/challenges_tab.dart';
import 'package:focus/widgets/friends_tab.dart';

class FriendsPage extends StatefulWidget {
  final int initialTabIndex; // Added to control initial tab

  const FriendsPage({super.key, this.initialTabIndex = 0});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex
          .clamp(0, 1), // Use initialTabIndex, clamped to valid range
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends & Challenges'),
          backgroundColor: Theme.of(context).primaryColor,
          bottom: const TabBar(
            tabs: [
              Tab(
                text: 'Friends',
              ),
              Tab(text: 'Challenges'),
            ],
            indicatorColor: Colors.white,
          ),
        ),
        body: const TabBarView(
          children: [
            FriendsTab(),
            ChallengesTab(),
          ],
        ),
      ),
    );
  }
}
