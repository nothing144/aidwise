import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up
  Future<String?> signUp({
    required String email, 
    required String password, 
    required String role, 
    required String fullName
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      // Store additional user data (like role) in Firestore
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': role,
        'fullName': fullName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'Idle',
      }).timeout(const Duration(seconds: 20), onTimeout: () {
        throw Exception('Database connection timed out. Please check your internet connection and ensure Firestore is in Test Mode.');
      });
      return null; // Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') return 'The password provided is too weak.';
      if (e.code == 'email-already-in-use') return 'The account already exists for that email.';
      return e.message ?? 'An error occurred during signup.';
    } catch (e) {
      return e.toString();
    }
  }

  // Log In
  Future<String?> login({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'No user found for that email.';
      if (e.code == 'wrong-password') return 'Wrong password provided.';
      return e.message ?? 'An error occurred during login.';
    } catch (e) {
      return e.toString();
    }
  }

  // Get User Role
  Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get()
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception('Firestore read timed out');
      });
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
      return null;
    } catch (e) {
      rethrow; // Let AuthWrapper handle the error UI
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Checking current user
  User? get currentUser => _auth.currentUser;
}
