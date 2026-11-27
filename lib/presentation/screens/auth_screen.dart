import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/utils/error_formatter.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../widgets/brand_logo.dart';
import 'user_guide_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool canPop;

  const AuthScreen({super.key, this.canPop = false});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isBusy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showFriendlyAuthError(Object error, AppStrings strings) async {
    final msg = await AppErrorFormatter.formatErrorAsync(error, strings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final strings = ref.read(appStringsProvider);

    setState(() => _isBusy = true);
    try {
      if (_isSignUp) {
        final res = await AuthService.instance.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );
        if (res.user == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.checkEmailConfirm)),
          );
          setState(() => _isSignUp = false);
          return;
        }
      } else {
        await AuthService.instance.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      await ref.read(appSettingsProvider.notifier).setOfflineGuestMode(false);
      if (mounted && widget.canPop) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      await _showFriendlyAuthError(e, strings);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final strings = ref.read(appStringsProvider);
    setState(() => _isBusy = true);
    try {
      await AuthService.instance.signInWithGoogle();
      await ref.read(appSettingsProvider.notifier).setOfflineGuestMode(false);
      if (mounted && widget.canPop) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      await _showFriendlyAuthError(e, strings);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _forgotPassword(AppStrings strings) async {
    final emailCtrl = TextEditingController(text: _emailController.text);
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.forgotPassword),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: strings.emailLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.confirm),
          ),
        ],
      ),
    );
    if (sent == true && emailCtrl.text.trim().isNotEmpty) {
      try {
        await AuthService.instance.resetPassword(emailCtrl.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.resetPasswordSent)),
          );
        }
      } catch (e) {
        await _showFriendlyAuthError(e, strings);
      }
    }
    emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final language = ref.watch(appSettingsProvider.select((s) => s.language));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: widget.canPop ? AppBar(title: Text(strings.signInTitle)) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.canPop)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UserGuideScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.help_outline_rounded, size: 18),
                        label: Text(strings.userGuideTitle),
                      ),
                      SegmentedButton<AppLanguage>(
                        segments: const [
                          ButtonSegment(
                            value: AppLanguage.en,
                            label: Text('EN'),
                          ),
                          ButtonSegment(
                            value: AppLanguage.my,
                            label: Text('မြန်မာ'),
                          ),
                        ],
                        selected: {language},
                        onSelectionChanged: (sel) {
                          ref
                              .read(appSettingsProvider.notifier)
                              .setLanguage(sel.first);
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                const Center(
                  child: BrandLogo(size: 84, borderRadius: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  strings.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  strings.appSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),

                // Google Sign-In
                if (AppEnv.isGoogleSignInConfigured) ...[
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                    label: Text(strings.continueWithGoogle),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: false,
                              label: Text(strings.signInTitle),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text(strings.signUpTitle),
                            ),
                          ],
                          selected: {_isSignUp},
                          onSelectionChanged: (sel) {
                            setState(() => _isSignUp = sel.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_isSignUp) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: strings.displayNameLabel,
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                (_isSignUp && (v == null || v.trim().isEmpty))
                                    ? strings.requiredField
                                    : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: strings.emailLabel,
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return strings.requiredField;
                            }
                            if (!v.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: strings.passwordLabel,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return strings.requiredField;
                            }
                            if (v.length < 6) {
                              return 'Min 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (!_isSignUp) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  _isBusy ? null : () => _forgotPassword(strings),
                              child: Text(strings.forgotPassword),
                            ),
                          ),
                        ] else
                          const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _isBusy ? null : _submitEmail,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: _isBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isSignUp
                                      ? strings.signUpTitle
                                      : strings.signInTitle,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (!widget.canPop) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _isBusy
                        ? null
                        : () => ref
                            .read(appSettingsProvider.notifier)
                            .setOfflineGuestMode(true),
                    icon: const Icon(Icons.offline_bolt_outlined),
                    label: Text(strings.useOfflineBtn),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
