// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db   = FirestoreService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUp(
    String email, String password, String name, String qualification,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email, password: password,
    );
    await _db.createUserDoc(cred.user!.uid, {
      'email': email,
      'name': name,
      'qualification': qualification,
      'role': 'student',
      'tier': 'free',
      'writingAccess': false,
      'groupAccess': false,
      'enrolledCourses': <String>[],
      'badges': <String>[],
      'friends': <String>[],
      'coins': 0,
      'points': 0,
      'streak': 0,
      'longestStreak': 0,
      'joinDate': DateTime.now().toIso8601String().split('T')[0],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return cred;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in.');
    await user.updatePassword(newPassword);
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Not signed in.');
    }
    final cred = EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(cred);
  }
}
