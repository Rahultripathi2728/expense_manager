import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:sqflite/sqflite.dart';

/// Centralized utility for formatting raw errors/exceptions into user-friendly messages.
class ErrorFormatter {
  ErrorFormatter._();

  /// Converts any given exception [e] to a user-friendly string.
  static String format(dynamic e) {
    if (e == null) return 'An unknown error occurred';

    if (e is AppwriteException) {
      if (e.code == 401) return 'Session expired. Please sign in again.';
      if (e.code == 404) return 'The requested resource could not be found.';
      if (e.code == 409) return 'This record already exists.';
      if (e.message != null && e.message!.isNotEmpty) {
        // Expose appwrite message but strip out severe tech jargon if needed
        return e.message!;
      }
      return 'Network error occurred. Please check your connection.';
    }

    if (e is DatabaseException) {
      final msg = e.toString().toLowerCase();
      // Look for the specific bug the user faced (NOT NULL constraint)
      if (msg.contains('not null constraint failed') || msg.contains('notnull')) {
        return 'Could not complete the action. The data is incomplete or corrupted.';
      }
      if (msg.contains('unique constraint failed')) {
        return 'This record already exists locally.';
      }
      return 'Local database error occurred. Please try again.';
    }

    if (e is SocketException) {
      return 'No internet connection. Please check your network.';
    }

    if (e is FormatException) {
      return 'Invalid data format encountered.';
    }

    // Default fallback
    final rawError = e.toString();
    if (rawError.contains('connection refused') || rawError.contains('XMLHttpRequest error')) {
      return 'Unable to reach the server. Please check your internet connection.';
    }

    // If it's a simple string exception
    if (rawError.length < 50 && !rawError.contains('Exception:')) {
      return rawError;
    }

    return 'Something went wrong. Please try again later.';
  }
}
