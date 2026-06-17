import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/appwrite_client.dart';
import '../../../core/utils/row_helpers.dart';
import '../../expenses/presentation/add_expense/add_expense_screen.dart'; // for groupProfilesProvider
import '../domain/group_model.dart';
import '../domain/group_member_model.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';
import '../data/group_repository.dart';
import '../../auth/data/auth_repository.dart';

final groupDetailProvider = FutureProvider.family<Group?, String>((
  ref,
  groupId,
) async {
  final tablesDB = ref.watch(appwriteTablesDBProvider);
  try {
    final doc = await tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupsCollection,
      rowId: groupId,
    );
    return Group.fromMap(doc.dataWithId);
  } catch (_) {
    return null;
  }
});

final groupMembersListProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, groupId) async {
      return ref.watch(groupRepositoryProvider).getGroupMembers(groupId);
    });

class GroupDetailPage extends ConsumerWidget {
  final String groupId;
  const GroupDetailPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final profilesAsync = ref.watch(groupProfilesProvider(groupId));
    final membersAsync = ref.watch(groupMembersListProvider(groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Group Details',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: groupAsync.when(
        loading: () =>
            const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: SkeletonGroupList(itemCount: 1)),
        error: (err, _) => Center(
          child: Text(
            'Error loading group: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group name
                Text(
                  group.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Join code card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.vpn_key_outlined,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join Code',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            group.joinCode,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: group.joinCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Join Code "${group.joinCode}" copied!',
                              ),
                              backgroundColor: AppColors.textPrimary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                Text(
                  'Members',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                profilesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: SkeletonList(itemCount: 3),
                  ),
                  error: (err, _) => Text(
                    'Error loading members: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                  data: (profiles) {
                    if (profiles.isEmpty) {
                      return Text(
                        'No members in this group.',
                        style: TextStyle(color: AppColors.textSecondary),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: profiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final prof = profiles[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFF3F3F3),
                                child: Text(
                                  prof.fullName.isNotEmpty
                                      ? prof.fullName
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    prof.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (prof.userId == currentUser?.id)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        '(You)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                membersAsync.valueOrNull
                                            ?.where(
                                              (m) => m.userId == prof.userId,
                                            )
                                            .firstOrNull
                                            ?.isAdmin ==
                                        true
                                    ? 'Admin'
                                    : 'Member',
                                style: TextStyle(
                                  color:
                                      membersAsync.valueOrNull
                                              ?.where(
                                                (m) => m.userId == prof.userId,
                                              )
                                              .firstOrNull
                                              ?.isAdmin ==
                                          true
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight:
                                      membersAsync.valueOrNull
                                              ?.where(
                                                (m) => m.userId == prof.userId,
                                              )
                                              .firstOrNull
                                              ?.isAdmin ==
                                          true
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                // Group Actions
                if (currentUser != null &&
                    membersAsync.valueOrNull != null) ...[
                  Builder(
                    builder: (context) {
                      final members = membersAsync.valueOrNull!;
                      final myMember = members
                          .where((m) => m.userId == currentUser.id)
                          .firstOrNull;
                      if (myMember == null) return const SizedBox();

                      final isAdmin = myMember.isAdmin;

                      return Column(
                        children: [
                          if (isAdmin) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _handleDeleteGroup(context, ref, group),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                                label: Text(
                                  'Delete Group',
                                  style: TextStyle(color: AppColors.error),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.error),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _handleLeaveGroup(
                                context,
                                ref,
                                group,
                                members,
                                isAdmin,
                                currentUser.id,
                              ),
                              icon: Icon(
                                Icons.exit_to_app,
                                color: AppColors.error,
                                size: 18,
                              ),
                              label: Text(
                                'Leave Group',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleDeleteGroup(BuildContext context, WidgetRef ref, Group group) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to completely delete this group? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(100, 48),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(groupRepositoryProvider).deleteGroup(group.id);
                ref.invalidate(userGroupsProvider);
                if (context.mounted) context.pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleLeaveGroup(
    BuildContext context,
    WidgetRef ref,
    Group group,
    List<GroupMember> members,
    bool isAdmin,
    String myUserId,
  ) {
    if (isAdmin && members.length > 1) {
      // Need to transfer ownership
      final otherMembers = members.where((m) => m.userId != myUserId).toList();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Transfer Ownership'),
          content: const Text(
            'As the admin, you must transfer ownership to another member before leaving.',
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
                    onPressed: () async {
                      Navigator.pop(context);
                      _showTransferDialog(
                        context,
                        ref,
                        group,
                        otherMembers,
                        myUserId,
                      );
                    },
                    child: const Text('Select Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      return;
    }

    // Normal leave or last member leaving (which deletes group)
    final isLastMember = members.length == 1;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text(
          isLastMember
              ? 'You are the last member. Leaving will delete the group. Continue?'
              : 'Are you sure you want to leave this group?',
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
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.surface,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      if (isLastMember) {
                        await ref.read(groupRepositoryProvider).deleteGroup(group.id);
                      } else {
                        await ref
                            .read(groupRepositoryProvider)
                            .leaveGroup(group.id, myUserId);
                      }
                      ref.invalidate(userGroupsProvider);
                      if (context.mounted) context.pop();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text('Leave', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(
    BuildContext context,
    WidgetRef ref,
    Group group,
    List<GroupMember> otherMembers,
    String myUserId,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select New Admin'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: otherMembers.length,
            itemBuilder: (context, index) {
              final member = otherMembers[index];
              return ListTile(
                title: Text(
                  'User ID: ${member.userId.substring(0, 5)}...',
                ), // Profile data not directly available here, so using ID as fallback
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: Size.zero),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final repo = ref.read(groupRepositoryProvider);
                      await repo.transferOwnership(group.id, member.userId);
                      await repo.leaveGroup(group.id, myUserId);
                      ref.invalidate(userGroupsProvider);
                      if (context.mounted) context.pop();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text('Make Admin & Leave'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
