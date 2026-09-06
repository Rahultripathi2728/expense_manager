import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/split_pro_logo.dart';
import 'profile_page.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfoAsync = ref.watch(packageInfoProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('About Split Pro'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Branding Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const SplitProLogo(size: 64),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Split Pro',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Smart, Fair & Transparent Expense Sharing',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  packageInfoAsync.when(
                    data: (info) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Version ${info.version} (Build ${info.buildNumber})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Mission Statement Card
            _buildCard(
              title: 'Our Mission',
              icon: Icons.lightbulb_outline_rounded,
              iconColor: const Color(0xFFF59E0B),
              child: Text(
                'Split Pro was created with a single mission: to eliminate the awkwardness, mathematical confusion, and stress around group finances. Whether sharing rent with flatmates, splitting road trip expenses, or tracking daily personal spending, Split Pro guarantees that every single rupee is accounted for transparently down to the paisa.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Key Highlights & Features Card
            _buildCard(
              title: 'Key Capabilities',
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFF8B5CF6),
              child: Column(
                children: [
                  _buildFeatureRow(
                    icon: Icons.call_split_rounded,
                    title: 'Flexible Bill Splitting',
                    description: 'Split equally, by exact amount, or itemized shares across any number of group members.',
                  ),
                  const SizedBox(height: 14),
                  _buildFeatureRow(
                    icon: Icons.calculate_outlined,
                    title: 'Splitwise Cumulative Ledger',
                    description: 'When member A pays member B, member C’s debt stays 100% untouched. No balance fluctuations or phantom dues.',
                  ),
                  const SizedBox(height: 14),
                  _buildFeatureRow(
                    icon: Icons.qr_code_scanner_rounded,
                    title: '1-Click Direct UPI Settlement',
                    description: 'Instant launch into GPay, PhonePe, Paytm, or BHIM with prefilled VPA and amount, plus automatic verification dialog.',
                  ),
                  const SizedBox(height: 14),
                  _buildFeatureRow(
                    icon: Icons.cloud_done_outlined,
                    title: 'Real-time Sync & Offline Mode',
                    description: 'Instant synchronization across devices with reliable offline caching so you never lose track.',
                  ),
                  const SizedBox(height: 14),
                  _buildFeatureRow(
                    icon: Icons.picture_as_pdf_outlined,
                    title: 'Export Statements (PDF & CSV)',
                    description: 'Download professionally formatted monthly statements and group ledgers for record keeping.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // How It Works Guide
            _buildCard(
              title: 'How It Works',
              icon: Icons.help_outline_rounded,
              iconColor: const Color(0xFF10B981),
              child: Column(
                children: [
                  _buildStepRow(
                    step: '1',
                    title: 'Create or Join a Group',
                    desc: 'Create a room for flatmates, trips, or projects and share the 6-character code with friends.',
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    step: '2',
                    title: 'Add Expenses on the Go',
                    desc: 'Enter bills, select who paid, choose participants, and let the engine compute individual shares.',
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    step: '3',
                    title: 'Settle Up Effortlessly',
                    desc: 'Check "Who Pays Whom", tap Pay via UPI or Settle, and watch debts reset smoothly to ₹0.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Terms and Conditions Section
            _buildCard(
              title: 'Terms & Conditions',
              icon: Icons.gavel_rounded,
              iconColor: const Color(0xFF06B6D4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTermItem(
                    heading: '1. Acceptance of Terms',
                    body: 'By accessing or using Split Pro, you agree to comply with and be bound by these Terms and Conditions. If you do not agree with any part of these terms, please do not use the application.',
                  ),
                  _buildTermItem(
                    heading: '2. User Accounts & Security',
                    body: 'You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account. You agree to notify us immediately of any unauthorized access or security breach.',
                  ),
                  _buildTermItem(
                    heading: '3. Expense Calculation & Financial Disclaimer',
                    body: 'Split Pro is an expense calculation, tracking, and organization tool. It is not a bank, digital wallet, or payment intermediary. Split Pro facilitates UPI deep links for user convenience; the actual monetary transfer occurs entirely through third-party banking/UPI applications governed by their respective terms.',
                  ),
                  _buildTermItem(
                    heading: '4. Accuracy of Information',
                    body: 'Users are responsible for the accuracy of expense figures, split percentages, and UPI IDs entered. Split Pro strives for mathematical precision in debt minimization and cumulative ledgers but assumes no liability for errors arising from inaccurate user inputs.',
                  ),
                  _buildTermItem(
                    heading: '5. Privacy & Data Protection',
                    body: 'Your personal information, expense records, and group memberships are protected and encrypted. We do not sell or monetize your personal financial data to advertisers or third parties.',
                  ),
                  _buildTermItem(
                    heading: '6. Service Availability & Modifications',
                    body: 'We continuously improve Split Pro. We reserve the right to modify, suspend, or discontinue features with appropriate notice. New updates, including OTP email verification and enhanced settlement features, will be rolled out progressively.',
                  ),
                  _buildTermItem(
                    heading: '7. Limitation of Liability',
                    body: 'To the maximum extent permitted by law, Split Pro and its developers shall not be liable for any indirect, incidental, or consequential damages resulting from the use or inability to use the service.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Footer & Copyright
            Center(
              child: Column(
                children: [
                  Text(
                    'Built with ❤️ for fair financial collaboration.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© ${DateTime.now().year} Split Pro. All Rights Reserved.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepRow({
    required String step,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermItem({
    required String heading,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
