// lib/services/streak_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Maintains a daily-open streak on the user document.
///
/// Rules:
/// - Same calendar day as last open → no change.
/// - Exactly the next calendar day → streak += 1.
/// - Any other gap → streak = 1.
/// - Tracks `longestStreak` as the max ever reached.
class StreakService {
  StreakService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Returns the new streak value, or null if nothing changed.
  Future<int?> recordOpen(String uid) async {
    final ref = _db.collection('users').doc(uid);
    return _db.runTransaction<int?>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return null;

      final data = snap.data() ?? {};
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final ts = data['lastActiveAt'];
      DateTime? lastDay;
      if (ts is Timestamp) {
        final d = ts.toDate().toLocal();
        lastDay = DateTime(d.year, d.month, d.day);
      }

      final current = (data['streak'] as num?)?.toInt() ?? 0;
      final longest = (data['longestStreak'] as num?)?.toInt() ?? 0;

      int next;
      if (lastDay == null) {
        next = 1;
      } else if (lastDay == today) {
        // Already counted today — only refresh timestamp.
        tx.update(ref, {'lastActiveAt': FieldValue.serverTimestamp()});
        return null;
      } else if (today.difference(lastDay).inDays == 1) {
        next = current + 1;
      } else {
        next = 1;
      }

      tx.update(ref, {
        'streak': next,
        'longestStreak': next > longest ? next : longest,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      return next;
    });
  }
}
