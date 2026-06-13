import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/update_service.dart';

class UpdateDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Available!'),
      content: Text(
        'A new version (${updateInfo.latestVersion}) of the app is available. Please update to get the latest features and bug fixes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (updateInfo.releaseUrl != null) {
              final url = Uri.parse(updateInfo.releaseUrl!);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Update Now'),
        ),
      ],
    );
  }
}
