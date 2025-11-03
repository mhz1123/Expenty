import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In...');

      // Sign out first to ensure clean state
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('User cancelled the sign-in');
        return null; // User cancelled the sign-in
      }

      debugPrint('Google user signed in: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('Missing Google Auth tokens');
        return null;
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('Signing in to Firebase...');
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        debugPrint('Firebase user signed in: ${user.uid}');

        // Store user data in Firestore
        try {
          final userDoc = _firestore.collection('users').doc(user.uid);
          final docSnapshot = await userDoc.get();

          if (!docSnapshot.exists) {
            debugPrint('Creating new user document in Firestore...');
            await userDoc.set({
              'uid': user.uid,
              'email': user.email,
              'displayName': user.displayName,
              'photoURL': user.photoURL,
              'createdAt': FieldValue.serverTimestamp(),
            });
            debugPrint('User document created successfully');
          } else {
            debugPrint('User document already exists');
          }
        } catch (e) {
          debugPrint('Error creating user document: $e');
          // Don't fail sign-in if Firestore write fails
        }
      }

      debugPrint('Sign-in successful!');
      return user;
    } catch (e) {
      debugPrint('Error during sign-in: $e');

      // Try to sign out to clean up state
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (_) {}

      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      debugPrint('Sign-out successful');
    } catch (e) {
      debugPrint('Error during sign-out: $e');
    }
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
