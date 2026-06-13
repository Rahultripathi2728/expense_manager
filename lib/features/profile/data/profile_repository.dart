import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/utils/row_helpers.dart';
import '../domain/profile_model.dart';
import '../../auth/data/auth_repository.dart';

class ProfileRepository {
  final TablesDB _tablesDB;

  ProfileRepository(this._tablesDB);

  Future<Profile?> getProfile(String userId) async {
    try {
      final res = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesCollection,
        queries: [Query.equal('userId', userId)],
      );
      if (res.rows.isEmpty) return null;
      return Profile.fromMap(res.rows.first.dataWithId);
    } catch (e) {
      return null;
    }
  }

  Future<Profile> updateProfile(Profile profile) async {
    final res = await _tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesCollection,
      rowId: profile.id,
      data: profile.toMap(),
    );
    return Profile.fromMap(res.dataWithId);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(appwriteTablesDBProvider));
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final profileRepo = ref.watch(profileRepositoryProvider);
  var profile = await profileRepo.getProfile(user.id);

  if (profile == null) {
    final tablesDB = ref.watch(appwriteTablesDBProvider);
    try {
      await tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesCollection,
        rowId: ID.unique(),
        data: {
          'userId': user.id,
          'fullName': user.name,
          'avatarUrl': null,
          'monthlyBudget': 0.0,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      profile = await profileRepo.getProfile(user.id);
    } catch (_) {}
  } else {
    // Keep profile fullName in sync with Auth user name if it was updated outside
    if (user.name.isNotEmpty && profile.fullName != user.name) {
      try {
        final updated = profile.copyWith(fullName: user.name);
        await profileRepo.updateProfile(updated);
        profile = updated;
      } catch (_) {}
    }
  }

  return profile;
});
