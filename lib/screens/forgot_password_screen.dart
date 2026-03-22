// lib/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/lang_toggle.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AuthProvider>().sendPasswordReset(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not send reset email. Check the address.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().lang;
    return Scaffold(
      appBar: AppBar(title: Text(t('forgot.title', lang))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _sent ? _successBody(context, lang) : _formBody(context, lang),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formBody(BuildContext context, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.saffron, AppColors.violet]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.lock_reset, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        Text(t('forgot.sub', lang), style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.ruby.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.ruby.withAlpha(77)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.ruby, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.ruby))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: t('login.email', lang),
            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 24),
        AppButton(label: t('forgot.btn', lang), onPressed: _submit, fullWidth: true, loading: _loading),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('← Back to Login'),
          ),
        ),
        const SizedBox(height: 4),
        const LangToggle(),
      ],
    );
  }

  Widget _successBody(BuildContext context, String lang) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: AppColors.emerald.withAlpha(30),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.emerald),
            ),
            child: const Icon(Icons.mark_email_read_outlined, color: AppColors.emerald, size: 36),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.emerald.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.emerald.withAlpha(77)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.emerald, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(t('forgot.success', lang), style: const TextStyle(color: AppColors.emerald), textAlign: TextAlign.center)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        AppButton(label: '← Back to Login', onPressed: () => context.go('/login'), fullWidth: true),
      ],
    );
  }
}
