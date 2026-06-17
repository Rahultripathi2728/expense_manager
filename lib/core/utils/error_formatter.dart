import 'dart:io';
import 'package:appwrite/appwrite.dart';

class ErrorFormatter {
  static String format(dynamic error) {
    if (error is AppwriteException) {
      if (error.code == 401) {
        return 'Invalid credentials. Please check your email and password.';
      }
      if (error.code == 409) {
        return 'An account with this email already exists.';
      }
      if (error.code == 400) {
        return 'Invalid request. Please check the information provided.';
      }
      if (error.code == 404) {
        return 'Resource not found. It may have been deleted.';
      }
      if (error.message != null && error.message!.isNotEmpty) {
        // Appwrite often returns "user_invalid_credentials, ..."
        // We can strip out the code prefix if present, or just return the message.
        final msg = error.message!;
        if (msg.contains(',')) {
          return msg.split(',').last.trim().replaceAll(RegExp(r'\s*\(\d+\)$'), '');
        }
        return msg;
      }
      return 'A server error occurred. Please try again later.';
    } else if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    } else if (error is Exception) {
      final msg = error.toString();
      if (msg.startsWith('Exception: ')) {
        return msg.substring(11);
      }
      return msg;
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
