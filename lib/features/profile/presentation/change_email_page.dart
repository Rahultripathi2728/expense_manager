import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../auth/data/auth_repository.dart';

class ChangeEmailPage extends ConsumerStatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  ConsumerState<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends ConsumerState<ChangeEmailPage> {
  // Step 0: Password verification, Step 1: New email, Step 2: OTP verification
  int _currentStep = 0;

  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  String? _tempUserId;
  int _resendTimerSeconds = 60;
  Timer? _timer;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendTimerSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0) {
        setState(() => _resendTimerSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _verifyCurrentPassword() async {
    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your current password');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    HapticHelper.lightTap();

    try {
      final isValid = await ref.read(authStateProvider.notifier).verifyCurrentPassword(password);
      if (!isValid) {
        setState(() {
          _errorMessage = 'Incorrect password. Please try again.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _currentStep = 1; // Proceed to New Email input
        _loading = false;
      });
      HapticHelper.mediumTap();
    } catch (e) {
      setState(() {
        _errorMessage = ErrorFormatter.format(e);
        _loading = false;
      });
    }
  }

  Future<void> _sendNewEmailOtp() async {
    final newEmail = _emailCtrl.text.trim();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(newEmail)) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser != null && currentUser.email.toLowerCase() == newEmail.toLowerCase()) {
      setState(() => _errorMessage = 'New email cannot be the same as your current email');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    HapticHelper.lightTap();

    try {
      final uid = await ref.read(authStateProvider.notifier).sendEmailChangeOtp(newEmail: newEmail);
      _tempUserId = uid;
      _startResendTimer();
      setState(() {
        _currentStep = 2; // Proceed to OTP verification
        _loading = false;
      });
      HapticHelper.mediumTap();
    } catch (e) {
      setState(() {
        _errorMessage = ErrorFormatter.format(e);
        _loading = false;
      });
    }
  }

  Future<void> _completeEmailChange() async {
    final otpCode = _otpCtrl.text.trim();
    if (otpCode.length < 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit OTP');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    HapticHelper.lightTap();

    try {
      await ref.read(authStateProvider.notifier).completeEmailChange(
            newEmail: _emailCtrl.text.trim(),
            currentPassword: _passwordCtrl.text,
            tempUserId: _tempUserId ?? '',
            otpCode: otpCode,
          );

      if (mounted) {
        HapticHelper.mediumTap();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = ErrorFormatter.format(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Change Email Address',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Email Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Email', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text(
                          currentUser?.email ?? 'Unknown',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step Indicator
            Row(
              children: [
                _buildStepPill(stepIndex: 0, title: '1. Password'),
                const SizedBox(width: 8),
                _buildStepPill(stepIndex: 1, title: '2. New Email'),
                const SizedBox(width: 8),
                _buildStepPill(stepIndex: 2, title: '3. OTP Verify'),
              ],
            ),
            const SizedBox(height: 24),

            // Error Display
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // STEP 0: Verify Password
            if (_currentStep == 0) ...[
              Text(
                'Security Verification',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'To change your email address, please confirm your current account password.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyCurrentPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Verify Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],

            // STEP 1: Enter New Email
            if (_currentStep == 1) ...[
              Text(
                'Enter New Email',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'We will send a 6-digit verification code to your new email to verify ownership.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'New Email Address',
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendNewEmailOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],

            // STEP 2: Enter OTP
            if (_currentStep == 2) ...[
              Text(
                'Verify New Email',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the 6-digit code sent to ${_emailCtrl.text.trim()}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _resendTimerSeconds > 0 || _loading ? null : _sendNewEmailOtp,
                  child: Text(
                    _resendTimerSeconds > 0 ? 'Resend code in ${_resendTimerSeconds}s' : 'Resend Code',
                    style: TextStyle(color: _resendTimerSeconds > 0 ? AppColors.textTertiary : AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _completeEmailChange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm & Update Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepPill({required int stepIndex, required String title}) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : isDone
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : isDone
                    ? const Color(0xFF10B981)
                    : AppColors.borderLight,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive
                  ? Colors.white
                  : isDone
                      ? const Color(0xFF10B981)
                      : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
