import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final bool updateAvailable;
  final String? latestVersion;
  final String? releaseUrl;
  final String? apkUrl;

  UpdateInfo({
    required this.updateAvailable,
    this.latestVersion,
    this.releaseUrl,
    this.apkUrl,
  });
}

class UpdateService {
  // Using the GitHub username provided and assumed repository name
  final String owner = 'Rahultripathi2728';
  final String repo = 'expense_manager';

  Future<UpdateInfo> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String latestTag = data['tag_name'] as String; // e.g., 'v1.0.1' or '1.0.1'
        final String latestVersion = latestTag.replaceAll('v', '').trim();
        final String releaseUrl = data['html_url'] as String;

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version; // e.g., '1.0.0'

        // Basic semantic versioning comparison
        if (_isNewerVersion(currentVersion, latestVersion)) {
          String? apkUrl;
          final assets = data['assets'] as List<dynamic>?;
          if (assets != null) {
            for (final asset in assets) {
              final assetName = asset['name'] as String?;
              if (assetName != null && assetName.endsWith('.apk')) {
                apkUrl = asset['browser_download_url'] as String?;
                break;
              }
            }
          }

          return UpdateInfo(
            updateAvailable: true,
            latestVersion: latestVersion,
            releaseUrl: releaseUrl,
            apkUrl: apkUrl,
          );
        }
      }
    } catch (e) {
      // Failed to check for updates
      debugPrint('Update check failed: $e');
    }
    
    return UpdateInfo(updateAvailable: false);
  }

  bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.');
    final latestParts = latest.split('.');
    
    for (var i = 0; i < currentParts.length && i < latestParts.length; i++) {
      final currentPart = int.tryParse(currentParts[i]) ?? 0;
      final latestPart = int.tryParse(latestParts[i]) ?? 0;
      
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    return latestParts.length > currentParts.length;
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});
