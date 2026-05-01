import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/empty_state.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  final _db = FirestoreService();
  
  Map<String, dynamic>? _searchedUser;
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  Future<void> _searchFriend() async {
    final email = _searchCtrl.text.trim();
    if (email.isEmpty) return;
    final currentUid = context.read<AuthProvider>().user!.uid;
    
    setState(() { _isSearching = true; _searchError = null; _searchedUser = null; });
    try {
      final user = await _db.getUserByEmail(email);
      if (user == null) {
        _searchError = 'User not found.';
      } else if (user['id'] == currentUid) {
        _searchError = 'You cannot add yourself.';
      } else {
        _searchedUser = user;
      }
    } catch (e) {
      _searchError = 'Error searching for user.';
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(String toUid) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;
    try {
      await _db.sendFriendRequest(uid, toUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent!'), behavior: SnackBarBehavior.floating));
        setState(() => _searchedUser = null);
        _searchCtrl.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send request'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Please log in.')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'My Friends'),
            Tab(text: 'Add / Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── TAB 1: MY FRIENDS ──
          _MyFriendsTab(uid: uid, db: _db),

          // ── TAB 2: ADD FRIENDS & REQUESTS ──
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Friend', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by Email Address',
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.cardBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (_) => _searchFriend(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: _isSearching ? 'Search...' : 'Search',
                      onPressed: _isSearching ? () {} : _searchFriend,
                    ),
                  ],
                ),
                if (_searchError != null) ...[
                  const SizedBox(height: 12),
                  Text(_searchError!, style: const TextStyle(color: AppColors.ruby)),
                ],
                if (_searchedUser != null) ...[
                  const SizedBox(height: 16),
                  ListTile(
                    tileColor: AppColors.cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: CircleAvatar(backgroundColor: AppColors.primary, child: Text(_searchedUser!['name']?[0] ?? '?')),
                    title: Text(_searchedUser!['name'] ?? 'Unknown', style: const TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text(_searchedUser!['email'] ?? '', style: const TextStyle(color: AppColors.textMuted)),
                    trailing: AppButton(
                      label: 'Add',
                      onPressed: () => _sendRequest(_searchedUser!['id']),
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                const Text('Pending Requests', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _db.listenIncomingFriendRequests(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('No pending friend requests.', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        return _FriendRequestTile(request: req, db: _db, currentUserUid: uid);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendRequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final FirestoreService db;
  final String currentUserUid;

  const _FriendRequestTile({required this.request, required this.db, required this.currentUserUid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: db.getUserDoc(request['fromUid']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const ListTile(title: Text('Loading...', style: TextStyle(color: AppColors.textMuted)));
        final user = snapshot.data!;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.primary, child: Text(user['name']?[0] ?? '?')),
            title: Text(user['name'] ?? 'Unknown', style: const TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(user['email'] ?? '', style: const TextStyle(color: AppColors.textMuted)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Accept friend request',
                  icon: const Icon(Icons.check_circle, color: AppColors.emerald),
                  onPressed: () async {
                    await db.acceptFriendRequest(request['id'], request['fromUid'], currentUserUid);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend added!'), behavior: SnackBarBehavior.floating));
                  },
                ),
                IconButton(
                  tooltip: 'Reject friend request',
                  icon: const Icon(Icons.cancel, color: AppColors.ruby),
                  onPressed: () => db.rejectFriendRequest(request['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MyFriendsTab extends StatelessWidget {
  final String uid;
  final FirestoreService db;

  const _MyFriendsTab({required this.uid, required this.db});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: db.getAcceptedFriendIds(uid).then((ids) => db.getFriendsProfiles(ids)),
      builder: (context, profileSnap) {
        if (profileSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (profileSnap.hasError) return const Center(child: Text('Failed to load friends', style: TextStyle(color: AppColors.ruby)));
        final profiles = profileSnap.data ?? [];
        if (profiles.isEmpty) {
          return const EmptyState(
            emoji: '👋',
            title: 'No friends yet',
            message: 'Add classmates to challenge them in 1-on-1 quiz battles.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: profiles.length,
          itemBuilder: (context, index) {
            final friend = profiles[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.primary, child: Text(friend['name']?[0] ?? '?')),
                title: Text(friend['name'] ?? 'Unknown', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('Points: ${friend['points'] ?? 0}', style: const TextStyle(color: AppColors.saffron)),
                trailing: AppButton(
                  label: 'Battle',
                  style: AppButtonStyle.primary,
                  onPressed: () => context.push('/battle_lobby', extra: friend),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
