import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:focus/pages/home_screen.dart';
import 'package:focus/services/firebase_auth_methods.dart';
import 'package:focus/widgets/focus_animation.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = screenWidth / 375; // Standard mobile width
    final bool isLargeScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        image: AssetImage('assets/images/loginpagebg1.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
            SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(24.0 * scaleFactor),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 2 * scaleFactor),
                        Text(
                          'Welcome Back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22 * scaleFactor,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 4 * scaleFactor,
                            color: Colors.white70,
                            shadows: [
                              Shadow(
                                color: Colors.blue,
                                blurRadius: 10 * scaleFactor,
                              )
                            ],
                          ),
                        ),
                        SizedBox(height: 10 * scaleFactor),
                        SizedBox(
                          width: double.infinity,
                          height: 250 * scaleFactor,
                          child: FocusAnimation(),
                        ),
                        SizedBox(height: 50 * scaleFactor),
                        _buildLoginForm(scaleFactor),
                        SizedBox(height: 30 * scaleFactor),
                        _buildLoginButton(scaleFactor),
                        SizedBox(height: 20 * scaleFactor),
                        _buildSocialLoginButtons(scaleFactor, isLargeScreen),
                        SizedBox(height: 20 * scaleFactor),
                        _buildSignUpText(scaleFactor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(double scaleFactor) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15 * scaleFactor),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1 * scaleFactor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 20 * scaleFactor,
                  spreadRadius: 2 * scaleFactor,
                ),
              ],
            ),
            child: TextFormField(
              controller: _emailController,
              style: TextStyle(color: Colors.white, fontSize: 16 * scaleFactor),
              decoration: InputDecoration(
                filled: true,
                fillColor: Color(0xFF11171D).withOpacity(0.9),
                hintText: 'Enter your email',
                hintStyle: TextStyle(
                    color: Colors.white54, fontSize: 14 * scaleFactor),
                prefixIcon: Icon(Icons.email,
                    color: Colors.blue[300], size: 24 * scaleFactor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15 * scaleFactor),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
          ),
          SizedBox(height: 20 * scaleFactor),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15 * scaleFactor),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1 * scaleFactor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 10 * scaleFactor,
                  spreadRadius: 2 * scaleFactor,
                ),
              ],
            ),
            child: TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              style: TextStyle(color: Colors.white, fontSize: 16 * scaleFactor),
              decoration: InputDecoration(
                filled: true,
                fillColor: Color(0xFF11171D).withOpacity(0.9),
                hintText: 'Enter your password',
                hintStyle: TextStyle(
                    color: Colors.white54, fontSize: 14 * scaleFactor),
                prefixIcon: Icon(Icons.lock,
                    color: Colors.blue[300], size: 24 * scaleFactor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.blue[200],
                    size: 24 * scaleFactor,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15 * scaleFactor),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(double scaleFactor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15 * scaleFactor),
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.lightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withOpacity(0.4),
            blurRadius: 50 * scaleFactor,
            spreadRadius: 4 * scaleFactor,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 16 * scaleFactor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15 * scaleFactor),
          ),
        ),
        child: Text(
          'LOGIN',
          style: TextStyle(
            fontSize: 16 * scaleFactor,
            letterSpacing: 2 * scaleFactor,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLoginButtons(double scaleFactor, bool isLargeScreen) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSocialLoginButton(
            icon: Icons.g_translate,
            label: "Google",
            onPressed: _handleGoogleSignIn,
            scaleFactor: scaleFactor,
            width: isLargeScreen ? 200 : 170 * scaleFactor,
          ),
          SizedBox(width: 10 * scaleFactor),
          if (Theme.of(context).platform == TargetPlatform.iOS)
            _buildSocialLoginButton(
              icon: Icons.apple,
              label: "Apple",
              onPressed: _showNotAvailable,
              scaleFactor: scaleFactor,
              width: isLargeScreen ? 200 : 170 * scaleFactor,
            ),
          if (Theme.of(context).platform == TargetPlatform.iOS)
            SizedBox(width: 10 * scaleFactor),
          if (Theme.of(context).platform == TargetPlatform.android)
            _buildSocialLoginButton(
              icon: Icons.facebook,
              label: "Facebook",
              onPressed: _showNotAvailable,
              scaleFactor: scaleFactor,
              width: isLargeScreen ? 200 : 170 * scaleFactor,
            ),
        ],
      ),
    );
  }

  Widget _buildSocialLoginButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required double scaleFactor,
    required double width,
  }) {
    return AnimatedContainer(
      width: width,
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15 * scaleFactor),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1 * scaleFactor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10 * scaleFactor,
            spreadRadius: 2 * scaleFactor,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scaleFactor,
          vertical: 1 * scaleFactor,
        ),
        child: ElevatedButton.icon(
          icon: Icon(icon, color: Colors.white, size: 24 * scaleFactor),
          label: Text(
            label,
            style: TextStyle(
              fontSize: 14 * scaleFactor,
              color: Colors.white,
            ),
          ),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: 16 * scaleFactor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15 * scaleFactor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpText(double scaleFactor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New user? ',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14 * scaleFactor,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushReplacementNamed('/signup');
          },
          child: Text(
            'Sign Up',
            style: TextStyle(
              color: Colors.lightBlue,
              fontSize: 14 * scaleFactor,
              decoration: TextDecoration.underline,
              decorationColor: Colors.lightBlue,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();

      User? user = await _authService.signInWithEmailPassword(email, password);

      if (user != null) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => FocusFlowHome()));
      } else {
        _showErrorSnackBar('Login failed. Please check your credentials.');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    User? user = await _authService.signInWithGoogle();
    if (user != null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => FocusFlowHome()));
    } else {
      _showErrorSnackBar('Google login failed.');
    }
  }

  void _showNotAvailable() {
    _showErrorSnackBar('Not available for now.');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
