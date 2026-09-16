import 'dart:io';
import 'package:appwrite/appwrite.dart';

class ErrorFormatter {
  static String format(dynamic error) {
    if (error is AppwriteException) {
      final code = error.code;
      final type = error.type ?? '';
      final rawMessage = error.message ?? '';

      // 1. Account conflict / duplicate email
      if (code == 409 ||
          type == 'user_already_exists' ||
          type == 'user_email_already_exists' ||
          rawMessage.toLowerCase().contains('already exists')) {
        return 'An account with this email already exists. Please sign in.';
      }

      // 2. Authentication failure / invalid credentials
      if (code == 401 || type == 'user_invalid_credentials') {
        return 'Invalid credentials. Please check your email and password.';
      }

      // 3. Rate limiting / too many attempts
      if (code == 429 || type == 'general_rate_limit_exceeded') {
        return 'Too many attempts. Please wait a moment and try again.';
      }

      // 4. Token / OTP verification errors
      if (type == 'user_invalid_token' || rawMessage.toLowerCase().contains('invalid token')) {
        return 'The verification code is invalid or has expired. Please request a new one.';
      }

      // 5. Password complexity & safety errors
      if (type == 'password_recently_used' ||
          type == 'password_personal_data' ||
          type == 'password_history' ||
          rawMessage.toLowerCase().contains('commonly used password') ||
          rawMessage.toLowerCase().contains('password must not')) {
        return 'This password is too weak or commonly used. Please choose a stronger password.';
      }

      // 6. Inspect descriptive Appwrite error message
      if (rawMessage.isNotEmpty) {
        String msg = rawMessage.trim();

        // Strip prefixes like "Invalid `password` param: " or "general_argument_invalid, "
        if (msg.contains('param:')) {
          msg = msg.split('param:').last.trim();
        } else if (msg.contains(',')) {
          msg = msg.split(',').last.trim();
        }
        msg = msg.replaceAll(RegExp(r'\s*\(\d+\)$'), '').trim();

        final lower = msg.toLowerCase();
        if (lower.contains('password must be between 8 and 256')) {
          return 'Password must be at least 8 characters long.';
        }
        if (lower.contains('password')) {
          return msg;
        }
        if (lower.contains('email') && (lower.contains('valid') || lower.contains('param'))) {
          return 'Please provide a valid email address.';
        }
        if (lower.contains('attribute not found in schema') || lower.contains('index not found')) {
          return 'Database schema mismatch. Please contact support or try again.';
        }
        if (msg.isNotEmpty && !msg.startsWith('general_')) {
          return msg;
        }
      }

      // 7. Status code fallbacks
      if (code == 404) {
        return 'Resource not found. It may have been deleted.';
      }
      if (code == 400) {
        return 'Invalid request details. Please check the information you entered.';
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
