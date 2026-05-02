// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/streak_service.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

class AuthProvider extends ChangeNotifier {
  final _authService      = AuthService();
  final _firestoreService = FirestoreService();
  final _streakService    = StreakService();

  User? _user;
  Map<String, dynamic>? _profile;
  List<String> _groupIds = [];
  bool _loading = true;
  String? _error;

  User?                   get user    => _user;
  Map<String, dynamic>?   get profile => _profile;
  List<String>            get groupIds => _groupIds;
  bool                    get loading => _loading;
  String?                 get error   => _error;
  bool                    get isLoggedIn  => _user != null;
  String get role => _profile?['role'] ?? 'guest';
  String get tier => _profile?['tier'] ?? 'free';
  bool   get isAdmin        => role == 'admin';
  bool   get isTeacher      => role == 'teacher';
  bool   get isStudent      => role == 'student';
  bool   get isSuperAdmin   => role == 'super_admin';
  bool   get isModerator    => role == 'moderator';
  bool   get isFinance      => role == 'finance';
  bool   get isTeacherAdmin => role == 'teacher_admin';
  /// True for both admin and super_admin — used for routing guards.
  bool   get isAdminLevel  => role == 'admin' || role == 'super_admin' ||
      role == 'moderator' || role == 'finance' || role == 'teacher_admin';

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? firebaseUser) async {
    _user = firebaseUser;
    if (firebaseUser != null) {
      try {
        _profile = await _firestoreService.getUserDoc(firebaseUser.uid);
        if (_profile != null && _profile!['role'] == 'student') {
          _groupIds = await _firestoreService.getStudentGroupIds(firebaseUser.uid);
        } else {
          _groupIds = [];
        }
      } catch (e) {
        _error = 'Failed to load user profile. Please check your connection.';
      }

      // Update daily-open streak (best-effort).
      try {
        final newStreak = await _streakService.recordOpen(firebaseUser.uid);
        if (newStreak != null) _profile?['streak'] = newStreak;
      } catch (_) {
        // Silently ignore — streak is non-critical.
      }

      // Try to get and save FCM Token (Independent of profile loading)
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _firestoreService.updateUserDoc(firebaseUser.uid, {'fcmToken': token});
          _profile?['fcmToken'] = token;
        }
      } catch (e) {
        // Silently fail for FCM to not block app access
      }
    } else {
      _profile = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    _error = null;
    try {
      await _authService.signIn(email, password);
    } on FirebaseAuthException catch (e) {
      _error = _humanizeError(e.code);
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Login failed. Please check your internet connection.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String name, String qualification) async {
    _error = null;
    try {
      await _authService.signUp(email, password, name, qualification);
    } on FirebaseAuthException catch (e) {
      _error = _humanizeError(e.code);
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Registration failed. Please check your internet connection.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<void> sendPasswordReset(String email) =>
      _authService.sendPasswordReset(email);

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestoreService.updateUserDoc(uid, data);
      _profile = {...?_profile, ...data};
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update profile. Please check your connection.';
      notifyListeners();
      rethrow;
    }
  }

  String _humanizeError(String code) {
    switch (code) {
      case 'user-not-found':      return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':  return 'Incorrect password. Please try again.';
      case 'email-already-in-use':return 'An account already exists with this email.';
      case 'weak-password':       return 'Password must be at least 6 characters.';
      case 'invalid-email':       return 'Please enter a valid email address.';
      case 'too-many-requests':   return 'Too many attempts. Please wait a moment.';
      default:                    return 'Something went wrong. Please try again.';
    }
  }
}
