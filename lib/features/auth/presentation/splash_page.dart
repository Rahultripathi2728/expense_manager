import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/split_pro_logo.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;

  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Main staggered entrance controller
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Pulse glow controller (looping)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Icon: Scale from 0.3 → 1.0 with spring bounce (0% → 50%)
    _iconScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    // Icon: Fade in (0% → 30%)
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    // Title: Fade + slide (40% → 70%)
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.40, 0.70, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.40, 0.70, curve: Curves.easeOutCubic),
          ),
        );

    // Subtitle: Fade + slide (60% → 90%)
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.60, 0.90, curve: Curves.easeOut),
      ),
    );
    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.60, 0.90, curve: Curves.easeOutCubic),
          ),
        );

    // Pulse: continuous gentle floating & breathing glow
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_mainController, _pulseController]),
          builder: (context, _) {
            // Subtle floating offset for continuous organic motion
            final floatOffset = (1.0 - _pulseAnimation.value) * 8.0;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Floating & Pulsing ambient glow with new Wallet logo
                Transform.translate(
                  offset: Offset(0, -floatOffset),
                  child: Transform.scale(
                    scale: _iconScale.value,
                    child: Opacity(
                      opacity: _iconFade.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                alpha: 0.35 * _pulseAnimation.value,
                              ),
                              blurRadius: 36 + (14 * _pulseAnimation.value),
                              spreadRadius: 4 * _pulseAnimation.value,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(
                                alpha: 0.20 * _pulseAnimation.value,
                              ),
                              blurRadius: 24,
                              spreadRadius: 2 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                        child: const SplitProLogo(size: 116),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Title
                FadeTransition(
                  opacity: _titleFade,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: Text(
                      'Split Pro',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Subtitle
                FadeTransition(
                  opacity: _subtitleFade,
                  child: SlideTransition(
                    position: _subtitleSlide,
                    child: Text(
                      'Split bills • Track expenses • Settle easily',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
