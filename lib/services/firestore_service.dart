import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ── USERS & ACTIVITY ──────────────────────────────────────────────
  Future<void> logSession(Map<String, dynamic> data) =>
      _db.collection('activity_logs').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<Map<String, dynamic>?> getUserDoc(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...snap.data()!};
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final snap = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  Future<void> createUserDoc(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).set(data);

  Future<void> updateUserDoc(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).update(data);

  /// Streams all users — capped at 50 to avoid loading unbounded data.
  Stream<List<Map<String, dynamic>>> listenUsers() =>
      _db.collection('users').limit(50).snapshots().map(
        (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      );

  Future<List<Map<String, dynamic>>> getTeachers() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'teacher').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ── COURSES ───────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCourses() async {
    final snap = await _db.collection('courses').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Fetches a single course by document ID — avoids loading all courses.
  Future<Map<String, dynamic>?> getCourseById(String id) async {
    final snap = await _db.collection('courses').doc(id).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...snap.data()!};
  }

  // ── ORDERS ────────────────────────────────────────────────────────
  Future<void> placeOrder({
    required String studentId,
    required String studentName,
    required String courseId,
    required String courseTitle,
    required int amount,
  }) =>
      _db.collection('orders').add({
        'studentId': studentId,
        'studentName': studentName,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'amount': amount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Streams orders — capped at 50.
  Stream<List<Map<String, dynamic>>> listenOrders() =>
      _db.collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
          );

  Future<void> activateOrder(String orderId, String studentId, String courseId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final userRef = _db.collection('users').doc(studentId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      txn.update(orderRef, {'status': 'active'});
      if (snap.exists) {
        final enrolled = List<String>.from(snap.data()!['enrolled'] ?? []);
        if (!enrolled.contains(courseId)) {
          enrolled.add(courseId);
          txn.update(userRef, {'enrolled': enrolled});
        }
      }
    });
  }

  // ── SUBMISSIONS ───────────────────────────────────────────────────
  Future<void> addSubmission(Map<String, dynamic> data) =>
      _db.collection('submissions').add({
        ...data,
        'status': 'pending',
        'uploadDate': DateTime.now().toIso8601String().split('T')[0],
        'createdAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Map<String, dynamic>>> listenSubmissions({String? studentId}) {
    Query q = _db.collection('submissions').orderBy('createdAt', descending: true);
    if (studentId != null) q = q.where('studentId', isEqualTo: studentId);
    return q.snapshots().map(
      (s) => s.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList(),
    );
  }

  Future<void> updateSubmission(String id, Map<String, dynamic> data) =>
      _db.collection('submissions').doc(id).update(data);

  // ── LEADERBOARD ───────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> listenLeaderboard() =>
      _db.collection('users')
          .orderBy('points', descending: true)
          .limit(20)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  // ── COURSES (ADMIN CRUD) ──────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> listenCourses() =>
      _db.collection('courses').snapshots().map(
        (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      );

  Future<void> addCourse(Map<String, dynamic> data) =>
      _db.collection('courses').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateCourse(String id, Map<String, dynamic> data) =>
      _db.collection('courses').doc(id).update(data);

  Future<void> deleteCourse(String id) =>
      _db.collection('courses').doc(id).delete();

  // ── ORDERS (EXTENDED) ────────────────────────────────────────────
  Future<void> rejectOrder(String orderId) =>
      _db.collection('orders').doc(orderId).update({'status': 'rejected'});

  Future<void> deleteOrder(String orderId) =>
      _db.collection('orders').doc(orderId).delete();

  // ── SUBMISSIONS (ADMIN ALL) ───────────────────────────────────────
  Stream<List<Map<String, dynamic>>> listenAllSubmissions() =>
      _db.collection('submissions')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList());

  // ── STATS ─────────────────────────────────────────────────────────
  Future<Map<String, int>> getStats() async {
    final results = await Future.wait([
      _db.collection('users').count().get(),
      _db.collection('courses').count().get(),
      _db.collection('orders').where('status', isEqualTo: 'pending').count().get(),
      _db.collection('submissions').count().get(),
    ]);
    return {
      'users':       results[0].count ?? 0,
      'courses':     results[1].count ?? 0,
      'pending':     results[2].count ?? 0,
      'submissions': results[3].count ?? 0,
    };
  }

  // ── ANALYTICS ─────────────────────────────────────────────────────

  /// Extended stats for the Analytics tab.
  Future<Map<String, dynamic>> getAnalyticsOverview() async {
    final results = await Future.wait([
      _db.collection('users').count().get(),
      _db.collection('courses').count().get(),
      _db.collection('mock_test_results').count().get(),
      _db.collection('transactions').count().get(),
      _db.collection('orders').where('status', isEqualTo: 'active').count().get(),
    ]);
    return {
      'users':          results[0].count ?? 0,
      'courses':        results[1].count ?? 0,
      'testsTaken':     results[2].count ?? 0,
      'transactions':   results[3].count ?? 0,
      'activeOrders':   results[4].count ?? 0,
    };
  }

  /// Users who signed up in the last [days] days — used for signup growth chart.
  Future<List<Map<String, dynamic>>> getRecentSignups(int days) async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(Duration(days: days)));
    final snap = await _db.collection('users')
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Top [limit] users by number of mock tests taken.
  Future<List<Map<String, dynamic>>> getTopActiveUsers(int limit) async {
    final snap = await _db.collection('mock_test_results')
        .orderBy('completedAt', descending: true)
        .limit(500)
        .get();
    final counts = <String, int>{};
    final lastActivity = <String, dynamic>{};
    for (final doc in snap.docs) {
      final uid = doc.data()['uid'] as String? ?? '';
      if (uid.isEmpty) continue;
      counts[uid] = (counts[uid] ?? 0) + 1;
      lastActivity.putIfAbsent(uid, () => doc.data()['completedAt']);
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topUids = sorted.take(limit).map((e) => e.key).toList();
    if (topUids.isEmpty) return [];
    final userDocs = <Map<String, dynamic>>[];
    for (var i = 0; i < topUids.length; i += 10) {
      final chunk = topUids.sublist(i, (i + 10).clamp(0, topUids.length));
      final docs = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      userDocs.addAll(docs.docs.map((d) => {'id': d.id, ...d.data()}));
    }
    return (userDocs.map((u) => {...u, 'testCount': counts[u['id']] ?? 0}).toList())
      ..sort((a, b) => (b['testCount'] as int).compareTo(a['testCount'] as int));
  }

  /// Recent test results + transactions for a single user (for per-user analytics).
  Future<Map<String, dynamic>> getUserActivityData(String uid) async {
    final results = await Future.wait([
      _db.collection('mock_test_results')
          .where('uid', isEqualTo: uid)
          .orderBy('completedAt', descending: true)
          .limit(20)
          .get(),
      _db.collection('transactions')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get(),
    ]);
    return {
      'tests':        results[0].docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      'transactions': results[1].docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    };
  }

  /// Save the final AI Viva session result.
  Future<void> saveVivaResult(String uid, int courseId, int score, String feedback, {Map<String, double>? location}) async {
    await _db.collection('viva_results').doc().set({
      'uid': uid,
      'courseId': courseId,
      'score': score,
      'feedback': feedback,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── SETTINGS ───────────────────────────────────────────────────────
  Stream<Map<String, dynamic>> listenGlobalSettings() =>
      _db.collection('settings').doc('global').snapshots().map((s) => s.data() ?? {});

  Future<Map<String, dynamic>> getGlobalSettings() async {
    final snap = await _db.collection('settings').doc('global').get();
    return snap.data() ?? {};
  }

  Future<void> updateGlobalSettings(Map<String, dynamic> data) =>
      _db.collection('settings').doc('global').set(data, SetOptions(merge: true));

  // ── TEACHER SPECIFIC ───────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> listenTeacherCourses(String teacherId) =>
      _db.collection('courses').where('teacherId', isEqualTo: teacherId).snapshots().map(
        (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      );

  Stream<List<Map<String, dynamic>>> listenTeacherSubmissions(String teacherId) =>
      _db.collection('submissions').where('teacherId', isEqualTo: teacherId).orderBy('createdAt', descending: true).snapshots().map(
        (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      );
      
  /// Stream news posted by a specific teacher
  Stream<List<Map<String, dynamic>>> listenTeacherNews(String teacherId) {
    return _db.collection('news')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
  
  // ── STUDENT GROUPS ─────────────────────────────────────────────────
  
  /// Create a new student group for a specific course
  Future<void> createStudentGroup(String courseId, String teacherId, String groupName, List<String> studentIds) async {
    await _db.collection('groups').add({
      'courseId': courseId,
      'teacherId': teacherId,
      'name': groupName,
      'studentIds': studentIds,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update an existing student group
  Future<void> updateStudentGroup(String groupId, String groupName, List<String> studentIds) async {
    await _db.collection('groups').doc(groupId).update({
      'name': groupName,
      'studentIds': studentIds,
    });
  }
  
  /// Delete a student group
  Future<void> deleteStudentGroup(String groupId) async {
    await _db.collection('groups').doc(groupId).delete();
  }

  Future<void> addStudentToGroup(String groupId, String studentId) async {
    await _db.collection('groups').doc(groupId).update({
      'studentIds': FieldValue.arrayUnion([studentId])
    });
  }
  
  Future<void> removeStudentFromGroup(String groupId, String studentId) async {
    await _db.collection('groups').doc(groupId).update({
      'studentIds': FieldValue.arrayRemove([studentId])
    });
  }

  /// Stream groups managed by a specific teacher
  Stream<List<Map<String, dynamic>>> listenTeacherGroups(String teacherId) {
    return _db.collection('groups')
      .where('teacherId', isEqualTo: teacherId)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Get groups a specific student belongs to
  Future<List<String>> getStudentGroupIds(String studentId) async {
    final snap = await _db.collection('groups').where('studentIds', arrayContains: studentId).get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Admin: Stream all news
  Stream<List<Map<String, dynamic>>> listenAllNews() {
    return _db.collection('news')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── SS COIN WALLET ────────────────────────────────────────────────

  /// Stream the user's current coin balance.
  Stream<int> listenWallet(String uid) =>
      _db.collection('users').doc(uid).snapshots().map(
        (s) => (s.data()?['coins'] as int?) ?? 0,
      );

  /// Stream last 50 transactions for a user.
  Stream<List<Map<String, dynamic>>> listenTransactions(String uid) =>
      _db.collection('transactions')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// Admin: Stream latest global transactions.
  Stream<List<Map<String, dynamic>>> listenAllTransactions() =>
      _db.collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// Add coins to user wallet (simulated top-up) + log transaction.
  Future<void> topUpCoins(String uid, int coins, int paidAmount) async {
    final batch = _db.batch();
    final userRef = _db.collection('users').doc(uid);
    batch.update(userRef, {'coins': FieldValue.increment(coins)});
    batch.set(_db.collection('transactions').doc(), {
      'uid':         uid,
      'type':        'topup',
      'coins':       coins,
      'amount':      paidAmount,
      'description': 'Top-up: +$coins SS Coins for Rs $paidAmount',
      'createdAt':   FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Deduct coins, enroll student in course, and log spend — all atomic.
  /// Course price is read from Firestore inside the transaction; the client
  /// cannot tamper with it. Firestore rules additionally validate the spend.
  Future<void> spendCoins(String uid, int coins, String courseId, String courseTitle) async {
    await _db.runTransaction((tx) async {
      final courseRef = _db.collection('courses').doc(courseId);
      final userRef   = _db.collection('users').doc(uid);
      final courseSnap = await tx.get(courseRef);
      final userSnap   = await tx.get(userRef);

      if (!courseSnap.exists) throw Exception('Course not found');
      if (!userSnap.exists)   throw Exception('User not found');

      final int price        = (courseSnap.data()!['price'] as num).toInt();
      final int currentCoins = (userSnap.data()!['coins'] as num? ?? 0).toInt();
      final List enrolled    = List.from(userSnap.data()!['enrolledCourses'] ?? []);

      if (enrolled.contains(courseId)) throw Exception('Already enrolled');
      if (currentCoins < price)        throw Exception('Insufficient coins');

      tx.update(userRef, {
        'coins':              currentCoins - price,
        'enrolledCourses':    FieldValue.arrayUnion([courseId]),
        'lastEnrolledCourseId': courseId,
      });
      tx.set(_db.collection('transactions').doc(), {
        'uid':         uid,
        'type':        'spend',
        'coins':       price,
        'courseId':    courseId,
        'description': 'Enrolled: $courseTitle',
        'createdAt':   FieldValue.serverTimestamp(),
      });
    });
  }

  // ── MOCK TEST ENGINE ──────────────────────────────────────────────

  /// Admin: Create a new mock test for a specific course
  Future<void> createMockTest(String courseId, Map<String, dynamic> testData) async {
    testData['courseId'] = courseId;
    testData['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('mock_tests').add(testData);
  }

  /// Stream mock tests for a specific course (with local caching support)
  Stream<List<Map<String, dynamic>>> listenMockTestsForCourse(String courseId) async* {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'mock_tests_$courseId';

    // 1. Yield cached data immediately if available
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      try {
        final List<dynamic> decoded = json.decode(cachedData);
        final cachedList = decoded.cast<Map<String, dynamic>>();
        yield cachedList;
      } catch (e) {
        // Cache decoding failed, ignore and proceed to network fetch
      }
    }

    // 2. Fetch from network and update cache
    yield* _db.collection('mock_tests')
        .where('courseId', isEqualTo: courseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) {
          final items = s.docs.map((d) {
            final data = d.data();
            // Convert Timestamps to Strings before caching
            data.forEach((key, value) {
              if (value is Timestamp) {
                data[key] = value.toDate().toIso8601String();
              }
            });
            return {'id': d.id, ...data};
          }).toList();
          
          // Save to cache
          prefs.setString(cacheKey, json.encode(items));
          return items;
        });
  }

  /// Submit a completed mock test result
  Future<void> submitTestResult(String uid, String testId, String courseId, int score, int total, {Map<String, double>? location}) async {
    await _db.collection('mock_test_results').add({
      'uid': uid,
      'testId': testId,
      'courseId': courseId,
      'score': score,
      'totalQuestions': total,
      'location': location,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get a single mock test by ID
  Future<Map<String, dynamic>?> getMockTestById(String testId) async {
    final snap = await _db.collection('mock_tests').doc(testId).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...snap.data()!};
  }

  /// Get the user's past mock test results (for profile screen)
  Future<List<Map<String, dynamic>>> getMyTestResults(String uid) async {
    final qs = await _db.collection('mock_test_results')
        .where('uid', isEqualTo: uid)
        .orderBy('completedAt', descending: true)
        .get();
    return qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Admin: award (positive delta) or deduct (negative delta) coins with a reason.
  Future<void> adminAdjustCoins(String uid, int delta, String reason) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(uid), {'coins': FieldValue.increment(delta)});
    batch.set(_db.collection('transactions').doc(), {
      'uid':         uid,
      'type':        delta > 0 ? 'admin_award' : 'admin_deduct',
      'coins':       delta,
      'amount':      0,
      'description': 'Admin: $reason (${delta > 0 ? "+" : ""}$delta coins)',
      'createdAt':   FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Admin: Bulk award coins to ALL users (e.g. promotional)
  Future<void> bulkAwardCoins(int coins, String reason) async {
    final usersSnap = await _db.collection('users').get();
    var batch = _db.batch();
    int count = 0;
    for (var doc in usersSnap.docs) {
      batch.update(doc.reference, {'coins': FieldValue.increment(coins)});
      batch.set(_db.collection('transactions').doc(), {
        'uid':         doc.id,
        'type':        'admin_bulk_award',
        'coins':       coins,
        'amount':      0,
        'description': 'Admin Promo: $reason (+$coins coins)',
        'createdAt':   FieldValue.serverTimestamp(),
      });
      count += 2;
      if (count >= 490) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }
  // ── NEWS FEED ───────────────────────────────────────────────────────

  /// Stream all news bites ordered by newest first
  /// Stream specific news related to a user's enrolled courses or global news
  Stream<List<Map<String, dynamic>>> listenStudentNews(List<String> enrolledCourseIds, List<String> groupIds) {
    return _db.collection('news')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).where((n) {
          final cid = n['courseId'];
          // Show news if:
          // 1. It's global (cid is null)
          // 2. It matches an enrolled course
          // 3. It matches a group the student is in
          return cid == null || enrolledCourseIds.contains(cid) || groupIds.contains(cid);
        }).toList());
  }

  /// Admin: Create a new news bite
  Future<void> addNews(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('news').add(data);
  }

  /// Admin: Delete a news bite
  Future<void> deleteNews(String newsId) async {
    await _db.collection('news').doc(newsId).delete();
  }

  /// Check whether a news article with the same title already exists.
  /// Used by GoogleNewsService to avoid duplicate imports.
  Future<bool> newsExistsByTitle(String title) async {
    final snap = await _db
        .collection('news')
        .where('title', isEqualTo: title)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }


  // ── FRIEND SYSTEM ───────────────────────────────────────────────────

  /// Send a friend request to a user.
  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    // Check if request already exists
    final snap = await _db.collection('friend_requests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .get();
    
    if (snap.docs.isEmpty) {
      await _db.collection('friend_requests').add({
        'fromUid': fromUid,
        'toUid': toUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Listen to pending incoming friend requests for a specific user
  Stream<List<Map<String, dynamic>>> listenIncomingFriendRequests(String uid) {
    return _db.collection('friend_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Accept a friend request — only updates the friend_requests doc (no cross-user writes).
  Future<void> acceptFriendRequest(String requestId, String fromUid, String toUid) async {
    await _db.collection('friend_requests').doc(requestId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a friend request — only updates the friend_requests doc.
  Future<void> rejectFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).update({'status': 'rejected'});
  }

  /// Returns UIDs of all accepted friends, derived from friend_requests (no friends array needed).
  Future<List<String>> getAcceptedFriendIds(String uid) async {
    final sentQ = await _db.collection('friend_requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final receivedQ = await _db.collection('friend_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final ids = <String>{};
    for (final d in sentQ.docs) { ids.add(d.data()['toUid'] as String); }
    for (final d in receivedQ.docs) { ids.add(d.data()['fromUid'] as String); }
    return ids.toList();
  }

  /// Fetch a list of user documents for a given list of friend UIDs
  Future<List<Map<String, dynamic>>> getFriendsProfiles(List<dynamic> friendIds) async {
    if (friendIds.isEmpty) return [];
    
    // Firestore `whereIn` is limited to 10 items. For larger friend lists, 
    // we would need to chunk the array or fetch individually.
    final List<Map<String, dynamic>> friendsData = [];
    final chunks = <List<dynamic>>[];
    
    for (var i = 0; i < friendIds.length; i += 10) {
      chunks.add(friendIds.sublist(i, i + 10 > friendIds.length ? friendIds.length : i + 10));
    }

    for (final chunk in chunks) {
      final snap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      friendsData.addAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
    }

    return friendsData;
  }

  // ── BATTLE SYSTEM ───────────────────────────────────────────────────

  /// Issue a new asynchronous battle challenge to a friend
  Future<String> createBattle(String initiatorUid, String opponentUid, String courseId, String testId, Map<String, dynamic> testInfo) async {
    final docRef = await _db.collection('battles').add({
      'initiatorUid': initiatorUid,
      'opponentUid': opponentUid,
      'courseId': courseId,
      'testId': testId,
      'testTitle': testInfo['title'] ?? 'Mock Test',
      'courseTitle': testInfo['courseTitle'] ?? 'Course',
      'status': 'pending', // pending -> active -> completed
      'initiatorScore': null,
      'opponentScore': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Listen to pending incoming battle challenges for a user
  Stream<List<Map<String, dynamic>>> listenIncomingBattles(String uid) {
    return _db.collection('battles')
        .where('opponentUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
  
  /// Listen to active battles where the user has challenged someone and is waiting for them
  Stream<List<Map<String, dynamic>>> listenMyActiveChallenges(String uid) {
    return _db.collection('battles')
        .where('initiatorUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active') // meaning I took it, now waiting for opponent
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Submit my score for a battle. 
  /// If I am the initiator, status becomes 'active' (waiting for opponent).
  /// If I am the opponent, status becomes 'completed'.
  Future<void> submitBattleScore(String battleId, String uid, int score) async {
    final doc = await _db.collection('battles').doc(battleId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    String roleField = (data['initiatorUid'] == uid) ? 'initiatorScore' : 'opponentScore';
    
    // Determine new status
    String newStatus = data['status'];
    if (data['initiatorUid'] == uid && data['status'] == 'pending') {
      newStatus = 'active'; // Initiator played, now opponent needs to play
    } else if (data['opponentUid'] == uid && data['status'] == 'active') {
      newStatus = 'completed'; // Opponent played, match over.
    }

    await _db.collection('battles').doc(battleId).update({
      roleField: score,
      'status': newStatus,
    });
  }

  /// Get battle details
  Future<Map<String, dynamic>?> getBattleMatch(String battleId) async {
    final snap = await _db.collection('battles').doc(battleId).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...snap.data()!};
  }

  // ── PAYMENT REQUESTS (Manual Bank Transfer) ───────────────────────

  /// Submit a new manual payment request (after user sends bank transfer).
  Future<void> submitPaymentRequest({
    required String uid,
    required String userName,
    required String packLabel,
    required int coins,
    required int amount,
    required String screenshotUrl,
  }) =>
      _db.collection('payment_requests').add({
        'uid':          uid,
        'userName':     userName,
        'packLabel':    packLabel,
        'coins':        coins,
        'amount':       amount,
        'screenshotUrl': screenshotUrl,
        'status':       'pending',
        'createdAt':    FieldValue.serverTimestamp(),
      });

  /// Admin: Stream all payment requests ordered by newest first.
  Stream<List<Map<String, dynamic>>> listenPaymentRequests() =>
      _db.collection('payment_requests')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// User: Stream their own payment requests (to show pending/approved status).
  Stream<List<Map<String, dynamic>>> listenMyPaymentRequests(String uid) =>
      _db.collection('payment_requests')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// Admin: Approve a payment request — atomically awards coins and updates status.
  Future<void> approvePaymentRequest(String requestId, String uid, int coins, int amount) async {
    final batch = _db.batch();
    // Mark request approved
    batch.update(_db.collection('payment_requests').doc(requestId), {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });
    // Award coins to user
    batch.update(_db.collection('users').doc(uid), {
      'coins': FieldValue.increment(coins),
    });
    // Log transaction
    batch.set(_db.collection('transactions').doc(), {
      'uid':         uid,
      'type':        'topup',
      'coins':       coins,
      'amount':      amount,
      'description': 'Bank Transfer Approved: +$coins SS Coins for Rs $amount',
      'createdAt':   FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await checkAndAwardBadge(uid, 'first_topup');
  }

  /// Admin: Reject a payment request.
  Future<void> rejectPaymentRequest(String requestId) =>
      _db.collection('payment_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
  // ── GAMIFICATION (Badges) ─────────────────────────────────────────
  
  /// Checks and awards badgings based on user actions. Returns the newly awarded badge ID if any.
  Future<String?> checkAndAwardBadge(String uid, String actionPayload) async {
    final userDoc = await getUserDoc(uid);
    if (userDoc == null) return null;
    
    final badges = List<String>.from(userDoc['badges'] ?? []);
    String? newBadge;

    if (actionPayload == 'first_course' && !badges.contains('scholar')) {
      newBadge = 'scholar';
    } else if (actionPayload == 'first_test' && !badges.contains('novice_tester')) {
      newBadge = 'novice_tester';
    } else if (actionPayload == 'first_battle' && !badges.contains('warrior')) {
      newBadge = 'warrior';
    } else if (actionPayload == 'first_topup' && !badges.contains('supporter')) {
      newBadge = 'supporter';
    }

    if (newBadge != null) {
      badges.add(newBadge);
      await updateUserDoc(uid, {'badges': badges});
      
      // Optionally log badge award to transactions for history
      await _db.collection('transactions').add({
        'uid': uid,
        'type': 'admin_award', // Using star icon visually
        'coins': 0,
        'amount': 0,
        'description': '🏆 Badge Unlocked: ${newBadge.toUpperCase()}!',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return newBadge;
    }
    return null;
  }
}
