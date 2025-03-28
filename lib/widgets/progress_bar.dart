import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class XPBar extends StatefulWidget {
  final String userId;

  const XPBar({Key? key, required this.userId}) : super(key: key);

  @override
  _XPBarState createState() => _XPBarState();
}

class _XPBarState extends State<XPBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xpAnimation;
  double _previousXP = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _xpAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _calculateMaxXP(int level) => 100 + (level - 1) * 50;

  void _updateAnimation(double newXP) {
    _xpAnimation = Tween<double>(begin: _previousXP, end: newXP).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.reset();
    _controller.forward();
    _previousXP = newXP;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 20,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildXPBar(context, 1, 0, 100);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final int level = data['level'] ?? 1;
        final double xp = (data['xp'] ?? 0).toDouble();
        final double maxXP = _calculateMaxXP(level);

        if (xp != _previousXP) {
          _updateAnimation(xp);
        }

        return _buildXPBar(context, level, xp, maxXP);
      },
    );
  }

  Widget _buildXPBar(BuildContext context, int level, double xp, double maxXP) {
    final screenWidth = MediaQuery.of(context).size.width;
    final safeMaxXP = maxXP > 0 ? maxXP : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  "Level $level",
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  "- Focus Master",
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
            AnimatedBuilder(
              animation: _xpAnimation,
              builder: (context, child) {
                return Text(
                  "${_xpAnimation.value.toInt()}/$safeMaxXP XP",
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.grey[400],
                  ),
                );
              },
            ),
          ],
        ),
        SizedBox(height: screenWidth * 0.02),
        AnimatedBuilder(
          animation: _xpAnimation,
          builder: (context, child) {
            final progress = (_xpAnimation.value / safeMaxXP).clamp(0.0, 1.0);
            return SizedBox(
              height: screenWidth * 0.015,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          },
        ),
      ],
    );
  }
}
