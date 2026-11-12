import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Ultra-Sleek Futuristic Animated Loading & Splash Equalizer
class AnimatedLoadingWidget extends StatefulWidget {
  final AppTheme theme;
  final String message;
  final double size;

  const AnimatedLoadingWidget({
    super.key,
    required this.theme,
    this.message = 'Synchronizing Audio Streams...',
    this.size = 120,
  });

  @override
  State<AnimatedLoadingWidget> createState() => _AnimatedLoadingWidgetState();
}

class _AnimatedLoadingWidgetState extends State<AnimatedLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseCtrl, _rotateCtrl, _waveCtrl]),
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Pulsing Glow Aura
                    Container(
                      width: widget.size * (0.85 + 0.15 * _pulseCtrl.value),
                      height: widget.size * (0.85 + 0.15 * _pulseCtrl.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryGlow.withValues(alpha: 0.45 * _pulseCtrl.value),
                            blurRadius: widget.size * 0.4,
                            spreadRadius: widget.size * 0.05,
                          ),
                        ],
                      ),
                    ),

                    // Rotating Holographic Tech Ring
                    Transform.rotate(
                      angle: _rotateCtrl.value * 2 * math.pi,
                      child: Container(
                        width: widget.size * 0.95,
                        height: widget.size * 0.95,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: CustomPaint(
                          painter: _TechRingPainter(color: theme.primaryGlow),
                        ),
                      ),
                    ),

                    // Counter-rotating Inner Ring
                    Transform.rotate(
                      angle: -_rotateCtrl.value * 2 * math.pi * 1.5,
                      child: Container(
                        width: widget.size * 0.70,
                        height: widget.size * 0.70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.primaryGlow.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                      ),
                    ),

                    // Center Animated Equalizer Spectrum Bars (5 bars)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        final phase = (i * 0.2 + _waveCtrl.value) % 1.0;
                        final barHeight = (widget.size * 0.38) * (0.25 + 0.75 * math.sin(phase * math.pi));
                        return Container(
                          width: 3.5,
                          height: barHeight,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [theme.primary, theme.primaryGlow],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryGlow.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.message,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TechRingPainter extends CustomPainter {
  final Color color;
  _TechRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw 3 arc brackets
    for (int i = 0; i < 3; i++) {
      final startAngle = (i * 2 * math.pi / 3) + 0.2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        0.7,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
