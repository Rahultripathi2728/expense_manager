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
import '../../../shared/widgets/split_pro_logo.dart';

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
            Container(
              width: 80,
              height: 80,
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
                  user?.name.isNotEmpty == true
                      ? user!.name[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              user?.name ?? 'User',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
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
                    onTap: () {
                      final profile = profileAsync.valueOrNull;
                      _showEditProfile(
                        context,
                        ref,
                        user?.name ?? '',
                        profile?.upiId ?? '',
                      );
                    },
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
                    onTap: () => _showChangePassword(context, ref),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.system_update_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Check for Updates',
                    onTap: () => _checkUpdate(context, ref),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.info_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    title: 'About',
                    onTap: () => _showAboutDialog(context),
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

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            SplitProLogo(size: 32),
            SizedBox(width: 12),
            Text('About Split Pro'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Split Pro is your ultimate companion for personal and group financial tracking.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppSpacing.xs),
            Text('• Track personal and group expenses\n• Settle bills with friends unequally or equally\n• View analytics and expense summaries\n• Sync automatically in real time'),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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

  void _showEditProfile(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String currentUpiId,
  ) {
    final nameCtrl = TextEditingController(text: currentName);
    final upiCtrl = TextEditingController(text: currentUpiId);
    bool loading = false;
    String? upiError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Personal Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: upiCtrl,
                decoration: InputDecoration(
                  labelText: 'UPI ID (VPA)',
                  hintText: 'e.g. john@okaxis',
                  errorText: upiError,
                ),
              ),
            ],
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
                            if (nameCtrl.text.trim().isEmpty) return;
                            final upi = upiCtrl.text.trim();
                            if (upi.isNotEmpty) {
                              final upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
                              if (!upiRegex.hasMatch(upi)) {
                                setState(() => upiError = 'Invalid UPI ID format');
                                return;
                              }
                            }
                            
                            setState(() {
                              loading = true;
                              upiError = null;
                            });
                            try {
                              // Update Name
                              await ref
                                  .read(authStateProvider.notifier)
                                  .updateName(nameCtrl.text.trim());
                              
                              // Update UPI ID in Profile
                              final profile = ref.read(currentProfileProvider).valueOrNull;
                              if (profile != null) {
                                final updated = profile.copyWith(upiId: upi.isEmpty ? null : upi);
                                await ref
                                    .read(profileRepositoryProvider)
                                    .updateProfile(updated);
                              }
                              
                              ref.invalidate(currentProfileProvider);
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              // Handle error
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

  void _showChangePassword(BuildContext context, WidgetRef ref) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
                Text(error!, style: TextStyle(color: AppColors.error)),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextField(
                controller: oldCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
            ],
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
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: loading
                        ? null
                        : () async {
                            if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty) return;
      
                            setState(() {
                              loading = true;
                              error = null;
                            });
                            try {
                              await ref
                                  .read(authRepositoryProvider)
                                  .changePassword(
                                    oldPassword: oldCtrl.text,
                                    newPassword: newCtrl.text,
                                  );
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              setState(
                                () => error =
                                    'Failed to change password. Check current password.',
                              );
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
                        : const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
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
