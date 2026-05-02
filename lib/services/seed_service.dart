// lib/services/seed_service.dart
//
// Demo seed data for the admin panel.
// All documents written by this service carry a top-level `_seeded: true` flag
// so they can be bulk-deleted later via the "Delete Seed Data" button.
//
// Collections touched:
//   daily_aggregates, cohort_retention, funnel_stats,
//   experiments, admin_segments, settings/feature_flags, settings/maintenance,
//   news, users (demo only — no auth accounts), transactions, orders,
//   battles, mock_test_results, live_classes
import 'package:cloud_firestore/cloud_firestore.dart';

class SeedService {
  final _db = FirebaseFirestore.instance;

  // ── Public entry points ───────────────────────────────────────────────────

  Future<int> seedAll() async {
    int count = 0;
    count += await _seedDailyAggregates();
    count += await _seedCohortRetention();
    count += await _seedFunnelStats();
    count += await _seedExperiments();
    count += await _seedAdminSegments();
    count += await _seedFeatureFlags();
    count += await _seedMaintenanceDoc();
    count += await _seedNews();
    count += await _seedDemoUsers();
    count += await _seedTransactions();
    count += await _seedOrders();
    count += await _seedLiveClasses();
    return count;
  }

  /// Delete every document that has `_seeded: true` in the touched collections.
  Future<int> deleteAllSeedData() async {
    int count = 0;
    const collections = [
      'daily_aggregates',
      'cohort_retention',
      'funnel_stats',
      'experiments',
      'admin_segments',
      'news',
      'users',
      'transactions',
      'orders',
      'live_classes',
      'battles',
      'mock_test_results',
    ];
    for (final col in collections) {
      final snap = await _db
          .collection(col)
          .where('_seeded', isEqualTo: true)
          .get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
        count++;
      }
      if (snap.docs.isNotEmpty) await batch.commit();
    }
    // settings sub-docs: only delete if seeded
    for (final key in ['feature_flags', 'maintenance']) {
      final ref = _db.collection('settings').doc(key);
      final snap = await ref.get();
      if (snap.data()?['_seeded'] == true) {
        await ref.delete();
        count++;
      }
    }
    return count;
  }

  // ── daily_aggregates ─────────────────────────────────────────────────────

  Future<int> _seedDailyAggregates() async {
    final batch = _db.batch();
    final now = DateTime.now();
    int count = 0;

    // 30 days of fake DAU / revenue / Firestore reads
    for (int i = 29; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final id  = '${day.year}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';

      // Trending up slightly over time
      final base    = 80 + (29 - i) * 4;
      final dau     = base + _jitter(20);
      final revenue = (dau * 2.5 + _jitter(50)).round();
      final reads   = 120000 + (29 - i) * 8000 + _jitter(30000);

      batch.set(_db.collection('daily_aggregates').doc(id), {
        'date':           Timestamp.fromDate(day),
        'dau':            dau,
        'wau':            (dau * 3.2).round(),
        'mau':            (dau * 9.1).round(),
        'revenue':        revenue,
        'firestoreReads': reads,
        'newSignups':     _jitter(15) + 5,
        'activeOrders':   _jitter(8)  + 2,
        '_seeded':        true,
      });
      count++;
    }
    await batch.commit();
    return count;
  }

  // ── cohort_retention ─────────────────────────────────────────────────────

  Future<int> _seedCohortRetention() async {
    final batch = _db.batch();
    final now   = DateTime.now();
    int count   = 0;

    for (int w = 11; w >= 0; w--) {
      final cohortStart = now.subtract(Duration(days: w * 7));
      final id = '${cohortStart.year}-'
          '${cohortStart.month.toString().padLeft(2, '0')}-'
          '${cohortStart.day.toString().padLeft(2, '0')}';

      final signups = 100 + _jitter(40);
      // Retention decay: ~70% W1 → ~20% W8
      final retention = <String, double>{};
      double r = 1.0;
      for (int wk = 1; wk <= 12 - w; wk++) {
        r *= (0.65 + _jitter(10) / 100);
        r  = r.clamp(0.05, 0.95);
        retention['w$wk'] = double.parse(r.toStringAsFixed(2));
      }

      batch.set(_db.collection('cohort_retention').doc(id), {
        'cohortDate':    Timestamp.fromDate(cohortStart),
        'signups':       signups,
        'retentionByWeek': retention,
        '_seeded':       true,
      });
      count++;
    }
    await batch.commit();
    return count;
  }

  // ── funnel_stats ─────────────────────────────────────────────────────────

  Future<int> _seedFunnelStats() async {
    await _db.collection('funnel_stats').add({
      'signups':     1240,
      'firstCourse': 780,
      'firstTest':   430,
      'firstBattle': 190,
      'generatedAt': FieldValue.serverTimestamp(),
      '_seeded':     true,
    });
    return 1;
  }

  // ── experiments ──────────────────────────────────────────────────────────

  Future<int> _seedExperiments() async {
    final exps = [
      {
        'key':         'new_dashboard_v2',
        'name':        'New Dashboard Layout',
        'description': 'Tests card-first vs list-first layout for the home screen.',
        'variants':    ['control', 'card_layout', 'list_layout'],
        'active':      true,
        '_seeded':     true,
      },
      {
        'key':         'battle_entry_prompt',
        'name':        'Battle Entry CTA Wording',
        'description': 'Compares "Challenge a Friend" vs "Start Battle" button copy.',
        'variants':    ['control', 'challenge_friend'],
        'active':      true,
        '_seeded':     true,
      },
      {
        'key':         'paywall_position',
        'name':        'Paywall Screen Position',
        'description': 'Shows paywall after 3 lessons vs after first test failure.',
        'variants':    ['after_3_lessons', 'after_first_fail'],
        'active':      false,
        '_seeded':     true,
      },
    ];
    final batch = _db.batch();
    for (final e in exps) {
      batch.set(_db.collection('experiments').doc(), e);
    }
    await batch.commit();
    return exps.length;
  }

  // ── admin_segments ────────────────────────────────────────────────────────

  Future<int> _seedAdminSegments() async {
    final segs = [
      {
        'name':      'Gold Tier Users',
        'filters':   {'tier': 'gold'},
        'createdAt': FieldValue.serverTimestamp(),
        '_seeded':   true,
      },
      {
        'name':      'Inactive 30d',
        'filters':   {'lastActiveDaysAgo': 30},
        'createdAt': FieldValue.serverTimestamp(),
        '_seeded':   true,
      },
      {
        'name':      'Teachers',
        'filters':   {'role': 'teacher'},
        'createdAt': FieldValue.serverTimestamp(),
        '_seeded':   true,
      },
    ];
    final batch = _db.batch();
    for (final s in segs) {
      batch.set(_db.collection('admin_segments').doc(), s);
    }
    await batch.commit();
    return segs.length;
  }

  // ── settings/feature_flags ────────────────────────────────────────────────

  Future<int> _seedFeatureFlags() async {
    await _db.collection('settings').doc('feature_flags').set({
      'pyqEnabled':        true,
      'battleEnabled':     true,
      'liveClassEnabled':  false,
      'writingEnabled':    true,
      'groupsEnabled':     false,
      'newsEnabled':       true,
      '_seeded':           true,
    });
    return 1;
  }

  // ── settings/maintenance ──────────────────────────────────────────────────

  Future<int> _seedMaintenanceDoc() async {
    await _db.collection('settings').doc('maintenance').set({
      'enabled': false,
      'message': 'We are performing scheduled maintenance. Back online at 11pm NPT.',
      '_seeded': true,
    });
    return 1;
  }

  // ── news ──────────────────────────────────────────────────────────────────

  Future<int> _seedNews() async {
    final now = Timestamp.now();
    final items = [
      {
        'title':       'UPSC Prelims 2025 Date Announced',
        'body':        'The Union Public Service Commission has officially announced '
            'the UPSC Prelims 2025 examination date as June 1, 2025.',
        'category':    'upsc',
        'status':      'published',
        'publishedAt': now,
        'imageUrl':    '',
        '_seeded':     true,
      },
      {
        'title':       'Loksewa Aayog Vacancy: 450 Posts Open',
        'body':        'Loksewa Aayog has published a new vacancy notice for 450 '
            'positions across multiple departments.',
        'category':    'loksewa',
        'status':      'pending_approval',
        'submittedAt': now,
        '_seeded':     true,
      },
      {
        'title':       'Banking Sector Recruitment Drive 2025',
        'body':        'Nepal Rastra Bank and multiple commercial banks announce '
            'joint recruitment for 200+ positions.',
        'category':    'banking',
        'status':      'pending_approval',
        'submittedAt': now,
        '_seeded':     true,
      },
      {
        'title':       'SSC CGL 2025 Notification Released',
        'body':        'Staff Selection Commission has released the official notification '
            'for CGL 2025 with 17,727 vacancies.',
        'category':    'ssc',
        'status':      'published',
        'publishedAt': now,
        '_seeded':     true,
      },
      {
        'title':       'Scheduled Article: Education Policy Update',
        'body':        'New national education policy changes affecting competitive exam '
            'syllabi will take effect from 2026.',
        'category':    'general',
        'status':      'scheduled',
        'publishAt':   Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 3))),
        '_seeded':     true,
      },
    ];
    final batch = _db.batch();
    for (final n in items) {
      batch.set(_db.collection('news').doc(), n);
    }
    await batch.commit();
    return items.length;
  }

  // ── demo users ────────────────────────────────────────────────────────────

  Future<int> _seedDemoUsers() async {
    final users = [
      {
        'name':          'Anita Sharma (Demo)',
        'email':         'anita.demo@sarkarisewa.test',
        'role':          'student',
        'tier':          'gold',
        'coins':         340,
        'points':        1250,
        'writingAccess': true,
        'groupAccess':   false,
        '_seeded':       true,
      },
      {
        'name':          'Bikram Thapa (Demo)',
        'email':         'bikram.demo@sarkarisewa.test',
        'role':          'teacher',
        'tier':          'silver',
        'coins':         80,
        'points':        560,
        'writingAccess': true,
        'groupAccess':   true,
        '_seeded':       true,
      },
      {
        'name':          'Chanda Rai (Demo)',
        'email':         'chanda.demo@sarkarisewa.test',
        'role':          'moderator',
        'tier':          'free',
        'coins':         10,
        'points':        90,
        'writingAccess': false,
        'groupAccess':   false,
        '_seeded':       true,
      },
      {
        'name':          'Deepak Magar (Demo)',
        'email':         'deepak.demo@sarkarisewa.test',
        'role':          'finance',
        'tier':          'silver',
        'coins':         25,
        'points':        200,
        'writingAccess': false,
        'groupAccess':   false,
        '_seeded':       true,
      },
      {
        'name':          'Elina Gurung (Demo)',
        'email':         'elina.demo@sarkarisewa.test',
        'role':          'student',
        'tier':          'free',
        'coins':         5,
        'points':        30,
        'disabled':      true,
        'writingAccess': false,
        'groupAccess':   false,
        '_seeded':       true,
      },
    ];
    final batch = _db.batch();
    for (final u in users) {
      batch.set(_db.collection('users').doc(), u);
    }
    await batch.commit();
    return users.length;
  }

  // ── transactions ──────────────────────────────────────────────────────────

  Future<int> _seedTransactions() async {
    final batch = _db.batch();
    final now   = DateTime.now();
    int count   = 0;

    // Spread 20 transactions across last 14 days
    final types    = ['topup', 'topup', 'spend', 'spend', 'award'];
    final amounts  = [100, 200, 50, 150, 75];
    final teachers = ['teacher_seed_1', 'teacher_seed_2'];

    for (int i = 0; i < 20; i++) {
      final daysAgo = i % 14;
      final type    = types[i % types.length];
      final amount  = amounts[i % amounts.length];
      batch.set(_db.collection('transactions').doc(), {
        'uid':        'demo_user_${i % 5}',
        'type':       type,
        'amount':     amount,
        'reason':     type == 'award' ? 'Demo reward' : null,
        'teacherId':  type == 'spend' ? teachers[i % 2] : null,
        'createdAt':  Timestamp.fromDate(now.subtract(Duration(days: daysAgo))),
        '_seeded':    true,
      });
      count++;
    }
    await batch.commit();
    return count;
  }

  // ── orders ────────────────────────────────────────────────────────────────

  Future<int> _seedOrders() async {
    final batch    = _db.batch();
    final now      = DateTime.now();
    final statuses = ['active', 'active', 'pending', 'expired'];
    int count      = 0;

    for (int i = 0; i < 12; i++) {
      batch.set(_db.collection('orders').doc(), {
        'studentId': 'demo_user_${i % 5}',
        'courseId':  'course_demo_${i % 3}',
        'amount':    [499, 999, 1499][i % 3],
        'status':    statuses[i % statuses.length],
        'createdAt': Timestamp.fromDate(now.subtract(Duration(days: i * 2))),
        '_seeded':   true,
      });
      count++;
    }
    await batch.commit();
    return count;
  }

  // ── live_classes ──────────────────────────────────────────────────────────

  Future<int> _seedLiveClasses() async {
    final batch = _db.batch();
    final items = [
      {
        'title':     'UPSC GS Paper I — Crash Course (Demo)',
        'teacherId': 'teacher_seed_1',
        'status':    'published',
        'startTime': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 2))),
        '_seeded':   true,
      },
      {
        'title':     'Loksewa Aptitude Masterclass (Demo)',
        'teacherId': 'teacher_seed_2',
        'status':    'scheduled',
        'publishAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 2))),
        'startTime': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 2, hours: 4))),
        '_seeded':   true,
      },
    ];
    for (final lc in items) {
      batch.set(_db.collection('live_classes').doc(), lc);
    }
    await batch.commit();
    return items.length;
  }

  // ── helper ────────────────────────────────────────────────────────────────

  // Returns a pseudo-random int in [-half, +half] — deterministic per call order.
  static int _jitter(int half) {
    final n = DateTime.now().microsecondsSinceEpoch;
    return (n % (half * 2)) - half;
  }
}
