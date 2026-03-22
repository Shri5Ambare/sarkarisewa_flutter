// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/lang_toggle.dart';

const _qualifications = ['SLC/SEE', 'Intermediate (10+2)', 'Bachelor', 'Master', 'PhD', 'Other'];

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  String _qual     = 'Bachelor';
  bool _loading    = false;
  bool _obscure    = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _pwdCtrl.dispose(); super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AuthProvider>().signUp(
        _emailCtrl.text.trim(), _pwdCtrl.text, _nameCtrl.text.trim(), _qual,
      );
    } catch (e) {
      setState(() { _error = context.read<AuthProvider>().error; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().lang;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand header — matches login screen
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.saffron, AppColors.violet]),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(child: Icon(Icons.school, color: Colors.white, size: 36)),
                        ),
                        const SizedBox(height: 16),
                        Text(t('signup.title', lang), style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        Text(t('signup.subtitle', lang),
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
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
                  Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            autofillHints: const [AutofillHints.name],
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(labelText: t('signup.name', lang), prefixIcon: const Icon(Icons.person_outlined, color: AppColors.textMuted)),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted)),
                            validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _qual,
                            dropdownColor: AppColors.navyMid,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(labelText: t('signup.qual', lang), prefixIcon: const Icon(Icons.school_outlined, color: AppColors.textMuted)),
                            items: _qualifications.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                            onChanged: (v) => setState(() => _qual = v!),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pwdCtrl,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.newPassword],
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.textMuted),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppButton(label: t('signup.btn', lang), onPressed: _submit, fullWidth: true, loading: _loading),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t('signup.hasAcct', lang), style: const TextStyle(color: AppColors.textMuted)),
                      TextButton(onPressed: () => context.go('/login'), child: const Text('Sign In')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const LangToggle(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
