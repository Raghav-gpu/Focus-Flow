import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focus/services/firebase_auth_methods.dart'; // Assuming this is your AuthService file
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  String? _username;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadDiscordBannerStatus();
  }

  Future<void> _loadUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final username = await _authService.getUsername(user.uid);
      setState(() {
        _username = username ?? 'User';
      });
    }
  }

  Future<void> _loadDiscordBannerStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tips')
          .doc('discord')
          .get();
      if (doc.exists) {
        setState(() {
          _showBanner = doc.data()?['banner'] ?? false;
        });
      }
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _launchDiscord() async {
    final Uri url = Uri.parse('https://discord.gg/kAQ9R9KzCM');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching Discord link: $e')),
      );
    }
  }

  Future<void> _launchFocusFlow() async {
    final Uri url = Uri.parse('https://focusflowapp.io/');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching FocusFlow link: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/settings_page_bg.png'),
                        fit: BoxFit.cover,
                        opacity: 0.4,
                      ),
                    ),
                  ),
                );
              },
            ),
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.06,
                  vertical: screenHeight * 0.04,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showBanner) _buildBannerHeader(context),
                    SizedBox(height: screenHeight * 0.02),
                    _buildProfileHeader(context, user),
                    SizedBox(height: screenHeight * 0.04),
                    _buildSettingsSection(context, 'Support', [
                      _buildOption(
                        Icons.support,
                        'Terms of Service',
                        _launchFocusFlow,
                        context,
                      ),
                      _buildOption(
                        Icons.policy,
                        'Privacy Policy',
                        _launchFocusFlow,
                        context,
                      ),
                    ]),
                    SizedBox(height: screenHeight * 0.06),
                    _buildLogoutButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: _launchDiscord,
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5865F2), Color(0xFF7289DA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/discord_black.png',
              width: screenWidth * 0.1,
              height: screenWidth * 0.1,
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Text(
                'Join our Discord Community',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: screenWidth * 0.06,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, User user) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Row(
      children: [
        CircleAvatar(
          radius: screenWidth * 0.07,
          backgroundImage:
              user.photoURL != null ? NetworkImage(user.photoURL!) : null,
          child: user.photoURL == null
              ? Icon(
                  Icons.person,
                  size: screenWidth * 0.07,
                  color: Colors.grey[400],
                )
              : null,
          backgroundColor: Colors.grey[900],
        ),
        SizedBox(width: screenWidth * 0.04),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _username ?? 'Loading...',
                    style: TextStyle(
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.blue.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  if (!_showBanner)
                    GestureDetector(
                      onTap: _launchDiscord,
                      child: Image.asset(
                        'assets/images/discord_logo.png',
                        width: screenWidth * 0.12,
                        height: screenWidth * 0.12,
                      ),
                    ),
                ],
              ),
              SizedBox(height: screenWidth * 0.015),
              Text(
                user.email ?? 'No email',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(
      BuildContext context, String title, List<Widget> options) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.grey[900]?.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: options),
        ),
      ],
    );
  }

  Widget _buildOption(
      IconData icon, String text, VoidCallback onTap, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.blue.withOpacity(0.4),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: screenWidth * 0.03,
          horizontal: screenWidth * 0.02,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: screenWidth * 0.06),
            SizedBox(width: screenWidth * 0.04),
            Text(
              text,
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Center(
      child: ElevatedButton(
        onPressed: () => _authService.logout(context),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.redAccent, Colors.red],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.08,
            vertical: screenWidth * 0.04,
          ),
          child: Text(
            'Logout',
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
