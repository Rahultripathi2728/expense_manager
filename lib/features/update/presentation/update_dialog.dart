import 'dart:io' show Platform, File;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
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

  Future<void> _startUpdate() async {
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
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.updateInfo.apkUrl!));
      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 302) {
        throw Exception('Failed to download update. Server returned ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var receivedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/expense_manager_update_${widget.updateInfo.latestVersion}.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      await for (var chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _downloadProgress = (receivedBytes / contentLength) * 100;
            _statusMessage = 'Downloading update...';
          });
        }
      }
      
      await sink.flush();
      await sink.close();

      if (mounted) {
        setState(() {
          _statusMessage = 'Installing update...';
          _downloadProgress = 100.0;
        });
      }

      final result = await OpenFilex.open(filePath);
      
      if (mounted) {
        setState(() {
          _isDownloading = false;
          if (result.type != ResultType.done) {
            _errorMessage = 'Failed to open installer: ${result.message}';
          } else {
            _statusMessage = 'Installation started.';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Update failed: $e';
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
