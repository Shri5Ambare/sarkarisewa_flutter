// lib/services/audit_service.dart
//
// Records every privileged admin action in `admin_audit_logs`. The log is
// append-only and read-only-by-admins-and-super-admins (rules-enforced).
//
// Conventions:
//   action:    short verb-phrase, e.g. 'course.delete', 'payment.approve',
//              'user.role_change', 'broadcast.push'.
//   target:    a {kind, id} record describing what was acted on.
//   before/after: optional small JSON snapshots — keep these tight, the
//              log isn't a full version-history store.
//
// Example:
//   AuditService().log(
//     action: 'course.delete',
//     target: AuditTarget(kind: 'course', id: courseId),
//     before: {'title': course['title'], 'price': course['price']},
//   );
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditTarget {
  final String kind;
  final String id;
  const AuditTarget({required this.kind, required this.id});

  Map<String, dynamic> toMap() => {'kind': kind, 'id': id};
}

class AuditService {
  AuditService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db   = firestore ?? FirebaseFirestore.instance,
        _auth = auth      ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Best-effort log write. Never throws — audit failures must not block
  /// the underlying admin action.
  Future<void> log({
    required String action,
    required AuditTarget target,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    Map<String, dynamic>? extra,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      // Build the doc explicitly so we omit empty before/after/extra keys
      // — keeps the audit doc compact and easy to scan.
      final doc = <String, dynamic>{
        'adminUid':   user.uid,
        'adminEmail': user.email,
        'action':     action,
        'target':     target.toMap(),
        'createdAt':  FieldValue.serverTimestamp(),
      };
      if (before != null) doc['before'] = before;
      if (after  != null) doc['after']  = after;
      if (extra  != null) doc['extra']  = extra;
      await _db.collection('admin_audit_logs').add(doc);
    } catch (_) {
      // Swallow. Logging shouldn't break the user flow.
    }
  }

  /// Cursor-paginated log feed for the admin "Audit" tab.
  Future<({List<Map<String, dynamic>> items, DocumentSnapshot? cursor})>
      getPage({int pageSize = 25, DocumentSnapshot? startAfter}) async {
    Query<Map<String, dynamic>> q = _db.collection('admin_audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    final snap = await q.get();
    return (
      items: snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      cursor: snap.docs.isEmpty ? null : snap.docs.last,
    );
  }

  /// Live-tail the most recent entries (capped). Useful for the Live Ops
  /// widget that shows "what just happened" on the Dashboard tab.
  Stream<List<Map<String, dynamic>>> listenRecent({int limit = 20}) {
    return _db.collection('admin_audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
