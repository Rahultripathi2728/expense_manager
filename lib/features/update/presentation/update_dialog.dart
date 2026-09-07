import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/update_service.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static void show(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  Future<void> _launchBrowser() async {
    if (widget.updateInfo.releaseUrl != null) {
      final url = Uri.parse(widget.updateInfo.releaseUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(updateDownloadProvider);
    final isDownloading = downloadState.status == UpdateStatus.downloading;
    final isReady = downloadState.status == UpdateStatus.readyToInstall;
    final errorMessage = downloadState.errorMessage;

    return AlertDialog(
      title: const Text('Update Available!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A new version (${widget.updateInfo.latestVersion}) of Split Pro is available. '
            'Please update to get the latest features, security enhancements, and improvements.',
          ),
          if (isDownloading) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(value: downloadState.progress / 100),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    downloadState.statusMessage ?? 'Downloading update...',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${downloadState.progress.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          if (isReady) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Update downloaded! Ready to install.',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        if (isDownloading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Download in Background'),
          ),
        ] else if (isReady) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(updateDownloadProvider.notifier).installApk();
              Navigator.of(context).pop();
            },
            child: const Text('Install Now'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          if (!Platform.isAndroid || widget.updateInfo.apkUrl == null)
            ElevatedButton(
              onPressed: _launchBrowser,
              child: const Text('Open in Browser'),
            )
          else
            ElevatedButton(
              onPressed: () {
                ref.read(updateDownloadProvider.notifier).startDownload(widget.updateInfo);
              },
              child: const Text('Update Now'),
            ),
        ],
      ],
    );
  }
}
