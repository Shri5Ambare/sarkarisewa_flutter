// lib/screens/writing_screen.dart
import 'dart:io';
import 'dart:typed_data';
import '../services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/firestore_service.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/app_button.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});
  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  final _db         = FirestoreService();
  final _titleCtrl  = TextEditingController();
  final _notesCtrl  = TextEditingController();
  bool _submitting  = false;
  String? _toast;
  PlatformFile? _pickedFile;
  double _uploadProgress = 0;

  @override
  void dispose() { _titleCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  static const _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final size = file.size;
      final ext = file.extension?.toLowerCase() ?? '';

      if (!_allowedExtensions.contains(ext)) {
        setState(() => _toast = '❌ Only PDF, JPG, and PNG files are allowed.');
        return;
      }
      if (size > _maxFileSizeBytes) {
        setState(() => _toast = '❌ File too large. Maximum size is 10 MB.');
        return;
      }
      setState(() => _pickedFile = file);
    }
  }

  Future<String?> _uploadFile(String uid) async {
    if (_pickedFile == null) return null;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final objectName = 'submissions/$uid/${timestamp}_${_pickedFile!.name}';

    List<int> bytes;
    if (_pickedFile!.bytes != null) {
      bytes = _pickedFile!.bytes!;
    } else if (_pickedFile!.path != null) {
      bytes = await File(_pickedFile!.path!).readAsBytes();
    } else {
      return null;
    }

    final ext = _pickedFile!.extension?.toLowerCase() ?? '';
    final contentType = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');

    setState(() => _uploadProgress = 0.5);
    
    final storage = StorageService();
    final url = await storage.uploadFile(path: objectName, bytes: Uint8List.fromList(bytes), contentType: contentType);
    
    setState(() => _uploadProgress = 1.0);
    return url;
  }

  Future<void> _submit(AuthProvider auth) async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final uid = auth.user?.uid;
    if (uid == null) return;
    setState(() { _submitting = true; _uploadProgress = 0; });
    try {
      final fileUrl = await _uploadFile(uid);
      await _db.addSubmission({
        'studentId':   uid,
        'studentName': auth.profile?['name'] ?? 'Student',
        'courseId':    'general',
        'courseTitle': 'General Writing',
        'title':       _titleCtrl.text.trim(),
        'notes':       _notesCtrl.text.trim(),
        'fileUrl':     fileUrl ?? '',
        'fileName':    _pickedFile?.name ?? '',
      });
      _titleCtrl.clear(); _notesCtrl.clear();
      setState(() { _toast = '✅ Submission sent for review!'; _pickedFile = null; });
    } catch (_) {
      setState(() => _toast = '❌ Submission failed. Try again.');
    } finally {
      if (mounted) setState(() { _submitting = false; _uploadProgress = 0; });
    }
  }

  Color _statusColor(String s) => switch (s) {
    'reviewed'       => AppColors.emerald,
    'needs_revision' => AppColors.ruby,
    'pending'        => AppColors.gold,
    _                => AppColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LocaleProvider>().lang;
    final hasAccess = auth.profile?['writingAccess'] == true || auth.isTeacher || auth.isAdmin;

    return Scaffold(
      appBar: AppBar(title: Text(t('nav.writing', lang))),
      body: !hasAccess
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withAlpha(20),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold.withAlpha(60)),
                    ),
                    child: const Center(child: Text('✍️', style: TextStyle(fontSize: 42))),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Unlock Writing Practice',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Get AI-reviewed feedback on your written answers and improve your exam performance.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // Feature bullets
                  ...[
                    ('📝', 'Submit written answers for review'),
                    ('⭐', 'AI-powered scoring & feedback'),
                    ('📈', 'Track your writing improvement'),
                  ].map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.$1, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Text(item.$2, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  )),
                  const SizedBox(height: 32),
                  AppButton(
                    label: t('common.upgrade', lang),
                    onPressed: () => context.go('/dashboard'),
                    fullWidth: false,
                    style: AppButtonStyle.gold,
                    icon: Icons.star_outline,
                  ),
                ],
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Toast
              if (_toast != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _toast!.startsWith('✅') ? AppColors.emerald.withAlpha(26) : AppColors.ruby.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _toast!.startsWith('✅') ? AppColors.emerald.withAlpha(77) : AppColors.ruby.withAlpha(77)),
                  ),
                  child: Text(_toast!, style: TextStyle(color: _toast!.startsWith('✅') ? AppColors.emerald : AppColors.ruby)),
                ),
                const SizedBox(height: 16),
              ],

              // Upload card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t('writing.submit', lang), style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Title / Topic', prefixIcon: Icon(Icons.title, color: AppColors.textMuted)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes, color: AppColors.textMuted)),
                    ),
                    const SizedBox(height: 12),

                    // File picker area
                    GestureDetector(
                      onTap: _submitting ? null : _pickFile,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: _pickedFile != null ? AppColors.emerald : AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                          color: _pickedFile != null ? AppColors.emerald.withAlpha(15) : null,
                        ),
                        child: _pickedFile != null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.insert_drive_file, color: AppColors.emerald),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _pickedFile!.name,
                                    style: const TextStyle(color: AppColors.emerald, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 16),
                                  onPressed: () => setState(() => _pickedFile = null),
                                ),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_file, color: AppColors.textMuted),
                                Text('Tap to attach PDF or Image', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                      ),
                    ),

                    // Upload progress
                    if (_submitting && _uploadProgress > 0 && _uploadProgress < 1) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        color: AppColors.saffron,
                        backgroundColor: AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      Center(
                        child: Text('Uploading… ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ),
                    ],

                    const SizedBox(height: 16),
                    AppButton(label: t('writing.submit', lang), onPressed: () => _submit(auth), fullWidth: true, loading: _submitting),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(t('writing.history', lang), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),

              // Submissions history
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _db.listenSubmissions(studentId: auth.user?.uid),
                builder: (ctx, snap) {
                  if (snap.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Failed to load submissions.', style: TextStyle(color: AppColors.ruby), textAlign: TextAlign.center),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.saffron))),
                    );
                  }
                  final subs = snap.data ?? [];
                  if (subs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No submissions yet.', style: TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
                    );
                  }
                  return Column(
                    children: subs.map((s) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(s['uploadDate'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                  if ((s['remark'] ?? '').toString().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Teacher note: ${s['remark']}', style: const TextStyle(color: AppColors.sky, fontSize: 11)),
                                  ],
                                ],
                              )),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(s['status'] ?? '').withAlpha(31),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(s['status'] ?? '', style: TextStyle(color: _statusColor(s['status'] ?? ''), fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          if ((s['fileUrl'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.attach_file, size: 14, color: AppColors.saffron),
                                const SizedBox(width: 4),
                                Text(s['fileName'] ?? 'Attached file',
                                  style: const TextStyle(color: AppColors.saffron, fontSize: 11)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )).toList(),
                  );
                },
              ),
            ],
          ),
    );
  }
}
