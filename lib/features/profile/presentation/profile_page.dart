import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../../update/data/update_service.dart';
import '../../update/presentation/update_dialog.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Avatar
            _buildProfileAvatar(
              context,
              user?.name ?? '',
              profileAsync.valueOrNull?.avatarUrl,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              user?.name ?? 'User',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (profileAsync.valueOrNull?.username != null &&
                profileAsync.valueOrNull!.username!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '@${profileAsync.valueOrNull!.username!}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              user?.email ?? '',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxxl),

            // Settings items
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF2481E9),
                    title: 'Edit Personal Details',
                    subtitle: 'Name, username, UPI & photo',
                    onTap: () => context.push('/profile/edit'),
                  ),
                  const Divider(height: 1, indent: 56),

                  profileAsync.when(
                    loading: () => const SkeletonExpenseCard(),
                    error: (e, _) => const SizedBox(),
                    data: (profile) => _SettingsTile(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: const Color(0xFF10B981),
                      title: 'Monthly Budget',
                      subtitle: profile != null
                          ? '₹${profile.monthlyBudget.toStringAsFixed(0)}'
                          : '₹0',
                      onTap: () => _showBudgetEditor(
                        context,
                        ref,
                        profile?.monthlyBudget ?? 0,
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),

                  _SettingsTile(
                    icon: Icons.lock_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Change Password',
                    subtitle: 'Password security & recovery',
                    onTap: () => context.push('/profile/change-password'),
                  ),
                  const Divider(height: 1, indent: 56),

                  Consumer(
                    builder: (context, ref, _) {
                      final updateState = ref.watch(updateDownloadProvider);
                      if (updateState.status == UpdateStatus.downloading) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Downloading Update (${updateState.progress.toStringAsFixed(0)}%)...',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: updateState.progress / 100,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (updateState.status == UpdateStatus.readyToInstall) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: InkWell(
                            onTap: () => ref.read(updateDownloadProvider.notifier).installApk(),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.install_mobile_rounded, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Update Ready!',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                                      ),
                                      Text(
                                        'Tap here to install now',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => ref.read(updateDownloadProvider.notifier).installApk(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  child: const Text('Install', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return _SettingsTile(
                        icon: Icons.system_update_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        title: 'Check for Updates',
                        subtitle: 'Download in background & install',
                        onTap: () => _checkUpdate(context, ref),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.info_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    title: 'About Split Pro',
                    subtitle: 'Terms, features & app info',
                    onTap: () => context.push('/profile/about'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: _SettingsTile(
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Sign Out',
              titleColor: AppColors.error,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    actions: [
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                ref.read(authStateProvider.notifier).signOut();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: AppColors.surface,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
            const SizedBox(height: AppSpacing.xxl),
            ref.watch(packageInfoProvider).when(
                  data: (info) => Text(
                    'Version ${info.version} (${info.buildNumber})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                        ),
                  ),
                  error: (_, __) => const SizedBox(),
                  loading: () => const SizedBox(),
                ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }



  void _showBudgetEditor(
    BuildContext context,
    WidgetRef ref,
    double currentBudget,
  ) {
    final ctrl = TextEditingController(text: currentBudget.toStringAsFixed(0));
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Set Monthly Budget'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Budget (₹)',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: AppColors.surface,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: loading
                        ? null
                        : () async {
                            final val = double.tryParse(ctrl.text);
                            if (val == null) return;
      
                            final profile = ref
                                .read(currentProfileProvider)
                                .valueOrNull;
                            if (profile == null) return;
      
                            setState(() => loading = true);
                            try {
                              final updated = profile.copyWith(monthlyBudget: val);
                              await ref
                                  .read(profileRepositoryProvider)
                                  .updateProfile(updated);
                              ref.invalidate(currentProfileProvider);
                              if (context.mounted) Navigator.pop(context);
                            } finally {
                              if (context.mounted) setState(() => loading = false);
                            }
                          },
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(
    BuildContext context,
    String name,
    String? avatarUrl,
  ) {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    if (avatarUrl != null && avatarUrl.startsWith('avatar:')) {
      final emoji = avatarUrl.replaceFirst('avatar:', '');
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceVariant,
          border: Border.all(color: AppColors.primary, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 42)),
        ),
      );
    }

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            avatarUrl,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialAvatar(initial),
          ),
        );
      } else if (!kIsWeb) {
        final file = File(avatarUrl);
        if (file.existsSync()) {
          return ClipOval(
            child: Image.file(
              file,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          );
        }
      }
    }

    return _buildInitialAvatar(initial);
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            const Color(0xFF41A5FF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _checkUpdate(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    final updateService = ref.read(updateServiceProvider);
    final updateInfo = await updateService.checkForUpdates();
    
    if (context.mounted) {
      Navigator.pop(context); // Close loading indicator
      
      if (updateInfo.updateAvailable) {
        UpdateDialog.show(context, updateInfo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App is up to date!')),
        );
      }
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? titleColor ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: effectiveColor.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: effectiveColor,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
