import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/features/auth/presentation/sign_in_page.dart';
import 'package:expense_manager/features/auth/data/auth_repository.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:appwrite/appwrite.dart';

// Create a Fake AuthRepository
class FakeAuthRepository implements AuthRepository {
  @override
  Future<UserModel> signIn({required String email, required String password}) async {
    throw AppwriteException('user_invalid_credentials', 401, 'Invalid credentials');
  }

  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {}

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> resetPassword({required String userId, required String secret, required String password}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<UserModel> signUp({required String name, required String email, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> updateName(String newName) async {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('SignInPage shows formatted error message on invalid credentials', (tester) async {
    final mockRepo = FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SignInPage()),
        ),
      ),
    );

    // Wait for animations
    await tester.pumpAndSettle();

    // Find the text fields
    final emailField = find.byType(TextFormField).first;
    final passwordField = find.byType(TextFormField).last;

    // Enter text
    await tester.enterText(emailField, 'test@example.com');
    await tester.enterText(passwordField, 'wrongpassword');
    await tester.pumpAndSettle();

    // Tap the Sign In button
    final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    // Ensure the ErrorFormatter formatted the message properly
    expect(find.text('Invalid credentials. Please check your email and password.'), findsOneWidget);
  });
}
