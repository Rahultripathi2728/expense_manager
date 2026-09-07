import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

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

enum UpdateStatus { idle, checking, available, downloading, readyToInstall, error }

class UpdateDownloadState {
  final UpdateStatus status;
  final UpdateInfo? updateInfo;
  final double progress; // 0.0 to 100.0
  final String? statusMessage;
  final String? downloadedApkPath;
  final String? errorMessage;

  const UpdateDownloadState({
    this.status = UpdateStatus.idle,
    this.updateInfo,
    this.progress = 0.0,
    this.statusMessage,
    this.downloadedApkPath,
    this.errorMessage,
  });

  UpdateDownloadState copyWith({
    UpdateStatus? status,
    UpdateInfo? updateInfo,
    double? progress,
    String? statusMessage,
    String? downloadedApkPath,
    String? errorMessage,
  }) {
    return UpdateDownloadState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      downloadedApkPath: downloadedApkPath ?? this.downloadedApkPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UpdateDownloadNotifier extends StateNotifier<UpdateDownloadState> {
  final UpdateService _service;

  UpdateDownloadNotifier(this._service) : super(const UpdateDownloadState());

  Future<void> checkForUpdates() async {
    state = state.copyWith(status: UpdateStatus.checking, statusMessage: 'Checking for updates...');
    try {
      final info = await _service.checkForUpdates();
      if (info.updateAvailable) {
        // Also check if already cached
        if (info.apkUrl != null) {
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/expense_manager_update_${info.latestVersion}.apk';
          final file = File(filePath);
          if (await file.exists() && (await file.length()) > 15 * 1024 * 1024) {
            state = state.copyWith(
              status: UpdateStatus.readyToInstall,
              updateInfo: info,
              downloadedApkPath: filePath,
              progress: 100.0,
              statusMessage: 'v${info.latestVersion} ready to install',
            );
            return;
          }
        }
        state = state.copyWith(
          status: UpdateStatus.available,
          updateInfo: info,
          statusMessage: 'Update v${info.latestVersion} available',
        );
      } else {
        state = state.copyWith(
          status: UpdateStatus.idle,
          statusMessage: 'App is up to date',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Check failed: $e',
      );
    }
  }

  Future<void> startDownload(UpdateInfo info) async {
    if (info.apkUrl == null) return;

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/expense_manager_update_${info.latestVersion}.apk';
    final file = File(filePath);

    // Fast check: already downloaded?
    if (await file.exists() && (await file.length()) > 15 * 1024 * 1024) {
      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        updateInfo: info,
        downloadedApkPath: filePath,
        progress: 100.0,
        statusMessage: 'v${info.latestVersion} ready to install',
      );
      installApk();
      return;
    }

    state = state.copyWith(
      status: UpdateStatus.downloading,
      updateInfo: info,
      progress: 0.0,
      statusMessage: 'Starting download...',
      errorMessage: null,
    );

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(info.apkUrl!));
      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 302) {
        throw Exception('Download failed (${response.statusCode})');
      }

      final contentLength = response.contentLength ?? 0;
      var receivedBytes = 0;
      final sink = file.openWrite();

      await for (var chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0) {
          final p = (receivedBytes / contentLength) * 100;
          state = state.copyWith(
            progress: p,
            statusMessage: 'Downloading v${info.latestVersion}... ${p.toStringAsFixed(0)}%',
          );
        }
      }

      await sink.flush();
      await sink.close();

      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        progress: 100.0,
        downloadedApkPath: filePath,
        statusMessage: 'Update v${info.latestVersion} ready to install',
      );

      // Automatically launch package installer
      installApk();
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Download failed: $e',
      );
    }
  }

  Future<void> installApk() async {
    final path = state.downloadedApkPath;
    if (path != null && await File(path).exists()) {
      await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
    }
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

final updateDownloadProvider =
    StateNotifierProvider<UpdateDownloadNotifier, UpdateDownloadState>((ref) {
  return UpdateDownloadNotifier(ref.watch(updateServiceProvider));
});
