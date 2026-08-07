import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../data/auth_repository.dart';

class MagicLoginPage extends ConsumerStatefulWidget {
  final String userId;
  final String secret;

  const MagicLoginPage({
    super.key,
    required this.userId,
    required this.secret,
  });

  @override
  ConsumerState<MagicLoginPage> createState() => _MagicLoginPageState();
}

class _MagicLoginPageState extends ConsumerState<MagicLoginPage> {
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verify();
    });
  }

  Future<void> _verify() async {
    try {
      await ref
          .read(authStateProvider.notifier)
          .verifyMagicLink(userId: widget.userId, secret: widget.secret);
      // Navigation is handled by router on auth state change
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Invalid or expired magic link.\nPlease try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading) ...[
                CircularProgressIndicator(color: AppColors.textPrimary),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Verifying your magic link...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
              if (_error != null) ...[
                Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.error,
                      ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: () => context.go('/sign-in'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.surface,
                  ),
                  child: const Text('Back to Sign In'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
