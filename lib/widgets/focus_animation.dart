import 'package:flutter/material.dart';
import 'dart:math';

class FocusAnimation extends StatefulWidget {
  @override
  _FocusAnimationState createState() => _FocusAnimationState();
}

class _FocusAnimationState extends State<FocusAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _eyeGlowAnim;
  late Animation<double> _mandalaGlowAnim;
  late Animation<double> _mandalaRotateAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat(reverse: true);

    _eyeGlowAnim = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _mandalaGlowAnim = Tween(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _mandalaRotateAnim = Tween(begin: 0.0, end: 0.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _mandalaRotateAnim.value,
                  child: Opacity(
                    opacity: _mandalaGlowAnim.value,
                    child: CustomPaint(
                      painter: MandalaPainter(),
                      size: Size(400, 400),
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _eyeGlowAnim.value * 0.2 + 0.9,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.blue.withOpacity(_eyeGlowAnim.value),
                          Colors.blueAccent.withOpacity(0.6),
                          Colors.deepPurple.withOpacity(0.4),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.6),
                          blurRadius: 80,
                          spreadRadius: 25,
                        ),
                      ],
                    ),
                    child: Opacity(
                      opacity: 0.27,
                      child: Image.asset(
                        'assets/images/eye.png',
                        color: Colors.white24.withOpacity(_eyeGlowAnim.value),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class MandalaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = size.center(Offset.zero);
    final radius = size.width / 2.5;
    for (double angle = 0; angle < 2 * pi; angle += pi / 36) {
      final dx = center.dx + cos(angle) * radius;
      final dy = center.dy + sin(angle) * radius;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(dx, dy);
      canvas.drawPath(path, paint);
    }
    for (double i = 0; i < radius; i += 20) {
      canvas.drawCircle(center, i, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
