import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focus/services/friend_service.dart';
import 'package:focus/services/challenge_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FriendService _friendService = FriendService();
  final ChallengeService _challengeService = ChallengeService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _addFriendController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<String> selectedFriends = [];

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends & Challenges'),
          backgroundColor: Theme.of(context).primaryColor,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Friends'),
              Tab(text: 'Challenges'),
            ],
            indicatorColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            _buildFriendsTab(),
            _buildChallengesTab(),
          ],
        ),
      ),
    );
  }

  // Friends Tab
  Widget _buildFriendsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
            ),
          ),
          const SizedBox(height: 16),
          const Text('Friend Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildFriendRequests(),
          const SizedBox(height: 16),
          const Text('My Friends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildFriendsList(),
        ],
      ),
    );
  }

  Widget _buildFriendRequests() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _friendService.getFriendRequests(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No friend requests',
                style: TextStyle(color: Colors.grey)),
          );
        }

        return SizedBox(
          height: 120,
          child: ListView.builder(
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
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                pfpUrl != null ? NetworkImage(pfpUrl) : null,
                            child: pfpUrl == null
                                ? Text(username[0].toUpperCase())
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(username)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                onPressed: () => _acceptFriendRequest(senderId),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
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
          ),
        );
      },
    );
  }

  Widget _buildFriendsList() {
    return Expanded(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _friendService.getFriends(_currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final friends = snapshot.data ?? [];
          if (friends.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child:
                  Text('No friends yet', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
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
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: pfpUrl != null
                                      ? NetworkImage(pfpUrl)
                                      : null,
                                  child: pfpUrl == null
                                      ? Text(username[0].toUpperCase())
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.fromBorderSide(BorderSide(
                                          color: Colors.white, width: 2)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(username,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                            TextButton(
                              onPressed: () =>
                                  _showChallengeDialog(friendId, username),
                              child: const Text('Challenge',
                                  style: TextStyle(color: Colors.blue)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Challenges Tab
  Widget _buildChallengesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton(
            onPressed: _showCreateChallengeDialog,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag, size: 18),
                SizedBox(width: 8),
                Text('Create New Challenge'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _challengeService.getChallenges(_currentUser!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final challenges = snapshot.data ?? [];
                if (challenges.isEmpty) {
                  return const Center(
                      child: Text('No challenges yet',
                          style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: challenges.length,
                  itemBuilder: (context, index) {
                    final challenge = challenges[index];
                    final isSender = challenge['senderId'] == _currentUser!.uid;
                    final opponentId = isSender
                        ? challenge['receiverId']
                        : challenge['senderId'];
                    final myProgress = isSender
                        ? challenge['senderProgress']
                        : challenge['receiverProgress'];
                    final opponentProgress = isSender
                        ? challenge['receiverProgress']
                        : challenge['senderProgress'];

                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String?>(
                              future: _friendService.getUsername(opponentId),
                              builder: (context, usernameSnapshot) {
                                return Text(
                                  '${challenge['description']} vs ${usernameSnapshot.data ?? 'Loading...'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text('Status: ${challenge['status']}',
                                style: const TextStyle(fontSize: 12)),
                            Text(
                                'Your Progress: $myProgress/${challenge['durationDays']}',
                                style: const TextStyle(fontSize: 12)),
                            Text(
                                'Opponent Progress: $opponentProgress/${challenge['durationDays']}',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: myProgress / challenge['durationDays'],
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.blue),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (challenge['status'] == 'pending' &&
                                    !isSender)
                                  ElevatedButton(
                                    onPressed: () =>
                                        _acceptChallenge(challenge['id']),
                                    child: const Text('Accept'),
                                  ),
                                if (challenge['status'] == 'active') ...[
                                  ElevatedButton(
                                    onPressed: () =>
                                        _submitPhoto(challenge['id']),
                                    child: const Text('Submit Photo'),
                                  ),
                                  TextButton(
                                    onPressed: () => _showSubmissions(
                                        challenge['id'], opponentId),
                                    child: const Text('View Submissions'),
                                  ),
                                ],
                              ],
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
      ),
    );
  }

  // Helper Methods
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
        title: const Text('Unfriend'),
        content: Text('Are you sure you want to unfriend $username?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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

  void _showChallengeDialog(String friendId, String friendUsername) {
    final TextEditingController descriptionController = TextEditingController();
    int duration = 7;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Challenge $friendUsername'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descriptionController,
              decoration:
                  const InputDecoration(labelText: 'Challenge Description'),
            ),
            DropdownButton<int>(
              value: duration,
              items: [1, 3, 7, 14, 30]
                  .map((days) =>
                      DropdownMenuItem(value: days, child: Text('$days days')))
                  .toList(),
              onChanged: (value) {
                setState(() => duration = value!);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (descriptionController.text.isNotEmpty) {
                try {
                  await _challengeService.createChallenge(
                    _currentUser!.uid,
                    friendId,
                    descriptionController.text,
                    duration,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Challenge sent!')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to send challenge: $e')));
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showCreateChallengeDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController totalDaysController =
        TextEditingController(text: '30');
    final TextEditingController breakDaysController =
        TextEditingController(text: '2');
    bool verifyByLocation = false;
    bool verifyByFriends = true;
    bool verifyByAI = false;
    selectedFriends = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create a New Challenge'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Define your challenge and set verification methods.',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                      labelText: 'Challenge Title',
                      hintText: '30-Day Focus Challenge'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'Complete at least 2 hours of focused work every day'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: totalDaysController,
                        decoration:
                            const InputDecoration(labelText: 'Number of Days'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: breakDaysController,
                        decoration:
                            const InputDecoration(labelText: 'Break Days'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Invite Friends',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _showInviteFriendsSheet(setDialogState),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Select Friends'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40)),
                ),
                if (selectedFriends.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.group,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${selectedFriends.length} invited',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: selectedFriends.map((friendId) {
                            return FutureBuilder<String?>(
                              future: _friendService.getUsername(friendId),
                              builder: (context, snapshot) => Chip(
                                label: Text(snapshot.data ?? friendId),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Verification Methods',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, size: 16),
                        SizedBox(width: 4),
                        Text('Location', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    Switch(
                      value: verifyByLocation,
                      onChanged: (value) =>
                          setDialogState(() => verifyByLocation = value),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_add, size: 16),
                        SizedBox(width: 4),
                        Text('Friends', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    Switch(
                      value: verifyByFriends,
                      onChanged: (value) =>
                          setDialogState(() => verifyByFriends = value),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.smart_toy, size: 16),
                        SizedBox(width: 4),
                        Text('AI', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    Switch(
                      value: verifyByAI,
                      onChanged: (value) =>
                          setDialogState(() => verifyByAI = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty) {
                  try {
                    // For simplicity, assuming one friend for now (your ChallengeService supports one receiver)
                    if (selectedFriends.isNotEmpty) {
                      await _challengeService.createChallenge(
                        _currentUser!.uid,
                        selectedFriends
                            .first, // Modify ChallengeService for multiple friends if needed
                        descriptionController.text,
                        int.parse(totalDaysController.text),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Challenge sent!')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please select at least one friend')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Failed to send challenge: $e')));
                  }
                }
              },
              child: const Text('Create Challenge'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteFriendsSheet(void Function(void Function()) setDialogState) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Invite Friends',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Select friends to invite to your challenge',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _friendService.getFriends(_currentUser!.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final friends = snapshot.data ?? [];
                  if (friends.isEmpty) {
                    return const Center(child: Text('No friends to invite'));
                  }

                  return ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final friendId = friend['friendId'] as String;

                      return FutureBuilder<String?>(
                        future: _friendService.getUsername(friendId),
                        builder: (context, usernameSnapshot) {
                          final username = usernameSnapshot.data ?? friendId;
                          final isSelected = selectedFriends.contains(friendId);

                          return ListTile(
                            leading: CircleAvatar(
                                child: Text(username[0].toUpperCase())),
                            title: Text(username),
                            trailing: isSelected
                                ? const Icon(Icons.check, color: Colors.blue)
                                : null,
                            onTap: () {
                              setSheetState(() {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedFriends.remove(friendId);
                                  } else {
                                    selectedFriends.add(friendId);
                                  }
                                });
                              });
                            },
                            tileColor: isSelected
                                ? Colors.blue.withOpacity(0.1)
                                : null,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        setDialogState(() => selectedFriends.clear()),
                    child: const Text('Clear All'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Done (${selectedFriends.length})'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptChallenge(String challengeId) async {
    try {
      await _challengeService.acceptChallenge(challengeId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Challenge accepted')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept challenge: $e')));
    }
  }

  Future<void> _submitPhoto(String challengeId) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      try {
        await _challengeService.submitPhoto(
            _currentUser!.uid, challengeId, photo);
        await _checkChallengeStatus(challengeId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo submitted for verification')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit photo: $e')));
      }
    }
  }

  void _showSubmissions(String challengeId, String opponentId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: _challengeService.getSubmissions(challengeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final submissions = snapshot.data ?? [];
          if (submissions.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No submissions yet'),
            );
          }

          return ListView.builder(
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final submission = submissions[index];
              final isOpponentSubmission = submission['userId'] == opponentId;
              return ListTile(
                leading: Image.network(submission['photoUrl'],
                    width: 50, height: 50, fit: BoxFit.cover),
                title: Text('Date: ${submission['date']}'),
                subtitle:
                    Text('Verified: ${submission['verified'] ? 'Yes' : 'No'}'),
                trailing: isOpponentSubmission && !submission['verified']
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              await _challengeService.verifyPhoto(
                                  challengeId, submission['id'], true);
                              await _checkChallengeStatus(challengeId);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _challengeService.verifyPhoto(
                                challengeId, submission['id'], false),
                          ),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _checkChallengeStatus(String challengeId) async {
    try {
      await _challengeService.checkChallengeStatus(challengeId);
    } catch (e) {
      debugPrint('Error checking challenge status: $e');
    }
  }
}
