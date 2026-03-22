import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/badge_dialog.dart';

class BattleLobbyScreen extends StatefulWidget {
  final Map<String, dynamic>? opponent;
  const BattleLobbyScreen({super.key, this.opponent});

  @override
  State<BattleLobbyScreen> createState() => _BattleLobbyScreenState();
}

class _BattleLobbyScreenState extends State<BattleLobbyScreen> with SingleTickerProviderStateMixin {
  final _db = FirestoreService();
  late TabController _tabCtrl;
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  void _challengeOpponent(Map<String, dynamic> testInfo) async {
    if (widget.opponent == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    
    // Create Battle
    final battleId = await _db.createBattle(
      uid, 
      widget.opponent!['id'], 
      testInfo['courseId'], 
      testInfo['id'], 
      testInfo
    );

    if (!mounted) return;

    // Go directly to Match
    context.pushReplacement('/mock-test/${testInfo['id']}', extra: {'testInfo': testInfo, 'battleId': battleId});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.opponent != null) {
      return _buildChallengeView(context);
    }
    return _buildLobbyDashboard(context);
  }

  Widget _buildLobbyDashboard(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    if (uid == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battleground Lobby'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Incoming Challenges'),
            Tab(text: 'My Active Battles'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // INCOMING CHALLENGES
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.listenIncomingBattles(uid),
            builder: (ctx, snap) {
              if (snap.hasError) return Center(child: Text('Error loading challenges.', style: TextStyle(color: AppColors.ruby)));
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final battles = snap.data ?? [];
              if (battles.isEmpty) return const Center(child: Text('No incoming challenges.'));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: battles.length,
                itemBuilder: (ctx, i) => _BattleTile(battle: battles[i], db: _db, isIncoming: true),
              );
            },
          ),
          
          // MY SENT CHALLENGES
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.listenMyActiveChallenges(uid),
            builder: (ctx, snap) {
              if (snap.hasError) return Center(child: Text('Error loading battles.', style: TextStyle(color: AppColors.ruby)));
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final battles = snap.data ?? [];
              if (battles.isEmpty) return const Center(child: Text('You have no active battles waiting.'));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: battles.length,
                itemBuilder: (ctx, i) => _BattleTile(battle: battles[i], db: _db, isIncoming: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Challenge ${widget.opponent!['name']}')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _db.getCourses(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error loading courses.', style: TextStyle(color: AppColors.ruby)));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final courses = snap.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Step 1: Select a Course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Course'),
                  initialValue: _selectedCourseId,
                  items: courses.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['title'] ?? 'Course'))).toList(),
                  onChanged: (val) {
                    setState(() { _selectedCourseId = val; });
                  },
                ),
                const SizedBox(height: 24),
                
                if (_selectedCourseId != null) ...[
                  const Text('Step 2: Select a Mock Test to battle on', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _db.listenMockTestsForCourse(_selectedCourseId!),
                      builder: (context, testSnap) {
                        if (testSnap.hasError) return Center(child: Text('Error loading tests.', style: TextStyle(color: AppColors.ruby)));
                        if (testSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        final tests = testSnap.data ?? [];
                        if (tests.isEmpty) return const Text('No tests available in this course.');
                        
                        return ListView.builder(
                          itemCount: tests.length,
                          itemBuilder: (ctx, i) {
                            final t = tests[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.quiz, color: AppColors.primary),
                                title: Text(t['title'] ?? 'Mock Test'),
                                subtitle: Text('${t['durationMinutes'] ?? 0} mins'),
                                trailing: AppButton(
                                  label: 'Challenge',
                                  onPressed: () => _challengeOpponent(t),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BattleTile extends StatelessWidget {
  final Map<String, dynamic> battle;
  final FirestoreService db;
  final bool isIncoming;

  const _BattleTile({required this.battle, required this.db, required this.isIncoming});

  @override
  Widget build(BuildContext context) {
    final opponentUid = isIncoming ? battle['initiatorUid'] : battle['opponentUid'];
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: db.getUserDoc(opponentUid),
      builder: (context, snap) {
        if (!snap.hasData) return const Card(child: ListTile(title: Text('Loading...')));
        final user = snap.data!;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isIncoming ? '${user['name']} challenged you!' : 'Waiting for ${user['name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (isIncoming) const Icon(Icons.flash_on, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Test: ${battle['testTitle']}'),
                Text('Course: ${battle['courseTitle']}', style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                
                if (isIncoming)
                  AppButton(
                    label: 'Accept & Play',
                    onPressed: () async {
                      // Fetch the test details and start the mock test with this battleId
                      final tests = await db.listenMockTestsForCourse(battle['courseId']).first;
                      final t = tests.firstWhere((element) => element['id'] == battle['testId']);
                      if (!context.mounted) return;
                      // Award badge before navigating so dialog context is still valid
                      final uid = context.read<AuthProvider>().user!.uid;
                      final newBadge = await db.checkAndAwardBadge(uid, 'first_battle');
                      if (!context.mounted) return;
                      if (newBadge != null) BadgeUnlockDialog.show(context, newBadge);
                      context.pushReplacement('/mock-test/${t['id']}', extra: {'testInfo': t, 'battleId': battle['id'] as String?});
                    },
                  )
                else
                  Text(
                    'Your Score: ${battle['initiatorScore']} / ${battle['totalQuestions'] ?? '?'}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
