// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/lang_toggle.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  bool _loading    = false;
  bool _obscure    = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AuthProvider>().signIn(
            _emailCtrl.text.trim(),
            _pwdCtrl.text,
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
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: SafeArea(
        child: isWide ? _buildWide(context, lang) : _buildNarrow(context, lang),
      ),
    );
  }

  // ── Mobile / narrow layout ────────────────────────────────────────────────
  Widget _buildNarrow(BuildContext context, String lang) {
    return Stack(
      children: [
        // Decorative background orbs
        Positioned(
          top: -100, right: -80,
          child: _orb(260, AppColors.primary.withAlpha(35)),
        ),
        Positioned(
          bottom: -120, left: -80,
          child: _orb(280, AppColors.violet.withAlpha(28)),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _buildForm(context, lang, headerCentered: true),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tablet / desktop layout — split panel ─────────────────────────────────
  Widget _buildWide(BuildContext context, String lang) {
    return Row(
      children: [
        // Brand panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(gradient: AppGradients.brand),
            child: Stack(
              children: [
                Positioned(
                  top: -80, left: -60,
                  child: _orb(280, Colors.white.withAlpha(40)),
                ),
                Positioned(
                  bottom: -100, right: -80,
                  child: _orb(320, Colors.white.withAlpha(30)),
                ),
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: const Icon(Icons.school_rounded,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Welcome to\nSarkariSewa',
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Nepal's most-trusted exam-prep platform.\nPYQs, mock tests, live classes — all in one place.",
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.white.withAlpha(220)),
                      ),
                      const SizedBox(height: 40),
                      Wrap(
                        spacing: 12, runSpacing: 12,
                        children: const [
                          _BrandBadge(emoji: '🎯', label: '1000+ Mock Tests'),
                          _BrandBadge(emoji: '📚', label: '50+ Courses'),
                          _BrandBadge(emoji: '🏆', label: 'Live Battles'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Form panel
        Expanded(
          flex: 4,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: _buildForm(context, lang, headerCentered: false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared form ──────────────────────────────────────────────────────────
  Widget _buildForm(BuildContext context, String lang,
      {bool headerCentered = true}) {
    final align = headerCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = headerCentered ? TextAlign.center : TextAlign.left;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: align,
          children: [
            if (headerCentered) ...[
              Container(
                width: 76, height: 76,
                decoration: BoxDecoration(
                  gradient: AppGradients.brand,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.brand,
                ),
                child: const Center(
                  child: Icon(Icons.school_rounded, color: Colors.white, size: 38),
                ),
              ),
              const SizedBox(height: AppSpace.x6),
            ],
            Text(
              t('login.title', lang),
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: textAlign,
            ),
            const SizedBox(height: 6),
            Text(
              t('login.subtitle', lang),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              textAlign: textAlign,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.x8),

        // Error banner
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.ruby.withAlpha(20),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.ruby.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.ruby, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.ruby,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.x4),
        ],

        // Form
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: t('login.email', lang),
                    hintText: 'you@example.com',
                    prefixIcon: const Icon(Icons.mail_outline_rounded,
                        color: AppColors.textMuted),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: AppSpace.x4),
                TextFormField(
                  controller: _pwdCtrl,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: t('login.password', lang),
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Forgot password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/forgot-password'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              t('login.forgotPwd', lang),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.x4),

        // Sign in
        AppButton(
          label: t('login.btn', lang),
          onPressed: _submit,
          fullWidth: true,
          loading: _loading,
          size: AppButtonSize.lg,
          trailingIcon: Icons.arrow_forward_rounded,
        ),
        const SizedBox(height: AppSpace.x6),

        // Sign up link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'New to SarkariSewa? ',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            GestureDetector(
              onTap: () => context.go('/signup'),
              child: Text(
                t('login.createAcc', lang),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.x4),

        // Language toggle
        Center(child: const LangToggle()),
      ],
    );
  }

  Widget _orb(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withAlpha(0)]),
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  final String emoji;
  final String label;
  const _BrandBadge({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(45),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
