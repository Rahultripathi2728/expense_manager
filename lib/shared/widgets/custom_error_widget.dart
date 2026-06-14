import 'dart:io';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

class CustomErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String? message;

  const CustomErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.message,
  });

  String get _friendlyMessage {
    if (message != null) return message!;
    final errStr = error.toString();
    
    if (error is SocketException || errStr.contains('SocketException') || errStr.contains('Failed host lookup')) {
      return 'You appear to be offline. Please check your internet connection.';
    }
    if (error is AppwriteException) {
      final awErr = error as AppwriteException;
      if (awErr.code == 0 || awErr.type == 'general_unknown') {
         return 'Network error. Please check your connection and try again.';
      }
      return awErr.message ?? 'An unexpected server error occurred.';
    }
    
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = _friendlyMessage.contains('offline') || _friendlyMessage.contains('Network error');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _friendlyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
