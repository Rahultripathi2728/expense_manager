import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import 'split_pro_logo_bytes.dart';

/// Pre-decoded logo memory bytes for instant 0ms rendering across Web, Mobile & Desktop.
/// Eliminates Flutter Web asset bundle caching delays or AssetManifest sync issues.
final Uint8List _cachedLogoBytes = base64Decode(kSplitProLogoBase64);

/// Official branded logo widget for Split Pro.
/// Renders the official tall luxury wallet & expense tracker app icon.
class SplitProLogo extends StatelessWidget {
  final double size;
  
  const SplitProLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.24);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          _cachedLogoBytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.gradientStart,
                    AppColors.gradientEnd,
                  ],
                ),
                borderRadius: radius,
              ),
              child: Center(
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
