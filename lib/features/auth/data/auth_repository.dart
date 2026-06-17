import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../domain/user_model.dart';

/// Repository for all authentication operations.
class AuthRepository {
  final Account _account;
  final TablesDB _tablesDB;

  AuthRepository(this._account, this._tablesDB);

  /// Get current logged-in user, or null if not authenticated.
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = await _account.get();
      final userModel = UserModel.fromAppwrite(user);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user', jsonEncode(userModel.toJson()));
      return userModel;
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        // Explicitly unauthenticated / session expired
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_user');
        return null;
      }
      // Any other AppwriteException (e.g. network timeout, server error, no internet)
      return _getCachedUser();
    } catch (_) {
      // General exception (SocketException, ClientException, etc.)
      return _getCachedUser();
    }
  }

  Future<UserModel?> _getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_user');
      if (cached != null) {
        return UserModel.fromJson(jsonDecode(cached));
      }
    } catch (_) {}
    return null;
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
    } on AppwriteException catch (e) {
      // If a session is already active, we can just proceed to get the user
      if (e.message == null ||
          !e.message!.contains('prohibited when a session is active')) {
        rethrow;
      }
    }
    final user = await _account.get();
    final userModel = UserModel.fromAppwrite(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(userModel.toJson()));
    return userModel;
  }

  /// Sign up with email, password, and full name.
  /// Creates a profile document after account creation.
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = await _account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: name,
    );

    // Create session so we can create the profile
    await _account.createEmailPasswordSession(email: email, password: password);

    // Create profile document
    await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesCollection,
      rowId: ID.unique(),
      data: {
        'userId': user.$id,
        'fullName': name,
        'avatarUrl': null,
        'monthlyBudget': 0.0,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );

    // Send verification email
    try {
      await _account.createEmailVerification(
        url: 'https://expense-manager.app/verify',
      );
    } catch (_) {
      // Non-critical — user can verify later
    }

    final userModel = UserModel.fromAppwrite(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(userModel.toJson()));
    return userModel;
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } on AppwriteException catch (_) {
      // Session may already be expired or not exist — ignore
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user');
    }
  }

  /// Send password reset email.
  Future<void> forgotPassword(String email) async {
    await _account.createRecovery(
      email: email,
      url: 'https://expense-manager.app/reset-password',
    );
  }

  /// Complete password reset with userId, secret, and new password.
  Future<void> resetPassword({
    required String userId,
    required String secret,
    required String password,
  }) async {
    await _account.updateRecovery(
      userId: userId,
      secret: secret,
      password: password,
    );
  }

  /// Change password (requires re-auth with old password).
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _account.updatePassword(
      password: newPassword,
      oldPassword: oldPassword,
    );
  }

  /// Update user's name
  Future<UserModel> updateName(String newName) async {
    final user = await _account.updateName(name: newName);
    final userModel = UserModel.fromAppwrite(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(userModel.toJson()));
    return userModel;
  }
}

/// Provider for the AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(appwriteAccountProvider),
    ref.watch(appwriteTablesDBProvider),
  );
});

/// Auth state: holds the current user or null.
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<UserModel?>>((ref) {
      return AuthStateNotifier(ref.watch(authRepositoryProvider));
    });

class AuthStateNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repo;

  AuthStateNotifier(this._repo) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final user = await _repo.getCurrentUser();
      if (!state.hasValue || state.valueOrNull == null) {
        state = AsyncValue.data(user);
      }
    } catch (e, st) {
      if (!state.hasValue || state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      final user = await _repo.signIn(email: email, password: password);
      state = AsyncValue.data(user);
    } catch (e) {
      // Do not set error globally here to avoid destructive router redirects
      // the UI handles displaying the error string.
      rethrow;
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final user = await _repo.signUp(
        name: name,
        email: email,
        password: password,
      );
      state = AsyncValue.data(user);
    } catch (e) {
      // Do not set error globally here to avoid destructive router redirects
      // the UI handles displaying the error string.
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> updateName(String newName) async {
    try {
      final user = await _repo.updateName(newName);
      state = AsyncValue.data(user);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    final user = await _repo.getCurrentUser();
    state = AsyncValue.data(user);
  }
}
