import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// OMNI BRAND LOGO
/// Metaphor: The Interlocking Infinity Loop (∞) fused with Harmonic Soundwaves
/// and an Acoustic Play Apex — representing limitless, lossless music anywhere.
/// ─────────────────────────────────────────────────────────────────────────────
class OmniLogo extends StatefulWidget {
  final double size;
  final AppTheme? theme;
  final bool showText;
  final bool isAnimated;

  const OmniLogo({
    super.key,
    this.size = 36,
    this.theme,
    this.showText = false,
    this.isAnimated = false,
  });

  @override
  State<OmniLogo> createState() => _OmniLogoState();
}

class _OmniLogoState extends State<OmniLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    if (widget.isAnimated) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme?.primary ?? const Color(0xFFF43F5E);
    final secondary = widget.theme?.primaryGlow ?? const Color(0xFF8B5CF6);

    Widget iconWidget = CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _OmniLogoPainter(
        primaryColor: primary,
        secondaryColor: secondary,
      ),
    );

    if (widget.isAnimated) {
      iconWidget = ScaleTransition(
        scale: _pulseAnimation,
        child: iconWidget,
      );
    }

    if (!widget.showText) {
      return iconWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'OMNI ',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: widget.size * 0.44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: 'MUSIC',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: widget.size * 0.44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'INFINITE HI-FI SOUND',
              style: TextStyle(
                fontSize: widget.size * 0.19,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OmniLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  _OmniLogoPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Soft Ambient Glow under the logo
    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.22);
    canvas.drawCircle(center, w * 0.38, glowPaint);

    // 2. Outer Infinity Wave Ring (Smooth figure-8 harmonic path)
    final infinityPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.088
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: [
          primaryColor,
          secondaryColor,
          const Color(0xFF38BDF8),
          primaryColor,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path = Path();
    final r = w * 0.23;
    final d = w * 0.19;

    // Left Loop of Infinity
    path.moveTo(center.dx, center.dy);
    path.cubicTo(
      center.dx - d * 0.6, center.dy - r * 1.25,
      center.dx - d * 2.1, center.dy - r * 1.1,
      center.dx - d * 2.1, center.dy,
    );
    path.cubicTo(
      center.dx - d * 2.1, center.dy + r * 1.1,
      center.dx - d * 0.6, center.dy + r * 1.25,
      center.dx, center.dy,
    );

    // Right Loop of Infinity
    path.cubicTo(
      center.dx + d * 0.6, center.dy - r * 1.25,
      center.dx + d * 2.1, center.dy - r * 1.1,
      center.dx + d * 2.1, center.dy,
    );
    path.cubicTo(
      center.dx + d * 2.1, center.dy + r * 1.1,
      center.dx + d * 0.6, center.dy + r * 1.25,
      center.dx, center.dy,
    );

    canvas.drawPath(path, infinityPaint);

    // 3. Central Glowing Acoustic Play Core
    final playPath = Path();
    final playSize = w * 0.16;
    final playOffset = center + Offset(w * 0.02, 0);

    playPath.moveTo(
      playOffset.dx - playSize * 0.6,
      playOffset.dy - playSize * 0.85,
    );
    playPath.lineTo(
      playOffset.dx + playSize * 0.85,
      playOffset.dy,
    );
    playPath.lineTo(
      playOffset.dx - playSize * 0.6,
      playOffset.dy + playSize * 0.85,
    );
    playPath.close();

    final playPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white,
          primaryColor,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(center.dx - playSize, center.dy - playSize, playSize * 2, playSize * 2))
      ..style = PaintingStyle.fill;

    // Soft drop shadow for the play glyph
    canvas.drawShadow(playPath, primaryColor, 4.0, true);
    canvas.drawPath(playPath, playPaint);

    // 4. Harmonic Pulse Dots
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx - d * 2.0, center.dy), w * 0.035, dotPaint);
    canvas.drawCircle(Offset(center.dx + d * 2.0, center.dy), w * 0.035, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _OmniLogoPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
