import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // For CupertinoActivityIndicator
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focus/pages/challenge_submissions_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:focus/services/friend_service.dart';
import 'package:focus/services/challenge_service.dart';
import 'package:focus/services/challenge_collage_service.dart';
import 'package:focus/widgets/challenge_dialog.dart'; // Import the reusable dialog
import 'package:lottie/lottie.dart'; // Import Lottie package
import 'package:intl/intl.dart'; // For date formatting

class ChallengesTab extends StatefulWidget {
  const ChallengesTab({super.key});

  @override
  State<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<ChallengesTab>
    with SingleTickerProviderStateMixin {
  final ChallengeService _challengeService = ChallengeService();
  final FriendService _friendService = FriendService();
  final ChallengeCollageService _collageService = ChallengeCollageService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false; // Track upload state
  late AnimationController _animationController; // For fade animation
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: const BoxDecoration(color: Colors.black),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(constraints.maxWidth * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: () {
                    try {
                      showCreateChallengeDialog(
                        context,
                        friendService: _friendService,
                        challengeService: _challengeService,
                      );
                    } catch (e, stackTrace) {
// removed debug statement
// removed debug statement
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to open dialog: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize:
                        Size(double.infinity, constraints.maxHeight * 0.08),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag, size: 18),
                      SizedBox(width: constraints.maxWidth * 0.02),
                      const Text(
                        'Create New Challenge',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: constraints.maxHeight * 0.02),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _challengeService
                      .getPendingVerifications(_currentUser!.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.blueAccent));
                    }
                    final pendingVerifications = snapshot.data ?? [];
                    if (pendingVerifications.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return GestureDetector(
                      onTap: () =>
                          _showPendingVerificationsDialog(pendingVerifications),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange[100]?.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
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
                            Text(
                              'Pending Verifications (${pendingVerifications.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.black87),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: constraints.maxHeight * 0.02),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _challengeService.getChallenges(_currentUser!.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.blueAccent));
                    }
                    final challenges = snapshot.data ?? [];
                    if (challenges.isEmpty) {
                      return Center(
                        child: Text(
                          'No challenges yet',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: constraints.maxWidth * 0.04,
                          ),
                        ),
                      );
                    }

                    // Split into active and inactive challenges
                    final activeChallenges = challenges
                        .where(
                            (c) => ['pending', 'active'].contains(c['status']))
                        .toList();
                    final inactiveChallenges = challenges
                        .where((c) =>
                            ['completed', 'exited'].contains(c['status']))
                        .toList();

                    // Sort active challenges based on priority
                    activeChallenges.sort((a, b) {
                      final isSenderA = a['senderId'] == _currentUser!.uid;
                      final isSenderB = b['senderId'] == _currentUser!.uid;
                      final statusA = a['status'] as String;
                      final statusB = b['status'] as String;
                      final myProgressA = isSenderA
                          ? a['senderProgress'] as int? ?? 0
                          : a['receiverProgress'] as int? ?? 0;
                      final myProgressB = isSenderB
                          ? b['senderProgress'] as int? ?? 0
                          : b['receiverProgress'] as int? ?? 0;

                      // 1. Awaiting your acceptance (pending, not sender) - highest priority
                      if (statusA == 'pending' && !isSenderA) return -1;
                      if (statusB == 'pending' && !isSenderB) return 1;

                      // 2. Active challenges with no progress
                      if (statusA == 'active' && myProgressA == 0) {
                        if (statusB == 'active' && myProgressB == 0) return 0;
                        return -1;
                      }
                      if (statusB == 'active' && myProgressB == 0) return 1;

                      // 3. Other active challenges
                      if (statusA == 'active') {
                        if (statusB == 'active') return 0;
                        return -1;
                      }
                      if (statusB == 'active') return 1;

                      // 4. Awaiting opponent's acceptance (pending, sender) - lowest priority
                      if (statusA == 'pending' && isSenderA) return 1;
                      if (statusB == 'pending' && isSenderB) return -1;

                      return 0; // Fallback
                    });

                    // Sort inactive challenges (unchanged)
                    final isSender = (Map<String, dynamic> c) =>
                        c['senderId'] == _currentUser!.uid;
                    inactiveChallenges.sort((a, b) {
                      final aProgress = isSender(a)
                          ? a['senderProgress'] as int
                          : a['receiverProgress'] as int;
                      final bProgress = isSender(b)
                          ? b['senderProgress'] as int
                          : b['receiverProgress'] as int;
                      final aDuration = a['durationDays'] as int;
                      final bDuration = b['durationDays'] as int;
                      final aNeedsSubmission = aProgress < aDuration;
                      final bNeedsSubmission = bProgress < bDuration;
                      return aNeedsSubmission == bNeedsSubmission
                          ? 0
                          : (aNeedsSubmission ? -1 : 1);
                    });

                    return Column(
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: activeChallenges.length,
                          itemBuilder: (context, index) => _buildChallengeCard(
                              activeChallenges[index], constraints,
                              isActive: true),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: inactiveChallenges.length,
                          itemBuilder: (context, index) => _buildChallengeCard(
                              inactiveChallenges[index], constraints,
                              isActive: false),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChallengeCard(
      Map<String, dynamic> challenge, BoxConstraints constraints,
      {required bool isActive}) {
    final challengeId = challenge['id'] as String? ?? '';
    final isSender = challenge['senderId'] == _currentUser!.uid;
    final opponentId = isSender
        ? challenge['receiverId'] as String? ?? ''
        : challenge['senderId'] as String? ?? '';
    final myProgress = isSender
        ? challenge['senderProgress'] as int? ?? 0
        : challenge['receiverProgress'] as int? ?? 0;
    final opponentProgress = isSender
        ? challenge['receiverProgress'] as int? ?? 0
        : challenge['senderProgress'] as int? ?? 0;
    final durationDays = challenge['durationDays'] as int? ?? 1;
    final endDateString = challenge['endDate'] as String?;
    final endDate = endDateString != null
        ? DateTime.tryParse(endDateString) ?? DateTime.now()
        : DateTime.now();
    final formattedEndDate =
        DateFormat('d MMMM yyyy').format(endDate); // e.g., 20 April 2025
    final isCompleted = DateTime.now().isAfter(endDate);
    final exitedBy = challenge['exitedBy'] as String?;

    if (isCompleted &&
        challenge['status'] != 'completed' &&
        challenge['status'] != 'exited') {
      _completeChallenge(challengeId);
    }

    final status = challenge['status'] as String? ?? 'pending';
    final title = challenge['title'] as String? ??
        challenge['description'] as String? ??
        'No Title';
    final capitalizedTitle = title.isNotEmpty
        ? title[0].toUpperCase() + title.substring(1)
        : 'No Title';
    final winner = challenge['winner'] as String?;

    Widget card = Container(
      padding: EdgeInsets.all(constraints.maxWidth * 0.03),
      margin: EdgeInsets.symmetric(vertical: constraints.maxHeight * 0.01),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.38),
            blurRadius: 16,
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
              Expanded(
                child: Text(
                  capitalizedTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: constraints.maxWidth * 0.04,
                    color: Colors.white,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (status == 'active')
                    TextButton(
                      onPressed: () => _showQuitConfirmationDialog(challengeId),
                      child: const Text(
                        'Quit',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  if (status == 'completed' || status == 'exited')
                    TextButton(
                      onPressed: () => _collageService.shareChallengeCollage(
                        context,
                        challengeId,
                        _currentUser!.uid,
                        opponentId,
                        exitedBy: exitedBy,
                      ),
                      child: const Text(
                        'Share',
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: constraints.maxHeight * 0.01),
          FutureBuilder<String?>(
            future: _friendService.getUsername(opponentId),
            builder: (context, opponentNameSnapshot) {
              return Text(
                'Versus: ${opponentNameSnapshot.data ?? 'Loading...'}',
                style: TextStyle(
                  fontSize: constraints.maxWidth * 0.03,
                  color: Colors.grey[400],
                ),
              );
            },
          ),
          Text(
            'Ends on: $formattedEndDate',
            style: TextStyle(
              fontSize: constraints.maxWidth * 0.03,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: constraints.maxHeight * 0.02),
          if (status == 'pending' && isSender)
            Text(
              'Awaiting Opponent’s Epic Move! ⚔️',
              style: TextStyle(
                fontSize: constraints.maxWidth * 0.03,
                color: Colors.blueAccent,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            Text(
              'Your Progress: $myProgress/$durationDays',
              style: TextStyle(
                fontSize: constraints.maxWidth * 0.03,
                color: Colors.white,
              ),
            ),
            LinearProgressIndicator(
              value: myProgress / durationDays,
              backgroundColor: Colors.grey[800],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              borderRadius: BorderRadius.circular(10),
            ),
            SizedBox(height: constraints.maxHeight * 0.01),
            FutureBuilder<String?>(
              future: _friendService.getUsername(opponentId),
              builder: (context, opponentNameSnapshot) {
                return Text(
                  '${opponentNameSnapshot.data ?? 'Opponent'}’s Progress: $opponentProgress/$durationDays',
                  style: TextStyle(
                    fontSize: constraints.maxWidth * 0.03,
                    color: Colors.white,
                  ),
                );
              },
            ),
            LinearProgressIndicator(
              value: opponentProgress / durationDays,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              borderRadius: BorderRadius.circular(10),
            ),
          ],
          SizedBox(height: constraints.maxHeight * 0.02),
          if (status == 'active')
            FutureBuilder<bool>(
              future: _challengeService.canSubmitPhoto(
                  _currentUser!.uid, challengeId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.blueAccent));
                }
                final canSubmit = snapshot.data ?? false;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: canSubmit && !_isUploading
                          ? () => _submitPhoto(challengeId)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canSubmit && !_isUploading
                            ? Colors.blueAccent
                            : Colors.grey[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Submit Photo'),
                    ),
                    TextButton(
                      onPressed: () =>
                          _showSubmissions(challengeId, opponentId),
                      child: const Text(
                        'View Submissions',
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                  ],
                );
              },
            ),
          if (status == 'pending' && !isSender)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => _acceptChallenge(challengeId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
                TextButton(
                  onPressed: () => _declineChallenge(challengeId),
                  child: const Text(
                    'Decline',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          if (status == 'exited' || status == 'completed') ...[
            SizedBox(height: constraints.maxHeight * 0.01),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: status == 'exited' && exitedBy == _currentUser!.uid
                    ? Colors.red
                    : status == 'exited' && exitedBy != _currentUser!.uid
                        ? Colors.green
                        : winner == 'tie'
                            ? Colors.grey[700]
                            : winner == _currentUser!.uid
                                ? Colors.green
                                : Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status == 'exited'
                    ? (exitedBy == _currentUser!.uid
                        ? 'You exited this challenge'
                        : 'Opponent quit - You won!')
                    : winner == 'tie'
                        ? 'Tie! Both finished with $myProgress vs $opponentProgress'
                        : 'Winner: ${winner == _currentUser!.uid ? 'You' : 'Opponent'} ($myProgress vs $opponentProgress)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: constraints.maxWidth * 0.03,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );

    return isActive
        ? card
        : GestureDetector(
            onTap: () => _showRemoveChallengeDialog(challengeId),
            child: card,
          );
  }

  void _showQuitConfirmationDialog(String challengeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Quit Challenge?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'If you quit, you will lose the challenge with your friend. Are you sure?',
          style: TextStyle(color: Colors.grey[400]),
        ),
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
              await _exitChallenge(challengeId);
              Navigator.pop(context);
            },
            child: const Text('Quit / Lose'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRemoveChallengeDialog(String challengeId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Remove Challenge?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Do you want to delete this challenge from your list? This action cannot be undone.',
          style: TextStyle(color: Colors.grey[400]),
        ),
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
              await _removeChallenge(challengeId);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPhoto(String challengeId) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(
                  radius: 15, color: Colors.blueAccent),
              const SizedBox(height: 10),
              Text(
                'Uploading image...',
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );

      try {
        setState(() {
          _isUploading = true;
        });
        await _challengeService.submitPhoto(
            _currentUser!.uid, challengeId, photo);
// removed debug statement
        Navigator.pop(context);
        await _showUploadCompletedPopup();
      } catch (e) {
        Navigator.pop(context);
// removed debug statement
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit photo: $e')));
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
      setState(() {});
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No photo selected')));
    }
  }

  Future<void> _showUploadCompletedPopup() async {
    _animationController.reset();
    _animationController.forward();

    await showDialog(
      context: context,
      builder: (context) => FadeTransition(
        opacity: _fadeAnimation,
        child: AlertDialog(
          backgroundColor: Colors.grey[900],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/tick_animation.json',
                height: 100,
                width: 100,
                fit: BoxFit.contain,
                repeat: false,
              ),
              const SizedBox(height: 10),
              const Text(
                'Upload completed!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptChallenge(String challengeId) async {
    try {
      await _challengeService.acceptChallenge(challengeId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Challenge accepted!')));
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept challenge: $e')));
    }
  }

  Future<void> _declineChallenge(String challengeId) async {
    try {
      await _challengeService.declineChallenge(challengeId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Challenge declined')));
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline challenge: $e')));
    }
  }

  Future<void> _exitChallenge(String challengeId) async {
    try {
      await _challengeService.exitChallenge(challengeId, _currentUser!.uid);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Challenge exited')));
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to exit challenge: $e')));
    }
  }

  Future<void> _completeChallenge(String challengeId) async {
    try {
      await _challengeService.completeChallenge(challengeId);
// removed debug statement
      setState(() {});
    } catch (e) {
// removed debug statement
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete challenge: $e')));
    }
  }

  Future<void> _removeChallenge(String challengeId) async {
    try {
      await _challengeService.removeChallenge(challengeId);
// removed debug statement
      setState(() {});
    } catch (e) {
// removed debug statement
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove challenge: $e')));
    }
  }

  void _showSubmissions(String challengeId, String opponentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeSubmissionsPage(
            challengeId: challengeId, opponentId: opponentId),
      ),
    );
  }

  void _showPendingVerificationsDialog(
      List<Map<String, dynamic>> pendingVerifications) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Pending Verifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _challengeService
                      .getPendingVerifications(_currentUser!.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.blueAccent));
                    }
                    final pendingVerifications = snapshot.data ?? [];
                    if (pendingVerifications.isEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.pop(context);
                      });
                      return Center(
                        child: Text(
                          'No pending verifications',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: pendingVerifications.length,
                      itemBuilder: (context, index) {
                        final verification = pendingVerifications[index];
                        final challengeId =
                            verification['challengeId'] as String? ?? '';
                        final submissionId =
                            verification['submissionId'] as String? ?? '';
                        final photoUrl =
                            verification['photoUrl'] as String? ?? '';
                        final senderName =
                            verification['senderName'] as String? ?? 'Unknown';
                        final challengeTitle =
                            verification['challengeTitle'] as String? ??
                                'No Title';

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.3)),
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
                              Text(
                                'Challenge: $challengeTitle',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'From: $senderName',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              const SizedBox(height: 8),
                              Image.network(
                                photoUrl,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.error, color: Colors.red),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check,
                                        color: Colors.green),
                                    onPressed: () async {
                                      await _challengeService.verifyPhoto(
                                          challengeId, submissionId, true);
                                      setState(() {});
                                      this.setState(() {});
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    onPressed: () async {
                                      await _challengeService.verifyPhoto(
                                          challengeId, submissionId, false);
                                      setState(() {});
                                      this.setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
