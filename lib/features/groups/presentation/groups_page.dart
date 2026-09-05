import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../data/group_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/group_model.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';
import '../../../shared/widgets/custom_error_widget.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;

    final titleCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Groups',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage shared expenses with friends and family',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );

    final joinButton = OutlinedButton.icon(
      onPressed: () => _showJoinGroup(context, ref),
      icon: Icon(Icons.group_add_rounded, size: 18, color: AppColors.primary),
      label: const Text('Join Group'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.primary.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );

    final createButton = ElevatedButton.icon(
      onPressed: () => _showCreateGroup(context, ref),
      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
      label: const Text('Create Group'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        minimumSize: const Size(0, 44),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleCol,
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: joinButton),
              const SizedBox(width: 10),
              Expanded(child: createButton),
            ],
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titleCol),
          const SizedBox(width: 16),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                joinButton,
                const SizedBox(width: 10),
                createButton,
              ],
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final groupsAsync = ref.watch(userGroupsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.surface,
        backgroundColor: AppColors.textPrimary,
        strokeWidth: 3,
        onRefresh: () async {
          // Invalidate the provider to trigger a re-fetch
          ref.invalidate(userGroupsProvider);
          // Wait a short moment so the animation has time to show
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ref),
              const SizedBox(height: AppSpacing.xl),

              groupsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: SkeletonGroupList(itemCount: 4),
                ),
                error: (e, st) => CustomErrorWidget(
                  error: e,
                  onRetry: () => ref.refresh(userGroupsProvider),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceVariant),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 56,
                            color: AppColors.textDisabled,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'No groups yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create or join a group to split expenses',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final isAdmin = group.createdBy == user?.id;

                      // Staggered entry animation
                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 300 + (index * 80)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, child) {
                          return Opacity(
                            opacity: val,
                            child: Transform.translate(
                              offset: Offset(0, 15 * (1 - val)),
                              child: child,
                            ),
                          );
                        },
                        child: _GroupCard(
                          group: group,
                          isAdmin: isAdmin,
                          onTap: () => context.push('/group/${group.id}'),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGroup(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.surface,
          title: Text(
            'Create Group',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'Enter group name',
                ),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What is this group for?',
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
                            final name = nameCtrl.text.trim();
                            final desc = descCtrl.text.trim();
                            if (name.isEmpty) return;
      
                            final user = ref.read(authStateProvider).valueOrNull;
                            if (user == null) return;
      
                            setState(() => loading = true);
                            try {
                              await ref
                                  .read(groupRepositoryProvider)
                                  .createGroup(name, desc.isEmpty ? null : desc, user.id);
                              ref.invalidate(userGroupsProvider);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Group "$name" created successfully!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    backgroundColor: const Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) setState(() => loading = false);
                            }
                          },
                    child: loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surface,
                            ),
                          )
                        : const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinGroup(BuildContext context, WidgetRef ref) {
    final codeCtrl = TextEditingController();
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.surface,
          title: Text(
            'Join Group',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the 6-character join code',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: codeCtrl,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Join Code',
                  errorText: error,
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
                            final code = codeCtrl.text.trim();
                            if (code.length != 6) {
                              setState(() => error = 'Code must be 6 characters');
                              return;
                            }
      
                            setState(() {
                              loading = true;
                              error = null;
                            });
                            try {
                              final currentUser = ref
                                  .read(authStateProvider)
                                  .valueOrNull;
                              if (currentUser == null) return;
                              await ref
                                  .read(groupRepositoryProvider)
                                  .joinGroup(code, currentUser.id);
                              ref.invalidate(userGroupsProvider);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Joined group successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    backgroundColor: Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(
                                () => error = 'Invalid code or already joined',
                              );
                            } finally {
                              if (context.mounted) setState(() => loading = false);
                            }
                          },
                    child: loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surface,
                            ),
                          )
                        : const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  final Group group;
  final bool isAdmin;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _isHovered = false;

  static const _gradients = [
    [Color(0xFF2481E9), Color(0xFF00CEFF)], // Blue to Cyan
    [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo to Purple
    [Color(0xFFEC4899), Color(0xFFF43F5E)], // Rose to Pink
    [Color(0xFF10B981), Color(0xFF14B8A6)], // Emerald to Teal
    [Color(0xFFF59E0B), Color(0xFFF97316)], // Amber to Orange
    [Color(0xFF8B5CF6), Color(0xFFD946EF)], // Purple to Fuchsia
  ];

  List<Color> _getGroupGradient(String name) {
    if (name.isEmpty) return _gradients[0];
    final index = name.codeUnits.fold(0, (sum, c) => sum + c) % _gradients.length;
    return _gradients[index];
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _getGroupGradient(widget.group.name);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.diagonal3Values(
          _isHovered ? 1.015 : 1.0,
          _isHovered ? 1.015 : 1.0,
          1.0,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? AppColors.textPrimary : AppColors.borderLight,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: _isHovered ? 0.04 : 0.01),
              blurRadius: _isHovered ? 12 : 6,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.group.name.trim().isNotEmpty
                      ? widget.group.name.trim()[0].toUpperCase()
                      : 'G',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.group.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.isAdmin) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Admin',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.group.joinCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Join Code "${widget.group.joinCode}" copied!',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: const Color(0xFF1E293B),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tag_rounded, size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 2),
                            Text(
                              widget.group.joinCode,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.copy_rounded, size: 11, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}
