import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_player_service.dart';
import '../services/extension_engine.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/omni_logo.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';

class OmniSplashScreen extends StatefulWidget {
  final ExtensionEngine extensionEngine;
  final AudioPlayerService audioPlayerService;
  final bool showOnboarding;

  const OmniSplashScreen({
    super.key,
    required this.extensionEngine,
    required this.audioPlayerService,
    required this.showOnboarding,
  });

  @override
  State<OmniSplashScreen> createState() => _OmniSplashScreenState();
}

class _OmniSplashScreenState extends State<OmniSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutCubic),
    );

    // Fast warm-up and snappy transition to home (750ms)
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (context, anim, secAnim) => widget.showOnboarding
                ? OnboardingScreen(
                    playerService: widget.audioPlayerService,
                    extensionEngine: widget.extensionEngine,
                  )
                : HomeShell(
                    playerService: widget.audioPlayerService,
                    extensionEngine: widget.extensionEngine,
                  ),
            transitionsBuilder: (context, anim, secAnim, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1.0).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF06090F),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Central Logo and Branding
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing Vector Logo
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: OmniLogo(
                      size: 115,
                      theme: theme,
                      isAnimated: false,
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Title
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'OMNI ',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: 'MUSIC',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        color: theme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Infinite Sound Engine • Lossless Hi-Fi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),

              const SizedBox(height: 36),

              // Animated Soundwave Equalizer Bars
              AnimatedBuilder(
                animation: _waveCtrl,
                builder: (context, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(7, (index) {
                      final phase = (index * 0.4) + (_waveCtrl.value * 2 * math.pi);
                      final height = 8.0 + 22.0 * math.sin(phase).abs();
                      final color = index.isEven ? theme.primary : const Color(0xFF00FFC6);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: 3.5,
                        height: height,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ),

          // Bottom Version & Metaphor Badge
          Positioned(
            bottom: 30,
            child: Text(
              'v2.4.0 • Infinite Sound Engine',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
