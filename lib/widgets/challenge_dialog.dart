import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focus/services/challenge_service.dart';
import 'package:focus/services/friend_service.dart';

void showCreateChallengeDialog(
  BuildContext context, {
  String? preSelectedFriendId,
  String? preSelectedFriendUsername,
  required FriendService friendService,
  required ChallengeService challengeService,
}) {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController totalDaysController =
      TextEditingController(text: '30');
  String? selectedFriendId = preSelectedFriendId;

  void showInviteFriendsSheet(void Function(void Function()) setDialogState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900], // Dark background like homepage
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          children: [
            Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
              child: Column(
                children: [
                  Text(
                    'Invite Friend',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // White text like homepage
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Text(
                    'Select one friend to challenge',
                    style: TextStyle(
                      color: Colors.grey[400], // Subtle grey like homepage
                      fontSize: MediaQuery.of(context).size.width * 0.035,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: friendService.getFriends(currentUser!.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                      color: Colors.blueAccent, // Blue accent
                    ));
                  }
                  final friends = snapshot.data ?? [];
                  if (friends.isEmpty) {
                    return Center(
                      child: Text(
                        'No friends to invite',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final friendId = friend['friendId'] as String? ?? '';

                      return FutureBuilder<String?>(
                        future: friendService.getUsername(friendId),
                        builder: (context, usernameSnapshot) {
                          final username = usernameSnapshot.data ?? friendId;
                          final isSelected = selectedFriendId == friendId;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.withOpacity(0.2),
                              child: Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              username,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.blueAccent)
                                : null,
                            onTap: () {
                              setSheetState(() {
                                setDialogState(() {
                                  selectedFriendId = friendId;
                                });
                              });
                              Navigator.pop(context);
                            },
                            tileColor: isSelected
                                ? Colors.blueAccent.withOpacity(0.1)
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
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: Colors.grey[900], // Dark background like homepage
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        contentPadding: EdgeInsets.zero, // Remove default padding
        title: Text(
          preSelectedFriendUsername != null
              ? 'Challenge $preSelectedFriendUsername'
              : 'New Challenge',
          style: const TextStyle(
            color: Colors.white, // White title like homepage
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0), // Custom padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preSelectedFriendUsername != null
                        ? 'Define your challenge for $preSelectedFriendUsername.'
                        : 'Define your challenge and invite one friend.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400], // Subtle grey like homepage
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Challenge Title',
                      hintText: '30-Day Focus Challenge',
                      labelStyle: const TextStyle(color: Colors.blueAccent),
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.blue.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'Complete at least 2 hours of focused work every day',
                      labelStyle: const TextStyle(color: Colors.blueAccent),
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.blue.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: totalDaysController,
                    decoration: InputDecoration(
                      labelText: 'Number of Days',
                      labelStyle: const TextStyle(color: Colors.blueAccent),
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.blue.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  if (preSelectedFriendUsername == null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Invite Friend:',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                            width: MediaQuery.of(context).size.width * 0.02),
                        ElevatedButton.icon(
                          onPressed: () =>
                              showInviteFriendsSheet(setDialogState),
                          icon: const Icon(Icons.person_add, size: 16),
                          label: const Text('Select'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(100, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  if (selectedFriendId != null)
                    FutureBuilder<String?>(
                      future: friendService.getUsername(selectedFriendId!),
                      builder: (context, snapshot) {
                        return Text(
                          'Selected: ${snapshot.data ?? selectedFriendId}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blueAccent,
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.blueAccent),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (titleController.text.isNotEmpty &&
                              descriptionController.text.isNotEmpty &&
                              totalDaysController.text.isNotEmpty &&
                              selectedFriendId != null) {
                            try {
                              await challengeService.createChallenge(
                                currentUser!.uid,
                                selectedFriendId!,
                                titleController.text,
                                descriptionController.text,
                                int.parse(totalDaysController.text),
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Challenge sent!')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Failed to send challenge: $e')),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please fill in all fields and select a friend'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Send Challenge'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
