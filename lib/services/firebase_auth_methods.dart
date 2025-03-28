import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:focus/pages/login_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ✅ Sign Up with Email & Password
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('Sign-up error: $e');
      return null;
    }
  }

  Future<bool> setUsername(String username) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check if username is already taken
      final usernameQuery = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();
      if (usernameQuery.exists) return false;

      // Update user document with username
      await _firestore.collection('users').doc(user.uid).set({
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Reserve the username
      await _firestore.collection('usernames').doc(username.toLowerCase()).set({
        'userId': user.uid,
      });

      return true;
    } catch (e) {
      print('Error setting username: $e');
      return false;
    }
  }

  // Check if user has a username
  Future<String?> getUsername(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['username'] as String?;
    } catch (e) {
      print('Error fetching username: $e');
      return null;
    }
  }

  // ✅ Sign In with Email & Password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('Sign-in error: $e');
      return null;
    }
  }

  // ✅ Google Sign-In
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled sign-in

      // Get Auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      print('Google Sign-in error: $e');
      return null;
    }
  }

  // ✅ Sign Out
  Future<void> logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to the login screen after logout
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      print('Logout error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out. Please try again.')),
      );
    }
  }

  // ✅ Get Current User
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // ✅ Get User Data (Email, Name, Photo URL)
  Map<String, String?> getUserData() {
    User? user = _auth.currentUser;
    if (user != null) {
      return {
        'email': user.email,
        'name': user.displayName,
        'photoUrl': user.photoURL,
      };
    }
    return {};
  }
}
