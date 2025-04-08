import 'package:flutter/material.dart';
import 'package:focus/services/challenge_service.dart';
import 'package:focus/services/friend_service.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ChallengeCollageService {
  final ChallengeService _challengeService = ChallengeService();
  final FriendService _friendService = FriendService();
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> shareChallengeCollage(
    BuildContext context,
    String challengeId,
    String currentUserId,
    String opponentId, {
    String? exitedBy,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch verified submissions
      final verifiedSubmissions =
          await _challengeService.getVerifiedSubmissions(challengeId).first;

      if (verifiedSubmissions.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No submissions to share')),
        );
        return;
      }

      // Get challenge details
      final challengeDoc = await _challengeService
          .getChallenges(currentUserId)
          .first
          .then((challenges) =>
              challenges.firstWhere((c) => c['id'] == challengeId));
      final challengeTitle =
          challengeDoc['description'] as String? ?? 'Challenge';
      final status = challengeDoc['status'] as String? ?? 'completed';

      // Separate user and opponent submissions
      final userSubmissions = verifiedSubmissions
          .where((submission) => submission['userId'] == currentUserId)
          .toList();
      final opponentSubmissions = verifiedSubmissions
          .where((submission) => submission['userId'] == opponentId)
          .toList();

      // Get usernames
      final userName =
          await _friendService.getUsername(currentUserId) ?? 'User';
      final opponentName =
          await _friendService.getUsername(opponentId) ?? 'Opponent';

      // Determine winner
      final userCount = userSubmissions.length;
      final opponentCount = opponentSubmissions.length;
      String? winnerName;
      bool isTie = userCount == opponentCount;

      if (status == 'exited' && exitedBy != null) {
        winnerName = exitedBy == currentUserId ? opponentName : userName;
        isTie = false;
      } else {
        winnerName = isTie
            ? null
            : (userCount > opponentCount ? userName : opponentName);
      }

      // Build the collage widget with adaptive sizing
      final screenSize = MediaQuery.of(context).size;
      final collageWidth = screenSize.width * 0.9; // 90% of screen width
      final collageHeight = screenSize.height * 0.8; // 80% of screen height

      final collage = Screenshot(
        controller: _screenshotController,
        child: Container(
          width: collageWidth,
          height: collageHeight,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(collageWidth * 0.04), // 4% of width
          child: Column(
            children: [
              // Header
              Text(
                'Challenge Progress',
                style: TextStyle(
                  fontSize: collageWidth * 0.06, // 6% of width
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: collageHeight * 0.01), // 1% of height
              Text(
                '"$challengeTitle"',
                style: TextStyle(
                  fontSize: collageWidth * 0.045, // 4.5% of width
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: collageHeight * 0.02), // 2% of height

              // User Section
              Text(
                "$userName's Submissions ($userCount)",
                style: TextStyle(
                  fontSize: collageWidth * 0.04, // 4% of width
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: collageHeight * 0.01),
              Expanded(
                child: _buildAdaptiveGrid(userSubmissions),
              ),
              SizedBox(height: collageHeight * 0.02),

              // Winner Section
              Container(
                padding: EdgeInsets.all(collageWidth * 0.03), // 3% of width
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isTie ? Colors.blue : Colors.yellow,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // Prevent overflow
                  children: [
                    if (!isTie) ...[
                      Icon(Icons.star,
                          color: Colors.yellow,
                          size: collageWidth * 0.06), // 6% of width
                      SizedBox(width: collageWidth * 0.02),
                    ],
                    Flexible(
                      child: Text(
                        isTie ? "It's a Tie!" : "Winner: $winnerName!",
                        style: TextStyle(
                          fontSize: collageWidth * 0.05, // 5% of width
                          fontWeight: FontWeight.bold,
                          color: isTie ? Colors.blue : Colors.yellow,
                        ),
                        overflow: TextOverflow.ellipsis, // Handle long names
                      ),
                    ),
                    if (!isTie) ...[
                      SizedBox(width: collageWidth * 0.02),
                      Icon(Icons.star,
                          color: Colors.yellow, size: collageWidth * 0.06),
                    ],
                  ],
                ),
              ),
              SizedBox(height: collageHeight * 0.02),

              // Opponent Section
              Text(
                "$opponentName's Submissions ($opponentCount)",
                style: TextStyle(
                  fontSize: collageWidth * 0.04,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: collageHeight * 0.01),
              Expanded(
                child: _buildAdaptiveGrid(opponentSubmissions),
              ),
              SizedBox(height: collageHeight * 0.02),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icon.png',
                    height: collageWidth * 0.06,
                    width: collageWidth * 0.06,
                  ),
                  SizedBox(width: collageWidth * 0.02),
                  Text(
                    'Shared via Focus Flow',
                    style: TextStyle(
                      fontSize: collageWidth * 0.035, // 3.5% of width
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      // Close loading dialog after collage is built
      Navigator.pop(context);

      // Show preview dialog with adaptive sizing
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenSize.width * 0.9,
                maxHeight: screenSize.height * 0.8,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: collage,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () async {
                Navigator.pop(context);
                await _shareCollage(context, challengeTitle);
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing collage: ${e.toString()}')),
      );
    }
  }

  Widget _buildAdaptiveGrid(List<Map<String, dynamic>> submissions) {
    if (submissions.isEmpty) {
      return Center(
        child: Text(
          'No submissions yet',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxColumns = 4;
        final crossAxisCount =
            submissions.length < maxColumns ? submissions.length : maxColumns;
        final rowCount = (submissions.length / crossAxisCount).ceil();
        final cellSize = constraints.maxHeight / rowCount;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            mainAxisExtent: cellSize,
          ),
          itemCount: submissions.length,
          itemBuilder: (context, index) => _buildGridItem(submissions[index]),
        );
      },
    );
  }

  Widget _buildGridItem(Map<String, dynamic> submission) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Image.network(
          submission['photoUrl'] as String? ?? '',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.error, color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareCollage(
      BuildContext context, String challengeTitle) async {
    try {
      // Capture the collage
      final imageBytes = await _screenshotController.capture();
      if (imageBytes == null) {
        throw Exception('Failed to capture collage');
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/challenge_collage_$challengeTitle.png';
      final file = await File(filePath).writeAsBytes(imageBytes);

      // Share with full native share sheet
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Check out our challenge progress for "$challengeTitle" on Focus Flow!',
        subject: 'Challenge Collage',
      );

      // Clean up (optional, since temp files are cleared by OS eventually)
      // await file.delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: ${e.toString()}')),
      );
    }
  }
}
