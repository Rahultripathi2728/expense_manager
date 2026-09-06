import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      var profile = Profile.fromMap(res.rows.first.dataWithId);

      // Hydrate local cache for offline/extended fields
      try {
        final prefs = await SharedPreferences.getInstance();
        final localUpi = prefs.getString('user_upi_$userId');
        final localUsername = prefs.getString('user_username_$userId');
        final localAvatar = prefs.getString('user_avatar_$userId');

        profile = profile.copyWith(
          upiId: profile.upiId ?? localUpi,
          username: profile.username ?? localUsername,
          avatarUrl: profile.avatarUrl ?? localAvatar,
        );
      } catch (_) {}

      return profile;
    } catch (e) {
      return null;
    }
  }

  Future<List<Profile>> getProfiles(List<String> userIds) async {
    try {
      final res = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesCollection,
        queries: [Query.equal('userId', userIds)],
      );
      return res.rows.map((d) => Profile.fromMap(d.dataWithId)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Profile> updateProfile(Profile profile) async {
    // Save to SharedPreferences for instant resilience
    try {
      final prefs = await SharedPreferences.getInstance();
      if (profile.upiId != null) {
        await prefs.setString('user_upi_${profile.userId}', profile.upiId!);
      }
      if (profile.username != null) {
        await prefs.setString('user_username_${profile.userId}', profile.username!);
      }
      if (profile.avatarUrl != null) {
        await prefs.setString('user_avatar_${profile.userId}', profile.avatarUrl!);
      }
    } catch (_) {}

    final data = profile.toMap();
    if (profile.upiId != null) data['upiId'] = profile.upiId;

    try {
      final res = await _tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesCollection,
        rowId: profile.id,
        data: data,
      );
      return Profile.fromMap(res.dataWithId).copyWith(
        upiId: profile.upiId,
        username: profile.username,
        avatarUrl: profile.avatarUrl,
      );
    } catch (e) {
      // Fallback if Appwrite rejects custom columns like upiId
      final fallbackData = <String, dynamic>{
        'userId': profile.userId,
        'fullName': profile.fullName,
        'avatarUrl': profile.avatarUrl,
        'monthlyBudget': profile.monthlyBudget,
        'createdAt': profile.createdAt.toIso8601String(),
      };
      final res = await _tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesCollection,
        rowId: profile.id,
        data: fallbackData,
      );
      return Profile.fromMap(res.dataWithId).copyWith(
        upiId: profile.upiId,
        username: profile.username,
        avatarUrl: profile.avatarUrl,
      );
    }
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
