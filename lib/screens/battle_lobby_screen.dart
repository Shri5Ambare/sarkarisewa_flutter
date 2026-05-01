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
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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
            Tab(text: 'Incoming'),
            Tab(text: 'Waiting'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // INCOMING — opponent must play
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.listenIncomingBattles(uid),
            builder: (ctx, snap) {
              if (snap.hasError) return _errorView('Error loading challenges.');
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              final battles = snap.data ?? [];
              if (battles.isEmpty) {
                return const _BattleEmpty(
                  emoji: '⚔️',
                  title: 'No incoming challenges',
                  message: 'When a friend challenges you to a battle, it will show up here.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: battles.length,
                itemBuilder: (ctx, i) => _BattleTile(
                  battle: battles[i], db: _db, mode: _BattleMode.incoming,
                ),
              );
            },
          ),

          // WAITING — initiator submitted, opponent hasn't yet
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.listenMyActiveChallenges(uid),
            builder: (ctx, snap) {
              if (snap.hasError) return _errorView('Error loading battles.');
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              final battles = snap.data ?? [];
              if (battles.isEmpty) {
                return const _BattleEmpty(
                  emoji: '⏳',
                  title: 'Nobody to wait for',
                  message: 'Battles you started where the opponent hasn\'t played yet will appear here.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: battles.length,
                itemBuilder: (ctx, i) => _BattleTile(
                  battle: battles[i], db: _db, mode: _BattleMode.waiting,
                ),
              );
            },
          ),

          // COMPLETED — final results, server-decided winner
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.listenCompletedBattles(uid),
            builder: (ctx, snap) {
              if (snap.hasError) return _errorView('Error loading history.');
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              final battles = snap.data ?? [];
              if (battles.isEmpty) {
                return const _BattleEmpty(
                  emoji: '🏆',
                  title: 'No battles yet',
                  message: 'Your win/loss history will show up here once you complete a battle.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: battles.length,
                itemBuilder: (ctx, i) => _BattleTile(
                  battle: battles[i],
                  db: _db,
                  mode: _BattleMode.completed,
                  myUid: uid,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _errorView(String msg) => Center(
        child: Text(msg, style: const TextStyle(color: AppColors.ruby)),
      );

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

enum _BattleMode { incoming, waiting, completed }

class _BattleTile extends StatelessWidget {
  final Map<String, dynamic> battle;
  final FirestoreService db;
  final _BattleMode mode;
  final String? myUid;

  const _BattleTile({
    required this.battle,
    required this.db,
    required this.mode,
    this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    // Whose name to fetch — the *other* player.
    final otherUid = (mode == _BattleMode.incoming)
        ? battle['initiatorUid']
        : battle['opponentUid'];

    return FutureBuilder<Map<String, dynamic>?>(
      future: db.getUserDoc(otherUid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Card(child: ListTile(title: Text('Loading…')));
        }
        final user = snap.data!;
        final total = (battle['totalQuestions'] as num?)?.toInt() ?? 0;

        Widget content;
        switch (mode) {
          case _BattleMode.incoming:
            content = _IncomingBody(
              battle: battle, opponentName: user['name'] ?? 'Player', db: db,
              theirScore: (battle['initiatorScore'] as num?)?.toInt() ?? 0,
              total: total,
            );
            break;
          case _BattleMode.waiting:
            content = _WaitingBody(
              opponentName: user['name'] ?? 'Player',
              myScore: (battle['initiatorScore'] as num?)?.toInt() ?? 0,
              total: total,
            );
            break;
          case _BattleMode.completed:
            final iAmInitiator = battle['initiatorUid'] == myUid;
            final myScore =
                ((iAmInitiator ? battle['initiatorScore'] : battle['opponentScore']) as num?)
                        ?.toInt() ?? 0;
            final theirScore =
                ((iAmInitiator ? battle['opponentScore'] : battle['initiatorScore']) as num?)
                        ?.toInt() ?? 0;
            final winnerUid = battle['winnerUid'] as String?;
            final result = winnerUid == null
                ? 'tie'
                : (winnerUid == myUid ? 'win' : 'loss');
            content = _CompletedBody(
              opponentName: user['name'] ?? 'Player',
              myScore: myScore,
              theirScore: theirScore,
              total: total,
              result: result,
            );
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withAlpha(30),
                    child: Text(
                      (user['name'] as String? ?? 'P').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'] ?? 'Player',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          battle['courseTitle'] ?? '',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                battle['testTitle'] ?? 'Mock Test',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              content,
            ],
          ),
        );
      },
    );
  }
}

class _IncomingBody extends StatelessWidget {
  final Map<String, dynamic> battle;
  final String opponentName;
  final FirestoreService db;
  final int theirScore;
  final int total;

  const _IncomingBody({
    required this.battle,
    required this.opponentName,
    required this.db,
    required this.theirScore,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gold.withAlpha(20),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.gold.withAlpha(80)),
          ),
          child: Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$opponentName scored $theirScore${total > 0 ? ' / $total' : ''} — beat them!',
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Accept & Play',
          icon: Icons.bolt_rounded,
          fullWidth: true,
          onPressed: () async {
            final tests =
                await db.listenMockTestsForCourse(battle['courseId']).first;
            final t = tests.firstWhere(
              (element) => element['id'] == battle['testId'],
              orElse: () => <String, dynamic>{},
            );
            if (t.isEmpty) return;
            if (!context.mounted) return;

            final uid = context.read<AuthProvider>().user!.uid;
            final newBadge = await db.checkAndAwardBadge(uid, 'first_battle');
            if (!context.mounted) return;
            if (newBadge != null) BadgeUnlockDialog.show(context, newBadge);
            context.pushReplacement(
              '/mock-test/${t['id']}',
              extra: {'testInfo': t, 'battleId': battle['id'] as String?},
            );
          },
        ),
      ],
    );
  }
}

class _WaitingBody extends StatelessWidget {
  final String opponentName;
  final int myScore;
  final int total;
  const _WaitingBody({
    required this.opponentName,
    required this.myScore,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: AppColors.textMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your score: $myScore${total > 0 ? ' / $total' : ''}  •  Waiting for $opponentName',
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedBody extends StatelessWidget {
  final String opponentName;
  final int myScore;
  final int theirScore;
  final int total;
  final String result; // 'win' | 'loss' | 'tie'

  const _CompletedBody({
    required this.opponentName,
    required this.myScore,
    required this.theirScore,
    required this.total,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final (badgeColor, badgeLabel, emoji) = switch (result) {
      'win'  => (AppColors.emerald, 'YOU WON', '🏆'),
      'loss' => (AppColors.ruby,    'YOU LOST', '💀'),
      _      => (AppColors.gold,    'TIE',      '🤝'),
    };
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ScoreBlock(
                label: 'You',
                score: myScore,
                total: total,
                highlight: result == 'win',
              ),
            ),
            const SizedBox(width: 10),
            Text('vs', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(width: 10),
            Expanded(
              child: _ScoreBlock(
                label: opponentName,
                score: theirScore,
                total: total,
                highlight: result == 'loss',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: badgeColor.withAlpha(28),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                badgeLabel,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  final String label;
  final int score;
  final int total;
  final bool highlight;
  const _ScoreBlock({
    required this.label,
    required this.score,
    required this.total,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.emerald : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.emerald.withAlpha(20) : AppColors.navyLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            total > 0 ? '$score / $total' : '$score',
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleEmpty extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  const _BattleEmpty({
    required this.emoji,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: AppColors.navyLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
