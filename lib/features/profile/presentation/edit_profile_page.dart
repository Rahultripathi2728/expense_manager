import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _upiCtrl;
  late TextEditingController _budgetCtrl;

  String? _currentAvatarUrl;
  bool _isSaving = false;
  bool _initialized = false;

  // Preset avatar icons
  static const List<String> _presetAvatars = [
    'avatar:😎',
    'avatar:👑',
    'avatar:🚀',
    'avatar:🔥',
    'avatar:💎',
    'avatar:🦁',
    'avatar:🦊',
    'avatar:⚡',
    'avatar:🎯',
    'avatar:🌟',
    'avatar:🎧',
    'avatar:🎨',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _upiCtrl = TextEditingController();
    _budgetCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = ref.read(authStateProvider).valueOrNull;
      final profile = ref.read(currentProfileProvider).valueOrNull;

      _nameCtrl.text = user?.name ?? profile?.fullName ?? '';
      _usernameCtrl.text = profile?.username ?? (user?.name.replaceAll(' ', '_').toLowerCase() ?? '');
      _emailCtrl.text = user?.email ?? '';
      _upiCtrl.text = profile?.upiId ?? '';
      _budgetCtrl.text = (profile?.monthlyBudget ?? 0) > 0
          ? profile!.monthlyBudget.toStringAsFixed(0)
          : '';
      _currentAvatarUrl = profile?.avatarUrl;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _upiCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          _currentAvatarUrl = picked.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo selected! Tap "Save Changes" to apply.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showAvatarPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose Profile Icon or Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a fun emoji icon or upload your own photo',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),

                // Preset Avatars Grid
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _presetAvatars.map((av) {
                    final emoji = av.replaceFirst('avatar:', '');
                    final isSelected = _currentAvatarUrl == av;
                    return InkWell(
                      onTap: () {
                        setState(() => _currentAvatarUrl = av);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.surfaceVariant,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.borderLight,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),

                // Actions: Pick Photo or Reset to Initial
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _pickImageFromGallery();
                        },
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Upload Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() => _currentAvatarUrl = null);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reset to Initial'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToChangeEmail() async {
    HapticHelper.lightTap();
    await context.push('/profile/change-email');
    if (mounted) {
      final updatedUser = ref.read(authStateProvider).valueOrNull;
      if (updatedUser != null && updatedUser.email.isNotEmpty) {
        setState(() {
          _emailCtrl.text = updatedUser.email;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);
    HapticHelper.lightTap();

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      final profile = ref.read(currentProfileProvider).valueOrNull;
      final newName = _nameCtrl.text.trim();
      final newUsername = _usernameCtrl.text.trim();
      final newUpi = _upiCtrl.text.trim();
      final budgetVal = double.tryParse(_budgetCtrl.text.trim()) ?? 0.0;

      // 1. Update name in Auth if changed
      if (user != null && user.name != newName) {
        await ref.read(authStateProvider.notifier).updateName(newName);
      }

      // 2. Update profile document & local storage
      if (profile != null) {
        final updated = profile.copyWith(
          fullName: newName,
          username: newUsername.isNotEmpty ? newUsername : profile.username,
          avatarUrl: _currentAvatarUrl,
          upiId: newUpi.isNotEmpty ? newUpi : null,
          monthlyBudget: budgetVal,
        );

        await ref.read(profileRepositoryProvider).updateProfile(updated);
      }

      ref.invalidate(currentProfileProvider);
      ref.invalidate(authStateProvider);

      if (mounted) {
        HapticHelper.mediumTap();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal details updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update details: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildAvatarWidget(String initial) {
    if (_currentAvatarUrl != null && _currentAvatarUrl!.startsWith('avatar:')) {
      final emoji = _currentAvatarUrl!.replaceFirst('avatar:', '');
      return Container(
        width: 96,
        height: 96,
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
          child: Text(emoji, style: const TextStyle(fontSize: 48)),
        ),
      );
    }

    if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      if (_currentAvatarUrl!.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            _currentAvatarUrl!,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialAvatar(initial),
          ),
        );
      } else if (!kIsWeb) {
        final file = File(_currentAvatarUrl!);
        if (file.existsSync()) {
          return ClipOval(
            child: Image.file(
              file,
              width: 96,
              height: 96,
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
      width: 96,
      height: 96,
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
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final initial = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text[0].toUpperCase()
        : (user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Personal Details'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Avatar Section with Edit Badge
              Center(
                child: Stack(
                  children: [
                    InkWell(
                      onTap: _showAvatarPickerSheet,
                      borderRadius: BorderRadius.circular(48),
                      child: _buildAvatarWidget(initial),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showAvatarPickerSheet,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _showAvatarPickerSheet,
                child: const Text(
                  'Change Profile Icon / Photo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 20),

              // Personal Information Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Full Name Field
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Username Field
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                        hintText: 'e.g. rahul_27',
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          if (val.trim().length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Email Field with Edit / Update Button
                    InkWell(
                      onTap: _navigateToChangeEmail,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.email_outlined, size: 20, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email Address',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _emailCtrl.text.isNotEmpty
                                        ? _emailCtrl.text
                                        : (user?.email ?? 'No email set'),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap to change email via 3-step security check',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payments & Budget Settings Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment & Budget Preferences',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // UPI ID Field
                    TextFormField(
                      controller: _upiCtrl,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID (VPA)',
                        hintText: 'e.g. username@okhdfcbank',
                        prefixIcon: Icon(Icons.qr_code_rounded),
                        helperText: 'Used by group members to settle dues via UPI apps',
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
                          if (!upiRegex.hasMatch(val.trim())) {
                            return 'Invalid UPI ID format (e.g. name@bank)';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Monthly Budget Field
                    TextFormField(
                      controller: _budgetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Budget (₹)',
                        hintText: 'e.g. 15000',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        helperText: 'Used for expense tracking and budget alerts',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Save Changes Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Saving Changes...' : 'Save Changes',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
