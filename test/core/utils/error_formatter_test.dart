import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_test/flutter_test.dart' hide ErrorFormatter;
import 'package:expense_manager/core/utils/error_formatter.dart';

void main() {
  group('ErrorFormatter Tests', () {
    test('formats AppwriteException 401 properly', () {
      final error = AppwriteException('user_invalid_credentials', 401, 'Invalid credentials');
      final formatted = ErrorFormatter.format(error);
      expect(formatted, 'Invalid credentials. Please check your email and password.');
    });

    test('formats generic AppwriteException by cleaning up message', () {
      final error = AppwriteException('Some error message, This is clean (404)', 500, 'type');
      final formatted = ErrorFormatter.format(error);
      expect(formatted, 'This is clean');
    });

    test('formats SocketException properly', () {
      const error = SocketException('Failed host lookup: google.com');
      final formatted = ErrorFormatter.format(error);
      expect(formatted, 'No internet connection. Please check your network and try again.');
    });

    test('formats standard Exception', () {
      final error = Exception('Something went wrong');
      final formatted = ErrorFormatter.format(error);
      expect(formatted, 'Something went wrong');
    });
  });
}
