import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html;
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailAuth(AppLocalizations l) async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = l['fill_all_fields']);
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      final authService = ref.read(authServiceProvider);
      if (_isLogin) {
        await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        if (_nameController.text.isEmpty) {
          setState(() { _error = l['enter_name']; _isLoading = false; });
          return;
        }
        await authService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
      }
    } catch (e) {
      setState(() => _error = _parseError(e.toString(), l));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(String error, AppLocalizations l) {
    if (error.contains('user-not-found')) return l['error_user_not_found'];
    if (error.contains('wrong-password')) return l['error_wrong_password'];
    if (error.contains('email-already-in-use')) return l['error_email_in_use'];
    if (error.contains('weak-password')) return l['error_weak_password'];
    if (error.contains('invalid-email')) return l['error_invalid_email'];
    return l['error_generic'];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF312E81),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Back to landing
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => html.window.location.href = '/',
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: Text(l['back']),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Logo & branding
                      _buildLogo(l),
                      const SizedBox(height: 48),

                      // Auth card
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isLogin ? l['welcome_back'] : l['create_account'],
                              style: Theme.of(context).textTheme.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin ? l['sign_in_subtitle'] : l['signup_subtitle'],
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Google Sign In
                            _buildGoogleButton(l),
                            const SizedBox(height: 20),

                            // Divider
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    l['or'],
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Name field (signup only)
                            if (!_isLogin) ...[
                              TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  hintText: l['full_name'],
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                hintText: l['email_address'],
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),

                            // Password
                            TextField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                hintText: l['password'],
                                prefixIcon: const Icon(Icons.lock_outline),
                              ),
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleEmailAuth(l),
                            ),
                            const SizedBox(height: 8),

                            // Error
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Submit button
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : () => _handleEmailAuth(l),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(_isLogin ? l['sign_in'] : l['sign_up_btn']),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Toggle login/signup
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _error = null;
                                });
                              },
                              child: Text.rich(
                                TextSpan(
                                  text: _isLogin ? l['no_account'] : l['has_account'],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  children: [
                                    TextSpan(
                                      text: _isLogin ? l['signup'] : l['sign_in'],
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Legal links
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () => html.window.location.href = '/privacy/',
                                  child: Text(
                                    l['footer_privacy'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                Text(
                                  '  •  ',
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                ),
                                InkWell(
                                  onTap: () => html.window.location.href = '/terms/',
                                  child: Text(
                                    l['footer_terms'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(AppLocalizations l) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/ticketto_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Ticketto',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l['footer_tagline'],
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(AppLocalizations l) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        icon: Image.network(
          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
          height: 20,
          width: 20,
          errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
        ),
        label: Text(l['continue_google']),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
