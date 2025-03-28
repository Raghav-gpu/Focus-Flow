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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildXPBar(context, 1, 0, 100); // Default: Level 1, 0 XP
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final int level = data['level'] ?? 1;
        final double xp = (data['xp'] ?? 0).toDouble();
        final double maxXP = _calculateMaxXP(level);

        // Update animation only if XP changes
        if (xp != _previousXP) {
          _updateAnimation(xp);
        }

        return _buildXPBar(context, level, xp, maxXP);
      },
    );
  }

  Widget _buildXPBar(BuildContext context, int level, double xp, double maxXP) {
    // Ensure maxXP is never 0 to avoid division by zero
    final double safeMaxXP = maxXP > 0 ? maxXP : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _xpAnimation,
          builder: (context, child) {
            // Calculate progress safely, clamping between 0 and 1
            final double progress =
                (_xpAnimation.value / safeMaxXP).clamp(0.0, 1.0);
            final double barWidth = progress * 300;

            return Stack(
              children: [
                Container(
                  width: 300,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  width:
                      barWidth.isFinite ? barWidth : 0, // Fallback to 0 if NaN
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A00F4), Color(0xFFA100F2)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: progress > 0.9
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6A00F4).withOpacity(0.8),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A00F4),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6A00F4).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  "Level $level",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _xpAnimation,
                builder: (context, child) {
                  return Text(
                    "${_xpAnimation.value.toStringAsFixed(0)} / $safeMaxXP XP",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
