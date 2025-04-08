import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focus/services/challenge_service.dart';
import 'package:focus/services/friend_service.dart';
import 'package:focus/services/challenge_collage_service.dart';

class ChallengeSubmissionsPage extends StatelessWidget {
  final String challengeId;
  final String opponentId;

  const ChallengeSubmissionsPage({
    super.key,
    required this.challengeId,
    required this.opponentId,
  });

  @override
  Widget build(BuildContext context) {
    final ChallengeService _challengeService = ChallengeService();
    final FriendService _friendService = FriendService();
    final ChallengeCollageService _collageService = ChallengeCollageService();
    final User? _currentUser = FirebaseAuth.instance.currentUser;

    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Challenge Progress',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade900, Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _collageService.shareChallengeCollage(
              context,
              challengeId,
              _currentUser.uid,
              opponentId,
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _challengeService.getVerifiedSubmissions(challengeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CupertinoActivityIndicator(
                radius: 20,
                color: Colors.white70,
              ),
            );
          }
          final verifiedSubmissions = snapshot.data ?? [];
          if (verifiedSubmissions.isEmpty) {
            return const Center(
              child: Text(
                'No verified submissions yet',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final userSubmissions = verifiedSubmissions
              .where((submission) => submission['userId'] == _currentUser.uid)
              .toList();
          final opponentSubmissions = verifiedSubmissions
              .where((submission) => submission['userId'] == opponentId)
              .toList();

          return Column(
            children: [
              Expanded(
                child: _buildSection(
                  context: context,
                  friendService: _friendService,
                  userId: _currentUser.uid,
                  submissions: userSubmissions,
                ),
              ),
              const Divider(
                height: 2,
                thickness: 2,
                color: Colors.grey,
              ),
              Expanded(
                child: _buildSection(
                  context: context,
                  friendService: _friendService,
                  userId: opponentId,
                  submissions: opponentSubmissions,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required FriendService friendService,
    required String userId,
    required List<Map<String, dynamic>> submissions,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade800, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: FutureBuilder<String?>(
              future: friendService.getUsername(userId),
              builder: (context, snapshot) {
                final username = snapshot.data ?? 'loading';
                final capitalizedUsername = username.isNotEmpty
                    ? '${username[0].toUpperCase()}${username.substring(1)}'
                    : 'Loading';
                return Text(
                  "$capitalizedUsername's Progress",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: submissions.isEmpty
                ? const Center(
                    child: Text(
                      'No submissions yet',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: submissions.length,
                    itemBuilder: (context, index) {
                      final photoUrl = submissions[index]['photoUrl'] as String;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CupertinoActivityIndicator(
                                  radius: 15,
                                  color: Colors.white70,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.error, color: Colors.red),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
