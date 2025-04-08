import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focus/services/challenge_service.dart';
import 'package:focus/services/friend_service.dart';
import 'package:focus/services/streak_service.dart'; // Import StreakService
import 'package:focus/widgets/challenge_dialog.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final FriendService _friendService = FriendService();
  final ChallengeService _challengeService = ChallengeService();
  final StreakService _streakService = StreakService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _addFriendController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(constraints.maxWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _addFriendController,
                decoration: InputDecoration(
                  labelText: 'Enter username to add friend',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendFriendRequest,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: TextStyle(fontSize: constraints.maxWidth * 0.04),
              ),
              SizedBox(height: constraints.maxHeight * 0.02),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _friendService.getFriendRequests(_currentUser!.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final requests = snapshot.data ?? [];
                  if (requests.isEmpty) {
                    return const SizedBox.shrink(); // Hide section entirely
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Friend Requests',
                        style: TextStyle(
                          fontSize: constraints.maxWidth * 0.045,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildFriendRequests(context, constraints),
                    ],
                  );
                },
              ),
              SizedBox(height: constraints.maxHeight * 0.02),
              Text(
                'My Friends',
                style: TextStyle(
                  fontSize: constraints.maxWidth * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildFriendsList(context, constraints),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFriendRequests(
      BuildContext context, BoxConstraints constraints) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _friendService.getFriendRequests(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(constraints.maxWidth * 0.02),
            child: Text(
              'No friend requests',
              style: TextStyle(
                color: Colors.grey,
                fontSize: constraints.maxWidth * 0.035,
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true, // Allow it to take only the space it needs
          physics:
              const NeverScrollableScrollPhysics(), // Disable inner scrolling
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final senderId = request['senderId'] as String;

            return FutureBuilder<Map<String, dynamic>?>(
              future: _friendService.getUserDetails(senderId),
              builder: (context, userSnapshot) {
                final userDetails = userSnapshot.data ??
                    {'username': 'Unknown', 'profilePictureUrl': null};
                final username = userDetails['username'] as String;
                final pfpUrl = userDetails['profilePictureUrl'] as String?;

                return Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(
                      vertical: constraints.maxHeight * 0.01),
                  child: Padding(
                    padding: EdgeInsets.all(constraints.maxWidth * 0.02),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: constraints.maxWidth * 0.05,
                          backgroundImage:
                              pfpUrl != null ? NetworkImage(pfpUrl) : null,
                          child: pfpUrl == null
                              ? Text(
                                  username[0].toUpperCase(),
                                  style: TextStyle(
                                      fontSize: constraints.maxWidth * 0.04),
                                )
                              : null,
                        ),
                        SizedBox(width: constraints.maxWidth * 0.02),
                        Expanded(
                          child: Text(
                            username,
                            style: TextStyle(
                                fontSize: constraints.maxWidth * 0.04),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check,
                                  color: Colors.green,
                                  size: constraints.maxWidth * 0.06),
                              onPressed: () => _acceptFriendRequest(senderId),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: Colors.red,
                                  size: constraints.maxWidth * 0.06),
                              onPressed: () => _rejectFriendRequest(senderId),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsList(BuildContext context, BoxConstraints constraints) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _friendService.getFriends(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final friends = snapshot.data ?? [];
        if (friends.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(constraints.maxWidth * 0.02),
            child: Text(
              'No friends yet',
              style: TextStyle(
                color: Colors.grey,
                fontSize: constraints.maxWidth * 0.035,
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true, // Allow it to take only the space it needs
          physics:
              const NeverScrollableScrollPhysics(), // Disable inner scrolling
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            final friendId = friend['friendId'] as String;

            return FutureBuilder<Map<String, dynamic>?>(
              future: _friendService.getUserDetails(friendId),
              builder: (context, userSnapshot) {
                final userDetails = userSnapshot.data ??
                    {'username': 'Unknown', 'profilePictureUrl': null};
                final username = userDetails['username'] as String;
                final pfpUrl = userDetails['profilePictureUrl'] as String?;

                return GestureDetector(
                  onTap: () => _showUnfriendDialog(friendId, username),
                  child: Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(
                        vertical: constraints.maxHeight * 0.01),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(constraints.maxWidth * 0.02),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: constraints.maxWidth * 0.05,
                                    backgroundImage: pfpUrl != null
                                        ? NetworkImage(pfpUrl)
                                        : null,
                                    child: pfpUrl == null
                                        ? Text(
                                            username[0].toUpperCase(),
                                            style: TextStyle(
                                                fontSize: constraints.maxWidth *
                                                    0.04),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: constraints.maxWidth * 0.025,
                                      height: constraints.maxWidth * 0.025,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.fromBorderSide(
                                            BorderSide(
                                                color: Colors.white, width: 2)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: constraints.maxWidth * 0.02),
                              Expanded(
                                child: Text(
                                  username,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: constraints.maxWidth * 0.04,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => showCreateChallengeDialog(
                                  context,
                                  preSelectedFriendId: friendId,
                                  preSelectedFriendUsername: username,
                                  friendService: _friendService,
                                  challengeService: _challengeService,
                                ),
                                child: Text(
                                  'Challenge',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: constraints.maxWidth * 0.035,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              vertical: constraints.maxHeight * 0.015),
                          decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: FutureBuilder<int>(
                            future: _streakService.calculateStreak(friendId),
                            builder: (context, streakSnapshot) {
                              final streak = streakSnapshot.data ?? 0;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: Colors.amber,
                                    size: constraints.maxWidth * 0.05,
                                  ),
                                  SizedBox(width: constraints.maxWidth * 0.01),
                                  Text(
                                    '$streak day streak',
                                    style: TextStyle(
                                      fontSize: constraints.maxWidth * 0.035,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _sendFriendRequest() async {
    final username = _addFriendController.text.trim();
    if (username.isEmpty) return;

    try {
      await _friendService.sendFriendRequest(_currentUser!.uid, username);
      _addFriendController.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Friend request sent!')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
    }
  }

  Future<void> _acceptFriendRequest(String senderId) async {
    try {
      await _friendService.acceptFriendRequest(_currentUser!.uid, senderId);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept request: $e')));
    }
  }

  Future<void> _rejectFriendRequest(String senderId) async {
    try {
      await _friendService.rejectFriendRequest(_currentUser!.uid, senderId);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request rejected')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject request: $e')));
    }
  }

  void _showUnfriendDialog(String friendId, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend'),
        content: Text('Are you sure you want to unfriend $username?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('friends')
                    .doc(friendId)
                    .delete();
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(friendId)
                    .collection('friends')
                    .doc(_currentUser!.uid)
                    .delete();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend removed')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to unfriend: $e')));
              }
            },
            child: const Text('Unfriend'),
          ),
        ],
      ),
    );
  }
}
