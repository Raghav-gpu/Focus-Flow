import 'package:flutter/material.dart';

class GenerateScheduleCard extends StatelessWidget {
  const GenerateScheduleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double cardHeight =
        screenHeight * 0.25; // Adaptive height: 25% of screen height

    return Container(
      width: screenWidth * 0.375, // Half the screen width, same as tasks
      height: cardHeight,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(1),
            spreadRadius: 1,
            blurRadius: 20,
          ),
          BoxShadow(
            color: Colors.lightGreen.withOpacity(0.87),
            spreadRadius: -2,
            blurRadius: 8,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.4),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(
            Icons.arrow_outward_outlined,
            color: Colors.black,
          ),
          const Spacer(flex: 1),
          Center(
            child: Text(
              'Generate\nSchedule',
              style: TextStyle(
                fontSize:
                    screenWidth * 0.045, // Slightly scaled for readability
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
