// lib/screens/wallet_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/empty_state.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid ?? '';
    final userName = auth.user?.displayName ?? 'User';
    final db = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🪙 SS Coin Wallet'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.saffron, size: 18),
            label: const Text('Buy Coins', style: TextStyle(color: AppColors.saffron, fontSize: 13, fontWeight: FontWeight.w700)),
            onPressed: () => _showCoinPacks(context, uid, userName, db),
          ),
        ],
      ),
      body: Column(children: [
        // ── Balance card ───────────────────────────────────────────
        StreamBuilder<int>(
          stream: db.listenWallet(uid),
          builder: (ctx, snap) {
            if (snap.hasError) return const Text('Error', style: TextStyle(color: AppColors.ruby, fontSize: 36, fontWeight: FontWeight.bold));
            final bal = snap.data ?? 0;
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A1F6E), Color(0xFF1A1035)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.saffron.withAlpha(102)),
                boxShadow: [BoxShadow(color: AppColors.saffron.withAlpha(51), blurRadius: 20, spreadRadius: 2)],
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Your Balance', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$bal', style: const TextStyle(
                      color: AppColors.saffron, fontSize: 42, fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('SS Coins', style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
                  ]),
                  const SizedBox(height: 4),
                  Text('≈ Rs $bal', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ])),
                const Text('🪙', style: TextStyle(fontSize: 52)),
              ]),
            );
          },
        ),

        // ── Pending payment requests banner ─────────────────────────
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: db.listenMyPaymentRequests(uid),
          builder: (ctx, snap) {
            final requests = snap.data ?? [];
            final pending = requests.where((r) => r['status'] == 'pending').toList();
            if (pending.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3020),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald.withAlpha(100)),
              ),
              child: Row(children: [
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.emerald),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Verifying your transaction…',
                    style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('${pending.length} payment${pending.length > 1 ? 's' : ''} under review. Coins will be added once admin approves.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ])),
              ]),
            );
          },
        ),

        // ── Buy button ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.saffron,
                foregroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Buy SS Coins', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              onPressed: () => _showCoinPacks(context, uid, userName, db),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Transaction history ────────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Transaction History', style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.listenTransactions(uid),
            builder: (ctx, snap) {
              if (snap.hasError) return const Center(child: Text('Failed to load transactions.', style: TextStyle(color: AppColors.ruby)));
              if (!snap.hasData) {
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 4,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => const ShimmerBox(height: 68, radius: 12),
                );
              }
              final txns = snap.data!;
              if (txns.isEmpty) {
                return const EmptyState(
                  emoji: '🪙',
                  title: 'No transactions yet',
                  message: 'Top up some SS Coins to start enrolling in courses.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: txns.length,
                itemBuilder: (_, i) => _TxnTile(txns[i]),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showCoinPacks(BuildContext context, String uid, String userName, FirestoreService db) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navyMid,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CoinPackSheet(uid: uid, userName: userName, db: db),
    );
  }
}

// ── Transaction tile ─────────────────────────────────────────────────────────
class _TxnTile extends StatelessWidget {
  final Map<String, dynamic> txn;
  const _TxnTile(this.txn);

  @override
  Widget build(BuildContext context) {
    final coins = txn['coins'] as int? ?? 0;
    final isPositive = coins > 0;
    final type = txn['type'] as String? ?? '';
    final icon = switch (type) {
      'topup'        => Icons.add_circle,
      'spend'        => Icons.school_outlined,
      'admin_award'  => Icons.star,
      'admin_deduct' => Icons.remove_circle,
      _              => Icons.swap_horiz,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (isPositive ? AppColors.emerald : AppColors.ruby).withAlpha(31),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: isPositive ? AppColors.emerald : AppColors.ruby, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(txn['description'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12))),
        Text(
          '${isPositive ? "+" : ""}$coins 🪙',
          style: TextStyle(
            color: isPositive ? AppColors.emerald : AppColors.ruby,
            fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ]),
    );
  }
}

// ── Coin pack selection sheet ─────────────────────────────────────────────────
class CoinPackSheet extends StatelessWidget {
  final String uid;
  final String userName;
  final FirestoreService db;
  const CoinPackSheet({super.key, required this.uid, required this.userName, required this.db});

