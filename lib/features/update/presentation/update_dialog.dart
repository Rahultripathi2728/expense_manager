import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static void show(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  String? _errorMessage;

  Future<void> _launchBrowser() async {
    if (widget.updateInfo.releaseUrl != null) {
      final url = Uri.parse(widget.updateInfo.releaseUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _startUpdate() {
    // If not Android or apkUrl is null, fallback to browser
    if (!Platform.isAndroid || widget.updateInfo.apkUrl == null) {
      _launchBrowser();
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Starting download...';
      _errorMessage = null;
    });

    try {
      OtaUpdate()
          .execute(
        widget.updateInfo.apkUrl!,
        destinationFilename: 'app-release.apk',
      )
          .listen(
        (OtaEvent event) {
          if (!mounted) return;
          setState(() {
            switch (event.status) {
              case OtaStatus.DOWNLOADING:
                _statusMessage = 'Downloading update...';
                _downloadProgress = double.tryParse(event.value ?? '0') ?? 0.0;
                break;
              case OtaStatus.INSTALLING:
                _statusMessage = 'Installing update...';
                _downloadProgress = 100.0;
                break;
              case OtaStatus.INSTALLATION_DONE:
                _statusMessage = 'Installation done.';
                _isDownloading = false;
                break;
              case OtaStatus.ALREADY_RUNNING_ERROR:
                _errorMessage = 'An update download is already running.';
                _isDownloading = false;
                break;
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                _errorMessage = 'Permission denied to install unknown apps. Please enable it in system settings.';
                _isDownloading = false;
                break;
              case OtaStatus.DOWNLOAD_ERROR:
                _errorMessage = 'Download failed. Please check your internet connection.';
                _isDownloading = false;
                break;
              case OtaStatus.INSTALLATION_ERROR:
                _errorMessage = 'Installation failed. Please try installing the APK manually.';
                _isDownloading = false;
                break;
              case OtaStatus.CHECKSUM_ERROR:
                _errorMessage = 'Downloaded file is corrupted (Checksum error).';
                _isDownloading = false;
                break;
              case OtaStatus.CANCELED:
                _errorMessage = 'Update canceled.';
                _isDownloading = false;
                break;
              default:
                _errorMessage = 'An error occurred during update: ${event.status}';
                _isDownloading = false;
            }
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Update failed: $error';
            _isDownloading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to start update: $e';
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDownloading,
      child: AlertDialog(
        title: const Text('Update Available!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version (${widget.updateInfo.latestVersion}) of the app is available. '
              'Please update to get the latest features and bug fixes.',
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: _downloadProgress / 100),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_downloadProgress.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          if (!_isDownloading) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            if (_errorMessage != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(100, 48)),
                onPressed: _launchBrowser,
                child: const Text('Open in Browser'),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(100, 48)),
                onPressed: _startUpdate,
                child: const Text('Update Now'),
              ),
          ],
        ],
      ),
    );
  }
}
