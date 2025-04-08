import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:focus/pages/login_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      debugPrint('Sign-up error: $e');
      return null;
    }
  }

  Future<bool> setUsername(String username) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final usernameQuery = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();
      if (usernameQuery.exists) return false;

      await _firestore.collection('users').doc(user.uid).set({
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('usernames').doc(username.toLowerCase()).set({
        'userId': user.uid,
      });

      return true;
    } catch (e) {
      debugPrint('Error setting username: $e');
      return false;
    }
  }

  Future<String?> getUsername(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['username'] as String?;
    } catch (e) {
      debugPrint('Error fetching username: $e');
      return null;
    }
  }

  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      debugPrint('Sign-in error: $e');
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut(); // Ensure fresh token
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      debugPrint('Google Access Token: [redacted]');
      return userCredential.user;
    } catch (e) {
      debugPrint('Google Sign-in error: $e');
      return null;
    }
  }

  Future<String?> getGoogleAccessToken() async {
    try {
      GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
      if (googleUser == null) {
        googleUser = await _googleSignIn.signInSilently();
        if (googleUser == null) {
          debugPrint('No Google user found, prompting sign-in');
          googleUser = await _googleSignIn.signIn();
        }
      }
      if (googleUser == null) {
        debugPrint('Google sign-in canceled or failed');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null) {
        debugPrint('No access token available');
        return null;
      }

      debugPrint('Retrieved Access Token: [redacted]');
      return googleAuth.accessToken;
    } catch (e) {
      debugPrint('Error getting access token: $e');
      return null;
    }
  }

  Future<void> logout(BuildContext context) async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      debugPrint('Logout error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out. Please try again.')),
      );
    }
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

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