  static const _packs = [
    (coins: 100,  price: 100,  label: 'Starter',  bonus: '',          emoji: '🪙'),
    (coins: 250,  price: 230,  label: 'Popular',  bonus: '+20 free',  emoji: '💰'),
    (coins: 500,  price: 450,  label: 'Pro',      bonus: '+50 free',  emoji: '💎'),
    (coins: 1000, price: 850,  label: 'Premium',  bonus: '+150 free', emoji: '👑'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 16),
      const Text('Buy SS Coins', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      const Text('Select a pack — you\'ll pay via bank transfer', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.3,
        children: _packs.map((pack) => GestureDetector(
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.navyMid,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => BankPaymentSheet(uid: uid, userName: userName, db: db,
                coins: pack.coins, price: pack.price, packLabel: pack.label),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: pack.label == 'Popular'
                ? const LinearGradient(colors: [Color(0xFF2A1A5E), Color(0xFF3A2A7E)])
                : null,
              color: pack.label != 'Popular' ? AppColors.cardBg : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: pack.label == 'Popular' ? AppColors.saffron : AppColors.border,
                width: pack.label == 'Popular' ? 1.5 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(pack.emoji, style: const TextStyle(fontSize: 20)),
                const Spacer(),
                if (pack.bonus.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.emerald.withAlpha(51), borderRadius: BorderRadius.circular(10)),
                    child: Text(pack.bonus, style: const TextStyle(color: AppColors.emerald, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
              ]),
              const Spacer(),
              Text('${pack.coins} 🪙', style: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w800, fontSize: 15)),
              Text(pack.label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              Text('Rs ${pack.price}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        )).toList(),
      ),
      const SizedBox(height: 12),
      const Text('Pay via bank transfer • Admin verifies & adds coins', style: TextStyle(color: AppColors.textMuted, fontSize: 10), textAlign: TextAlign.center),
    ]),
  );
}

// ── Bank payment sheet ────────────────────────────────────────────────────────
class BankPaymentSheet extends StatefulWidget {
  final String uid;
  final String userName;
  final FirestoreService db;
  final int coins;
  final int price;
  final String packLabel;

  const BankPaymentSheet({
    super.key,
    required this.uid,
    required this.userName,
    required this.db,
    required this.coins,
    required this.price,
    required this.packLabel,
  });

  @override
  State<BankPaymentSheet> createState() => _BankPaymentSheetState();
}

class _BankPaymentSheetState extends State<BankPaymentSheet> {
  bool _loadingSettings = true;
  bool _uploading = false;
  bool _submitted = false;
  String? _error;
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final s = await widget.db.getGlobalSettings();
      if (mounted) setState(() { _settings = s; _loadingSettings = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSettings = false);
    }
  }

  static const _maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const _allowedImageExtensions = ['jpg', 'jpeg', 'png'];

  Future<void> _pickAndSubmit() async {
    setState(() { _error = null; _uploading = true; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _uploading = false);
        return;
      }

      // Validate file
      final file = result.files.first;
      final ext = file.extension?.toLowerCase() ?? '';
      if (!_allowedImageExtensions.contains(ext)) {
        setState(() { _error = 'Only JPG and PNG images are allowed.'; _uploading = false; });
        return;
      }
      if (file.size > _maxFileSizeBytes) {
        setState(() { _error = 'File too large. Maximum size is 5 MB.'; _uploading = false; });
        return;
      }

      // Upload screenshot to Firebase Storage
      final storage = StorageService();
      final storagePath = 'payment_screenshots/${widget.uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        bytes = await File(file.path!).readAsBytes();
      }

      final contentType = ext == 'png' ? 'image/png' : (ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'application/octet-stream');

      final downloadUrl = await storage.uploadFile(
        path: storagePath,
        bytes: bytes,
        contentType: contentType,
      );

      if (downloadUrl == null) {
        throw Exception('Failed to upload to Firebase Storage.');
      }

      // Submit payment request
      await widget.db.submitPaymentRequest(
        uid: widget.uid,
        userName: widget.userName,
        packLabel: widget.packLabel,
        coins: widget.coins,
        amount: widget.price,
        screenshotUrl: downloadUrl,
      );

      if (mounted) setState(() { _submitted = true; _uploading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Upload failed: $e'; _uploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SuccessView(coins: widget.coins, onDone: () => Navigator.pop(context));

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle bar
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          // Header
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Complete Payment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Text('Send money via bank transfer, then upload screenshot', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.saffron.withAlpha(26), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.saffron.withAlpha(100))),
              child: Text('Rs ${widget.price}  •  ${widget.coins} 🪙',
                style: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 20),

          // Bank details card
          if (_loadingSettings)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.saffron),
            ))
          else
            _BankDetailsCard(settings: _settings),

          const SizedBox(height: 20),

          // Steps
          _StepRow('1', 'Open your banking app or eSewa / Khalti'),
          const SizedBox(height: 8),
          _StepRow('2', 'Transfer exactly Rs ${widget.price} to the account above'),
          const SizedBox(height: 8),
          _StepRow('3', 'Take a screenshot of the payment confirmation'),
          const SizedBox(height: 8),
          _StepRow('4', 'Upload screenshot below — admin will verify and add your coins'),
          const SizedBox(height: 20),

          // Error
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.ruby.withAlpha(26), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: AppColors.ruby, fontSize: 12)),
            ),

          // Upload button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _uploading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_file_rounded),
              label: Text(_uploading ? 'Uploading…' : '📤  I\'ve Sent the Payment — Upload Screenshot',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              onPressed: _uploading ? null : _pickAndSubmit,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
        ]),
      ),
    );
  }
}

