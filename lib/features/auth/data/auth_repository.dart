import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/services/push_notification_service.dart';
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

  /// Send a Magic Link or 6-digit Email OTP for Passwordless Login.
  Future<String> sendMagicLink({required String email}) async {
    String magicUrl = 'https://expense-manager.app/magic-login';
    if (kIsWeb) {
      magicUrl = '${Uri.base.origin}/magic-login';
    }

    try {
      // 1. Send 6-digit OTP code to user's email via createEmailToken
      final token = await _account.createEmailToken(
        userId: ID.unique(),
        email: email,
      );

      // 2. Also attempt magic URL token in parallel if supported
      try {
        await _account.createMagicURLToken(
          userId: token.userId,
          email: email,
          url: magicUrl,
        );
      } catch (_) {}

      return token.userId;
    } catch (_) {
      // Fallback to createMagicURLToken
      final token = await _account.createMagicURLToken(
        userId: ID.unique(),
        email: email,
        url: magicUrl,
      );
      return token.userId;
    }
  }

  /// Verify a Magic Link or Email OTP and login.
  Future<UserModel> verifyMagicLink({
    required String userId,
    required String secret,
  }) async {
    await _account.createSession(userId: userId, secret: secret);
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
    required String username,
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
        'username': username,
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

  /// Create Appwrite user account and dispatch 6-digit OTP code to email.
  Future<String> signUpCreate({
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
    await _account.createEmailToken(
      userId: user.$id,
      email: email,
    );
    return user.$id;
  }

  /// Confirm the OTP code, log the user in, and create their profile.
  Future<UserModel> signUpVerify({
    required String userId,
    required String email,
    required String name,
    required String username,
    required String otpCode,
  }) async {
    await _account.createSession(
      userId: userId,
      secret: otpCode,
    );

    await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesCollection,
      rowId: ID.unique(),
      data: {
        'userId': userId,
        'fullName': name,
        'username': username,
        'avatarUrl': null,
        'monthlyBudget': 0.0,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );

    try {
      await _account.createEmailVerification(
        url: 'https://expense-manager.app/verify',
      );
    } catch (_) {}

    final user = await _account.get();
    final userModel = UserModel.fromAppwrite(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(userModel.toJson()));
    return userModel;
  }

  /// Resend verification OTP code.
  Future<void> resendOtp({
    required String userId,
    required String email,
  }) async {
    await _account.createEmailToken(
      userId: userId,
      email: email,
    );
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

  /// Verifies current password against active session.
  Future<bool> verifyCurrentPassword(String currentPassword) async {
    try {
      await _account.updatePassword(
        password: currentPassword,
        oldPassword: currentPassword,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sends a 6-digit OTP code to [newEmail] to verify ownership before email change.
  Future<String> sendEmailChangeOtp({required String newEmail}) async {
    final token = await _account.createEmailToken(
      userId: ID.unique(),
      email: newEmail,
    );
    return token.userId;
  }

  /// Completes email change after verifying 6-digit OTP and current password.
  Future<UserModel> completeEmailChange({
    required String newEmail,
    required String currentPassword,
    required String tempUserId,
    required String otpCode,
  }) async {
    try {
      await _account.createSession(
        userId: tempUserId,
        secret: otpCode,
      );
    } catch (_) {}

    final user = await _account.updateEmail(
      email: newEmail,
      password: currentPassword,
    );
    final userModel = UserModel.fromAppwrite(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(userModel.toJson()));
    return userModel;
  }

  /// Send 6-digit OTP code to user email for password reset.
  Future<String> sendPasswordResetOtp(String email) async {
    final token = await _account.createEmailToken(
      userId: ID.unique(),
      email: email,
    );
    return token.userId;
  }

  /// Reset password using 6-digit OTP code.
  Future<void> resetPasswordWithOtp({
    required String userId,
    required String otpCode,
    required String newPassword,
  }) async {
    await _account.createSession(
      userId: userId,
      secret: otpCode,
    );
    await _account.updatePassword(password: newPassword);
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
      return AuthStateNotifier(ref.watch(authRepositoryProvider), ref);
    });

class AuthStateNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthStateNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
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
      rethrow;
    }
  }

  Future<String> sendMagicLink({required String email}) async {
    return await _repo.sendMagicLink(email: email);
  }

  Future<bool> verifyCurrentPassword(String currentPassword) async {
    return await _repo.verifyCurrentPassword(currentPassword);
  }

  Future<String> sendEmailChangeOtp({required String newEmail}) async {
    return await _repo.sendEmailChangeOtp(newEmail: newEmail);
  }

  Future<void> completeEmailChange({
    required String newEmail,
    required String currentPassword,
    required String tempUserId,
    required String otpCode,
  }) async {
    final user = await _repo.completeEmailChange(
      newEmail: newEmail,
      currentPassword: currentPassword,
      tempUserId: tempUserId,
      otpCode: otpCode,
    );
    state = AsyncValue.data(user);
  }

  Future<String> sendPasswordResetOtp(String email) async {
    return await _repo.sendPasswordResetOtp(email);
  }

  Future<void> resetPasswordWithOtp({
    required String userId,
    required String otpCode,
    required String newPassword,
  }) async {
    await _repo.resetPasswordWithOtp(
      userId: userId,
      otpCode: otpCode,
      newPassword: newPassword,
    );
  }

  Future<void> verifyMagicLink({
    required String userId,
    required String secret,
  }) async {
    try {
      final user = await _repo.verifyMagicLink(userId: userId, secret: secret);
      state = AsyncValue.data(user);
    } catch (e) {
      rethrow;
    }
  }


  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final user = await _repo.signUp(
        name: name,
        username: username,
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

  Future<String> signUpCreate({
    required String name,
    required String email,
    required String password,
  }) async {
    return await _repo.signUpCreate(
      name: name,
      email: email,
      password: password,
    );
  }

  Future<void> signUpVerify({
    required String userId,
    required String email,
    required String name,
    required String username,
    required String otpCode,
  }) async {
    try {
      final user = await _repo.signUpVerify(
        userId: userId,
        email: email,
        name: name,
        username: username,
        otpCode: otpCode,
      );
      state = AsyncValue.data(user);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resendOtp({
    required String userId,
    required String email,
  }) async {
    await _repo.resendOtp(userId: userId, email: email);
  }

  Future<void> signOut() async {
    try {
      // Unregister the device push target BEFORE deleting the active session
      await _ref.read(pushNotificationServiceProvider).unregisterDeviceToken();
    } catch (e) {
      debugPrint('Failed to unregister push token during logout: $e');
    }
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
