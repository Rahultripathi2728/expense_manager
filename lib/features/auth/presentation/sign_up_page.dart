import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/throttler.dart';
import '../data/auth_repository.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  final _throttler = Throttler();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _throttler.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final name = _nameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      
      final uid = await ref
          .read(authStateProvider.notifier)
          .signUpCreate(
            name: name,
            email: email,
            password: _passwordCtrl.text,
          );
      
      setState(() {
        _loading = false;
      });
      if (!mounted) return;
      context.push('/otp', extra: {
        'userId': uid,
        'email': email,
        'name': name,
      });
    } catch (e) {
      if (mounted) setState(() => _error = ErrorFormatter.format(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildToggle(BuildContext context, bool isSignIn) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEBEB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (!isSignIn) {
                context.go('/sign-in');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
              decoration: BoxDecoration(
                color: isSignIn ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isSignIn
                    ? [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Sign In',
                style: TextStyle(
                  fontWeight: isSignIn ? FontWeight.w600 : FontWeight.normal,
                  color: isSignIn ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (isSignIn) {
                context.go('/sign-up');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
              decoration: BoxDecoration(
                color: !isSignIn ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: !isSignIn
                    ? [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Sign Up',
                style: TextStyle(
                  fontWeight: !isSignIn ? FontWeight.w600 : FontWeight.normal,
                  color: !isSignIn ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: 28,
                          height: 28,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Expense Manager',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Toggle Switch
                  _buildToggle(context, false),
                  const SizedBox(height: AppSpacing.xl),

                  // Auth Card
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create Account',
                                    style: Theme.of(context).textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Start tracking your expenses today',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),

                                  // Error
                                  if (_error != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(AppSpacing.md),
                                      decoration: BoxDecoration(
                                        color: AppColors.errorMuted,
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: AppColors.error,
                                            size: 20,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: TextStyle(
                                                color: AppColors.error,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                  ],

                                  // Name
                                  Text(
                                    'Full Name',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _nameCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'John Doe',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty
                                        ? 'Name is required'
                                        : null,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),

                                  // Email
                                  Text(
                                    'Email',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      hintText: 'you@example.com',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Email is required';
                                      }
                                      if (!v.contains('@')) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.lg),

                                  // Password
                                  Text(
                                    'Password',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _passwordCtrl,
                                    obscureText: _obscure,
                                    decoration: InputDecoration(
                                      hintText: '........',
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                        onPressed: () =>
                                            setState(() => _obscure = !_obscure),
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Password is required';
                                      }
                                      if (v.length < 6) return 'Minimum 6 characters';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.xl),

                                  // Sign Up Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : () => _throttler.run(_signUp),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.textPrimary,
                                        foregroundColor: AppColors.surface,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      child: _loading
                                          ? SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.surface,
                                              ),
                                            )
                                          : const Text(
                                              'Create Account',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                  // Sign In Link
                  TextButton(
                    onPressed: () => context.go('/sign-in'),
                    child: Text(
                      'Already have an account? Sign In',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