// ── Bank details card ─────────────────────────────────────────────────────────
class _BankDetailsCard extends StatelessWidget {
  final Map<String, dynamic> settings;
  const _BankDetailsCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final bankName    = settings['bankName']    as String? ?? 'Not configured';
    final accountNo   = settings['accountNo']   as String? ?? 'Not configured';
    final accountName = settings['accountName'] as String? ?? 'Not configured';
    final qrUrl       = settings['bankQrUrl']   as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sky.withAlpha(80)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance, color: AppColors.sky, size: 16),
          const SizedBox(width: 6),
          const Text('Bank Transfer Details', style: TextStyle(color: AppColors.sky, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Details
          Expanded(child: Column(children: [
            _DetailRow('Bank', bankName),
            const SizedBox(height: 8),
            _DetailRow('Account No.', accountNo),
            const SizedBox(height: 8),
            _DetailRow('Account Name', accountName),
          ])),
          // QR Code
          if (qrUrl.isNotEmpty) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(qrUrl, width: 90, height: 90, fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Container(
                    width: 90, height: 90,
                    color: AppColors.navyMid,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.saffron))),
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(color: AppColors.navyMid, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Icon(Icons.qr_code, color: AppColors.textMuted, size: 40))),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
      Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700))),
    ],
  );
}

class _StepRow extends StatelessWidget {
  final String step;
  final String text;
  const _StepRow(this.step, this.text);

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 22, height: 22,
      decoration: BoxDecoration(color: AppColors.saffron.withAlpha(40),
        shape: BoxShape.circle, border: Border.all(color: AppColors.saffron.withAlpha(100))),
      child: Center(child: Text(step, style: const TextStyle(color: AppColors.saffron, fontSize: 11, fontWeight: FontWeight.w800))),
    ),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
  ]);
}

// ── Success view ──────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final int coins;
  final VoidCallback onDone;
  const _SuccessView({required this.coins, required this.onDone});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.emerald.withAlpha(26),
          border: Border.all(color: AppColors.emerald.withAlpha(100), width: 2)),
        child: const Icon(Icons.check_circle_outline, color: AppColors.emerald, size: 42),
      ),
      const SizedBox(height: 16),
      const Text('Request Submitted!', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(
        'Your payment is under review.\n'
        'Once admin verifies the screenshot, $coins 🪙 will be added to your wallet within 24 hours.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 8),
      // Verifying indicator
      Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3020),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.emerald.withAlpha(100)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald)),
          SizedBox(width: 10),
          Text('Verifying your transaction…', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onDone,
          child: const Text('Back to Wallet', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    ]),
  );
}
