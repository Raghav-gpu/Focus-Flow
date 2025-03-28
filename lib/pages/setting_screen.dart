import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focus/services/firebase_auth_methods.dart'; // Assuming this is your AuthService file
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsEnabled = true;
  String? _username; // Add a variable to hold the username

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
    _loadUsername(); // Fetch username when the page initializes
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  Future<void> _loadUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final username = await _authService.getUsername(user.uid);
      setState(() {
        _username =
            username ?? 'User'; // Fallback to 'User' if username is null
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
    if (!value) {
      await _notificationsPlugin.cancelAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isLargeScreen = screenWidth > 600;
    final double scaleFactor =
        screenWidth / 375; // Based on standard mobile width

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Settings',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 24 * scaleFactor.clamp(0.8, 1.2),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isLargeScreen ? 800 : 600),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isLargeScreen ? 40 : 20 * scaleFactor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: isLargeScreen ? 50 : 40 * scaleFactor,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : const AssetImage('assets/images/user_pfp.png')
                              as ImageProvider,
                    ),
                    SizedBox(width: 15 * scaleFactor),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _username ??
                                'Loading...', // Display username or loading state
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (isLargeScreen ? 24 : 22) * scaleFactor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user?.email ?? 'No email',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16 * scaleFactor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30 * scaleFactor),
                _sectionTitle('Account', scaleFactor),
                _settingsOption(
                  Icons.lock,
                  'Reset Password',
                  () {},
                  scaleFactor,
                ),
                _settingsOption(
                  Icons.delete,
                  'Delete Account',
                  () {},
                  scaleFactor,
                ),
                Divider(color: Colors.grey, height: 20 * scaleFactor),
                _sectionTitle('App Preferences', scaleFactor),
                _toggleOption(
                  Icons.notifications,
                  'Notifications',
                  _notificationsEnabled,
                  _toggleNotifications,
                  scaleFactor,
                ),
                _toggleOption(
                  Icons.dark_mode,
                  'Dark Mode',
                  true,
                  (value) {},
                  scaleFactor,
                ),
                _settingsOption(
                  Icons.language,
                  'Change Language',
                  () {},
                  scaleFactor,
                ),
                Divider(color: Colors.grey, height: 20 * scaleFactor),
                _sectionTitle('Support', scaleFactor),
                _settingsOption(
                  Icons.support,
                  'Contact Support',
                  () {},
                  scaleFactor,
                ),
                _settingsOption(
                  Icons.policy,
                  'Privacy Policy',
                  () {},
                  scaleFactor,
                ),
                Divider(color: Colors.grey, height: 20 * scaleFactor),
                _sectionTitle('Terms & Conditions', scaleFactor),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0 * scaleFactor),
                  child: Text(
                    'By using this app, you agree to our Terms & Conditions.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14 * scaleFactor,
                    ),
                  ),
                ),
                Divider(color: Colors.grey, height: 20 * scaleFactor),
                Center(
                  child: ElevatedButton(
                    onPressed: () => _authService.logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(
                        horizontal: 40 * scaleFactor,
                        vertical: 15 * scaleFactor,
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16 * scaleFactor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, double scaleFactor) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: 10 * scaleFactor), // Fix this to 'bottom'
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white60,
          fontSize: 20 * scaleFactor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _settingsOption(
    IconData icon,
    String text,
    VoidCallback onTap,
    double scaleFactor,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white,
        size: 24 * scaleFactor,
      ),
      title: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16 * scaleFactor,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(vertical: 4 * scaleFactor),
    );
  }

  Widget _toggleOption(
    IconData icon,
    String text,
    bool currentValue,
    Function(bool) onChanged,
    double scaleFactor,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white,
        size: 24 * scaleFactor,
      ),
      title: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16 * scaleFactor,
        ),
      ),
      trailing: Transform.scale(
        scale: scaleFactor.clamp(0.8, 1.2),
        child: Switch(
          value: currentValue,
          onChanged: onChanged,
          activeColor: Colors.blueAccent,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 4 * scaleFactor),
    );
  }
}
