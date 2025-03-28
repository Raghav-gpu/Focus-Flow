// lib/pages/set_username_screen.dart
import 'package:flutter/material.dart';
import 'package:focus/pages/home_screen.dart';
import 'package:focus/services/firebase_auth_methods.dart';

class SetUsernameScreen extends StatefulWidget {
  @override
  _SetUsernameScreenState createState() => _SetUsernameScreenState();
}

class _SetUsernameScreenState extends State<SetUsernameScreen> {
  final _usernameController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set Your Username')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                errorText: _usernameController.text.isEmpty && _isLoading
                    ? 'Username cannot be empty'
                    : null,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _setUsername,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Save Username'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setUsername() async {
    if (_usernameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final success =
        await _authService.setUsername(_usernameController.text.trim());
    setState(() => _isLoading = false);
    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => FocusFlowHome()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Username taken or error occurred')),
      );
    }
  }
}
