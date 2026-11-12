import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../theme/animated_touch.dart';
import 'marvel_elements.dart';

// ─── 1. ADVANCED VECTOR MOTION BACKGROUND ────────────────────────────────────
class MarvelHeroMotionBackground extends StatefulWidget {
  final String heroType; // 'iron_man', 'infinity', 'cap', 'spider', 'panther'
  final Widget child;

  const MarvelHeroMotionBackground({
    super.key,
    required this.heroType,
    required this.child,
  });

  @override
  State<MarvelHeroMotionBackground> createState() => _MarvelHeroMotionBackgroundState();
}

class _MarvelHeroMotionBackgroundState extends State<MarvelHeroMotionBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _loopCtrl;

  @override
  void initState() {
    super.initState();
    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _loopCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loopCtrl,
      builder: (context, child) {
        return CustomPaint(
          painter: _HeroVectorBackgroundPainter(
            heroType: widget.heroType,
            progress: _loopCtrl.value,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _HeroVectorBackgroundPainter extends CustomPainter {
  final String heroType;
  final double progress;

  _HeroVectorBackgroundPainter({required this.heroType, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (heroType == 'spider') {
      // SPIDER-MAN: Holographic Web Grid & Neon Spider Particles
      final bgGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF881337).withValues(alpha: 0.22),
          const Color(0xFF0369A1).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = bgGradient);

      final webCenter = Offset(size.width * 0.85, size.height * 0.18);
      final webPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.08 + 0.04 * math.sin(progress * 2 * math.pi))
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Concentric Polygon Web Rings
      for (int r = 1; r <= 5; r++) {
        final radius = r * 45.0 * (0.95 + 0.05 * math.sin(progress * 2 * math.pi + r));
        final path = Path();
        for (int i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4);
          final p = Offset(webCenter.dx + radius * math.cos(angle), webCenter.dy + radius * math.sin(angle));
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, webPaint);
      }

      // Web Spoke Rays
      for (int i = 0; i < 8; i++) {
        final angle = (i * math.pi / 4);
        canvas.drawLine(
          webCenter,
          Offset(webCenter.dx + 300 * math.cos(angle), webCenter.dy + 300 * math.sin(angle)),
          webPaint,
        );
      }
    } else if (heroType == 'panther') {
      // BLACK PANTHER: Vibranium Kinetic Energy Ribbons & Chevron Weave
      final bgGradient = RadialGradient(
        center: const Alignment(0, -0.5),
        radius: 1.3,
        colors: [
          const Color(0xFF581C87).withValues(alpha: 0.35),
          const Color(0xFF2E1065).withValues(alpha: 0.20),
          Colors.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = bgGradient);

      // Kinetic Purple Shockwave Ripples
      final shockwavePaint = Paint()
        ..color = const Color(0xFFA855F7).withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final pCenter = Offset(size.width / 2, size.height * 0.22);
      for (int i = 0; i < 3; i++) {
        final waveRadius = ((progress * 200 + i * 70) % 250).toDouble();
        final alpha = (1.0 - (waveRadius / 250.0)).clamp(0.0, 1.0) * 0.18;
        canvas.drawCircle(pCenter, waveRadius, shockwavePaint..color = const Color(0xFFC084FC).withValues(alpha: alpha));
      }
    } else if (heroType == 'cap') {
      // CAPTAIN AMERICA: Concentric Titanium Shield Waves
      final bgGradient = RadialGradient(
        center: const Alignment(0, -0.4),
        radius: 1.2,
        colors: [
          const Color(0xFF1E3A8A).withValues(alpha: 0.30),
          const Color(0xFF0F172A).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = bgGradient);

      final capCenter = Offset(size.width / 2, size.height * 0.24);
      final capRingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      for (int i = 1; i <= 4; i++) {
        final r = i * 40.0 + (10 * math.sin(progress * 2 * math.pi + i));
        canvas.drawCircle(
          capCenter,
          r,
          capRingPaint..color = (i.isEven ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)).withValues(alpha: 0.08),
        );
      }
    } else if (heroType == 'infinity') {
      // INFINITY GAUNTLET: Cosmic Celestial Nebula & Orbiting Energy Dust
      final bgGradient = RadialGradient(
        center: Alignment(0.3 * math.cos(progress * 2 * math.pi), 0.3 * math.sin(progress * 2 * math.pi)),
        radius: 1.4,
        colors: [
          const Color(0xFF6B21A8).withValues(alpha: 0.32),
          const Color(0xFF1E1B4B).withValues(alpha: 0.20),
          Colors.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = bgGradient);

      final particlePaint = Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.25);
      for (int i = 0; i < 14; i++) {
        final px = (size.width * (0.1 + (i * 0.065) + math.sin(progress * 2 * math.pi + i) * 0.04)) % size.width;
        final py = (size.height * (0.15 + (i * 0.055) + math.cos(progress * 2 * math.pi + i) * 0.04)) % size.height;
        canvas.drawCircle(Offset(px, py), 1.5 + (i % 3) * 0.8, particlePaint);
      }
    } else {
      // IRON MAN: Stark HUD Diagnostics Grid & Unibeam Pulse
      final bgGradient = RadialGradient(
        center: const Alignment(0, -0.5),
        radius: 1.2,
        colors: [
          const Color(0xFF7F1D1D).withValues(alpha: 0.35),
          const Color(0xFF450A0A).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = bgGradient);

      final hudLinePaint = Paint()
        ..color = const Color(0xFFFFB703).withValues(alpha: 0.05)
        ..strokeWidth = 1.0;
      for (double y = (progress * 50) % 35; y < size.height * 0.7; y += 35) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), hudLinePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeroVectorBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.heroType != heroType;
}

// ─── 2. CUSTOM VECTOR VECTOR ART: SPIDER-MAN WEB-SLINGER ────────────────────
class VectorSpiderWebArt extends StatefulWidget {
  final double size;
  const VectorSpiderWebArt({super.key, this.size = 90});

  @override
  State<VectorSpiderWebArt> createState() => _VectorSpiderWebArtState();
}

class _VectorSpiderWebArtState extends State<VectorSpiderWebArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _webPulse;

  @override
  void initState() {
    super.initState();
    _webPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _webPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _webPulse,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _SpiderWebCanvasPainter(pulse: _webPulse.value),
        );
      },
    );
  }
}

class _SpiderWebCanvasPainter extends CustomPainter {
  final double pulse;
  _SpiderWebCanvasPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Glowing Neon Aura
    final auraPaint = Paint()
      ..color = const Color(0xFFE11D48).withValues(alpha: 0.25 + 0.15 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius * 0.85, auraPaint);

    // Dark Spider Shield Base
    final basePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF881337), Color(0xFF1E1B4B), Color(0xFF09090B)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.90, basePaint);

    // Outer Chrome Border
    final borderPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, radius * 0.90, borderPaint);

    // Geometric Web Strands
    final webLinePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int ring = 1; ring <= 3; ring++) {
      final r = (ring * radius * 0.26) * (0.94 + 0.06 * pulse);
      final path = Path();
      for (int i = 0; i < 8; i++) {
        final angle = (i * math.pi / 4);
        final pt = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, webLinePaint);
    }

    // Radial Web Spokes
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      canvas.drawLine(
        center,
        Offset(center.dx + radius * 0.85 * math.cos(angle), center.dy + radius * 0.85 * math.sin(angle)),
        webLinePaint,
      );
    }

    // Center Spider Emblem
    final spiderBodyPaint = Paint()..color = const Color(0xFFF43F5E);
    canvas.drawOval(Rect.fromCenter(center: center, width: 14, height: 18), spiderBodyPaint);
    canvas.drawCircle(Offset(center.dx, center.dy - 10), 4.5, spiderBodyPaint);
  }

  @override
  bool shouldRepaint(covariant _SpiderWebCanvasPainter oldDelegate) => oldDelegate.pulse != pulse;
}

// ─── 3. CUSTOM VECTOR ART: BLACK PANTHER VIBRANIUM CORE ─────────────────────
class VectorBlackPantherArt extends StatefulWidget {
  final double size;
  const VectorBlackPantherArt({super.key, this.size = 90});

  @override
  State<VectorBlackPantherArt> createState() => _VectorBlackPantherArtState();
}

class _VectorBlackPantherArtState extends State<VectorBlackPantherArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _kineticPulse;

  @override
  void initState() {
    super.initState();
    _kineticPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _kineticPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _kineticPulse,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _PantherCanvasPainter(pulse: _kineticPulse.value),
        );
      },
    );
  }
}

class _PantherCanvasPainter extends CustomPainter {
  final double pulse;
  _PantherCanvasPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Vibranium Purple Kinetic Glow
    final glowPaint = Paint()
      ..color = const Color(0xFFA855F7).withValues(alpha: 0.35 + 0.25 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius * 0.88, glowPaint);

    // Obsidian Armor Base
    final basePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF3B0764), Color(0xFF1E1035), Color(0xFF09060E)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.90, basePaint);

    // Tribal Vibranium Tooth Necklace Points
    final toothPaint = Paint()
      ..color = const Color(0xFFC084FC)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      final tipX = center.dx + (radius * 0.82) * math.cos(angle);
      final tipY = center.dy + (radius * 0.82) * math.sin(angle);
      final base1X = center.dx + (radius * 0.68) * math.cos(angle - 0.15);
      final base1Y = center.dy + (radius * 0.68) * math.sin(angle - 0.15);
      final base2X = center.dx + (radius * 0.68) * math.cos(angle + 0.15);
      final base2Y = center.dy + (radius * 0.68) * math.sin(angle + 0.15);

      final path = Path()
        ..moveTo(tipX, tipY)
        ..lineTo(base1X, base1Y)
        ..lineTo(base2X, base2Y)
        ..close();
      canvas.drawPath(path, toothPaint);
    }

    // Inner Glowing Violet Core
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          const Color(0xFFE9D5FF),
          const Color(0xFFA855F7),
          const Color(0xFF581C87),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.45));
    canvas.drawCircle(center, radius * (0.35 + 0.05 * pulse), corePaint);
  }

  @override
  bool shouldRepaint(covariant _PantherCanvasPainter oldDelegate) => oldDelegate.pulse != pulse;
}

// ─── 4. CUSTOM VECTOR ART: CAPTAIN AMERICA VIBRANIUM SHIELD ─────────────────
class VectorVibraniumShieldArt extends StatefulWidget {
  final double size;
  const VectorVibraniumShieldArt({super.key, this.size = 90});

  @override
  State<VectorVibraniumShieldArt> createState() => _VectorVibraniumShieldArtState();
}

class _VectorVibraniumShieldArtState extends State<VectorVibraniumShieldArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ShieldCanvasPainter(spin: _spin.value),
        );
      },
    );
  }
}

class _ShieldCanvasPainter extends CustomPainter {
  final double spin;
  _ShieldCanvasPainter({required this.spin});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer Red Ring
    canvas.drawCircle(center, radius * 0.95, Paint()..color = const Color(0xFFDC2626));
    // White/Silver Ring
    canvas.drawCircle(center, radius * 0.76, Paint()..color = const Color(0xFFE2E8F0));
    // Inner Red Ring
    canvas.drawCircle(center, radius * 0.58, Paint()..color = const Color(0xFFDC2626));
    // Blue Star Core
    canvas.drawCircle(center, radius * 0.40, Paint()..color = const Color(0xFF1D4ED8));

    // 5-Pointed Star Vector
    final starPath = Path();
    final starRadius = radius * 0.32;
    for (int i = 0; i < 5; i++) {
      final a1 = (i * 4 * math.pi / 5) - (math.pi / 2);
      final x1 = center.dx + starRadius * math.cos(a1);
      final y1 = center.dy + starRadius * math.sin(a1);
      if (i == 0) {
        starPath.moveTo(x1, y1);
      } else {
        starPath.lineTo(x1, y1);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, Paint()..color = Colors.white);

    // Looping Specular Sweep Reflection
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.15, 0.3],
        transform: GradientRotation(spin * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.95, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldCanvasPainter oldDelegate) => oldDelegate.spin != spin;
}

// ─── 5. CUSTOM VECTOR ART: 6 INFINITY STONES COSMIC ORB ─────────────────────
class VectorInfinityGauntletArt extends StatefulWidget {
  final double size;
  const VectorInfinityGauntletArt({super.key, this.size = 90});

  @override
  State<VectorInfinityGauntletArt> createState() => _VectorInfinityGauntletArtState();
}

class _VectorInfinityGauntletArtState extends State<VectorInfinityGauntletArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbitCtrl;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _orbitCtrl,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _GauntletCanvasPainter(progress: _orbitCtrl.value),
        );
      },
    );
  }
}

class _GauntletCanvasPainter extends CustomPainter {
  final double progress;
  _GauntletCanvasPainter({required this.progress});

  static const List<Map<String, dynamic>> _stones = [
    {'color': Color(0xFF3B82F6), 'glow': Color(0xFF93C5FD)}, // Space
    {'color': Color(0xFFEAB308), 'glow': Color(0xFFFEF08A)}, // Mind
    {'color': Color(0xFFEF4444), 'glow': Color(0xFFFCA5A5)}, // Reality
    {'color': Color(0xFFA855F7), 'glow': Color(0xFFE9D5FF)}, // Power
    {'color': Color(0xFF10B981), 'glow': Color(0xFF6EE7B7)}, // Time
    {'color': Color(0xFFF97316), 'glow': Color(0xFFFDBA74)}, // Soul
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Cosmic Center
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFDE047), Color(0xFFE11D48), Color(0xFF1E1B4B)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.45));
    canvas.drawCircle(center, radius * 0.35, corePaint);

    // Orbiting 6 Polished Stones
    for (int i = 0; i < _stones.length; i++) {
      final baseAngle = (i * 2 * math.pi / _stones.length) + (progress * 2 * math.pi);
      final sx = center.dx + (radius * 0.72) * math.cos(baseAngle);
      final sy = center.dy + (radius * 0.45) * math.sin(baseAngle);
      final s = _stones[i];

      // Stone Glow
      canvas.drawCircle(
        Offset(sx, sy),
        9,
        Paint()
          ..color = (s['glow'] as Color).withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Stone Core
      canvas.drawCircle(Offset(sx, sy), 6.5, Paint()..color = s['color']);
    }
  }

  @override
  bool shouldRepaint(covariant _GauntletCanvasPainter oldDelegate) => oldDelegate.progress != progress;
}

// ─── 6. INTERACTIVE MARVEL HERO SHOWCASE & FUNCTIONAL POWERS ─────────────────
class MarvelStickerShowcase extends StatefulWidget {
  final AudioPlayerService playerService;
  final ValueChanged<String>? onHeroChanged;

  const MarvelStickerShowcase({
    super.key,
    required this.playerService,
    this.onHeroChanged,
  });

  @override
  State<MarvelStickerShowcase> createState() => _MarvelStickerShowcaseState();
}

class _MarvelStickerShowcaseState extends State<MarvelStickerShowcase> {
  late int _activeHeroIndex;

  @override
  void initState() {
    super.initState();
    final cur = widget.playerService.marvelHero;
    final idx = _heroes.indexWhere((h) => h['id'] == cur);
    _activeHeroIndex = idx >= 0 ? idx : 0;
  }

  static const List<Map<String, dynamic>> _heroes = [
    {
      'id': 'spider',
      'title': 'Spider Scarlet Web (Stark Suit)',
      'hero': 'Spider-Man',
      'tag': 'PETER TINGLE ON 🕷️',
      'quote': '“With great power comes great beats.”',
      'power': 'Web-Sling (Skip to Next Track)',
      'color': Color(0xFFFF2A4D),
      'accent': Color(0xFF00D4FF),
      'tracks': [
        {'title': "What's Up Danger (Quantum 808)", 'artist': 'Miles Morales • Spider-Verse', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race1.ogg'},
        {'title': 'Queens Midnight Web Hop', 'artist': 'Spider-Byte Lo-Fi', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race2.ogg'},
      ],
    },
    {
      'id': 'iron_man',
      'title': 'Stark Arc Reactor (MK-85)',
      'hero': 'Iron Man',
      'tag': '400% CAPACITY ⚡',
      'quote': '“I love you 3000.” — Tony Stark',
      'power': 'Unibeam Boost (Lossless HQ)',
      'color': Color(0xFFFF1E42),
      'accent': Color(0xFFFFD700),
      'tracks': [
        {'title': 'Stark Unibeam Overdrive', 'artist': 'Tony Stark • AC/DC Energy', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race1.ogg'},
        {'title': 'Driving With The Top Down', 'artist': 'Stark Industries Records', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race2.ogg'},
      ],
    },
    {
      'id': 'deadpool',
      'title': 'Deadpool Merc Tactical Core',
      'hero': 'Deadpool',
      'tag': 'MAXIMUM EFFORT ⚔️',
      'quote': '“Maximum Effort!” — Wade Wilson',
      'power': 'Chimichanga Overdrive',
      'color': Color(0xFFFF003C),
      'accent': Color(0xFFE2E8F0),
      'tracks': [
        {'title': 'Careless Whisper (Merc Cut)', 'artist': 'Wade Wilson & Cable', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race1.ogg'},
        {'title': 'X-Force Beatdown', 'artist': 'Chimichanga Band', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race2.ogg'},
      ],
    },
    {
      'id': 'panther',
      'title': 'Wakandan Kinetic Suit',
      'hero': 'Black Panther',
      'tag': 'WAKANDA FOREVER 🐾',
      'quote': '“In times of crisis, the wise build bridges.”',
      'power': 'Kinetic Shockwave (+15% Vol)',
      'color': Color(0xFFA855F7),
      'accent': Color(0xFFFACC15),
      'tracks': [
        {'title': 'Wakanda Forever (Ancestral Plane)', 'artist': 'King T\'Challa • Tribal 808s', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race1.ogg'},
        {'title': 'Kinetic Shockwave Beats', 'artist': 'Shuri Vibranium Lab', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race2.ogg'},
      ],
    },
    {
      'id': 'thor',
      'title': 'Mjolnir Stormbringer Core',
      'hero': 'Thor',
      'tag': 'GOD OF THUNDER ⚡',
      'quote': '“Bring me Thanos!” — Thor Odinson',
      'power': 'Mjolnir Bass Blast (Max EQ)',
      'color': Color(0xFF00E5FF),
      'accent': Color(0xFF38BDF8),
      'tracks': [
        {'title': 'Immigrant Song (Valhalla Mix)', 'artist': 'Asgardian Rock Orchestra', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race1.ogg'},
        {'title': 'Ragnarok Thunder Hop', 'artist': 'Bifrost 808s', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race2.ogg'},
      ],
    },
    {
      'id': 'infinity',
      'title': 'Infinity Stones Cosmic Orbit',
      'hero': 'Infinity Gauntlet',
      'tag': 'ALL 6 POWERED 💎',
      'quote': '“I am inevitable.” — Thanos',
      'power': 'Quantum Reality Shuffle',
      'color': Color(0xFFFFD700),
      'accent': Color(0xFF8B5CF6),
      'tracks': [
        {'title': 'Portals to Eternity', 'artist': 'Cosmic Marvel Orchestra', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race1.ogg'},
        {'title': 'Cosmic Resonance', 'artist': 'Titan Symphony', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race2.ogg'},
      ],
    },
    {
      'id': 'cap',
      'title': 'Vibranium Shield',
      'hero': 'Captain America',
      'tag': 'STEALTH COATING 🛡️',
      'quote': '“I can do this all day.” — Steve Rogers',
      'power': 'Assemble Queue (Smart Mix)',
      'color': Color(0xFF2563EB),
      'accent': Color(0xFFEF4444),
      'tracks': [
        {'title': 'Star-Spangled Beats', 'artist': 'First Avenger Swing', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race1.ogg'},
        {'title': 'Whatever It Takes', 'artist': 'Brooklyn Nostalgia', 'url': 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_tracks/race2.ogg'},
      ],
    },
  ];

  void _triggerHeroAbility(Map<String, dynamic> hero) {
    HapticFeedback.heavyImpact();
    final id = hero['id'];

    if (id == 'iron_man') {
      widget.playerService.toggleLossless(!widget.playerService.isLosslessEnabled);
      _showAbilityNotice('⚡ UNIBEAM BOOST', 'Lossless 320kbps & Hi-Fi acoustic filter activated!');
    } else if (id == 'panther') {
      widget.playerService.setVolume(1.0);
      _showAbilityNotice('🐾 KINETIC DISCHARGE', 'Wakandan Vibranium absorbed energy! Volume boosted to 100%!');
    } else if (id == 'spider') {
      widget.playerService.next();
      _showAbilityNotice('🕸️ WEB-SLING SKIP', 'Spider-Sense swung to the next track in playlist!');
    } else if (id == 'cap') {
      widget.playerService.toggleShuffle();
      _showAbilityNotice('🛡️ AVENGERS ASSEMBLE', 'Playlist re-ordered for peak heroic morale!');
    } else if (id == 'infinity') {
      widget.playerService.toggleShuffle();
      _showAbilityNotice('🫰 THE INFINITY SNAP', 'Quantum Reality shuffled! Perfectly balanced, as all things should be.');
    } else if (id == 'thor') {
      widget.playerService.toggleLossless(true);
      _showAbilityNotice('⚡ MJOLNIR THUNDER', 'Asgardian lightning amplified acoustic clarity to maximum!');
    } else if (id == 'deadpool') {
      widget.playerService.next();
      _showAbilityNotice('⚔️ MAXIMUM EFFORT', 'Deadpool slashed straight to the next banger!');
    }
  }

  void _showAbilityNotice(String title, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.95),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
            const SizedBox(height: 2),
            Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _playHeroTrack(Map<String, String> tData, String heroName) {
    HapticFeedback.heavyImpact();
    final track = Track(
      id: 'marvel_${tData['title']!.toLowerCase().replaceAll(' ', '_')}',
      title: tData['title']!,
      artist: tData['artist']!,
      album: '$heroName Official Soundtrack',
      duration: const Duration(minutes: 3, seconds: 45),
      artworkUrl: 'https://picsum.photos/seed/${tData['title']}/500/500',
      streamUrl: tData['url']!,
      sourcePluginId: 'marvel-exclusive',
    );
    widget.playerService.playTrack(track);
  }

  @override
  Widget build(BuildContext context) {
    final hero = _heroes[_activeHeroIndex];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (hero['color'] as Color).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (hero['accent'] as Color).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (hero['color'] as Color).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Animation & Title Row
          Row(
            children: [
              // Interactive Vector Graphic
              GestureDetector(
                onTap: () => _triggerHeroAbility(hero),
                child: Hero(
                  tag: 'marvel_vector_art',
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    child: hero['id'] == 'spider'
                        ? const VectorSpiderWebArt(size: 85)
                        : hero['id'] == 'panther'
                            ? const VectorBlackPantherArt(size: 85)
                            : hero['id'] == 'cap'
                                ? const VectorVibraniumShieldArt(size: 85)
                                : hero['id'] == 'infinity'
                                    ? const VectorInfinityGauntletArt(size: 85)
                                    : const ArcReactorWidget(size: 85),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Title, Tag & Power Button
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (hero['accent'] as Color).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: (hero['accent'] as Color).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            hero['tag'],
                            style: TextStyle(
                              color: hero['accent'],
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hero['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hero['quote'],
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Tap to Activate Power
                    AnimatedTouch(
                      onTap: () => _triggerHeroAbility(hero),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (hero['accent'] as Color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: (hero['accent'] as Color).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, color: hero['accent'], size: 12),
                            const SizedBox(width: 4),
                            Text(
                              hero['power'],
                              style: TextStyle(
                                color: hero['accent'],
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 5 Hero Switcher Chips (Iron Man, Black Panther, Spider, Cap, Infinity)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_heroes.length, (i) {
                final isSelected = _activeHeroIndex == i;
                final item = _heroes[i];
                final emojis = ['⚡ Iron Man', '🐾 Panther', '🕸️ Spider', '🛡️ Cap', '💎 Infinity'];

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _activeHeroIndex = i);
                      widget.playerService.setMarvelHero(item['id']!);
                      widget.onHeroChanged?.call(item['id']!);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (item['accent'] as Color).withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? (item['accent'] as Color) : Colors.white.withValues(alpha: 0.1),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        emojis[i],
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 10),

          // Hero Soundtrack Shelf Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🔥 ${hero['hero']} SOUNDTRACK',
                style: TextStyle(
                  color: hero['accent'],
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('STREAM READY', style: TextStyle(color: Color(0xFF34D399), fontSize: 8.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Hero Tracks (Streamable)
          ...((hero['tracks'] as List<Map<String, String>>).map((tData) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: AnimatedTouch(
                onTap: () => _playHeroTrack(tData, hero['hero'] as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (hero['accent'] as Color).withValues(alpha: 0.2),
                        ),
                        child: Icon(Icons.play_arrow_rounded, color: hero['accent'], size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tData['title']!,
                              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              tData['artist']!,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (hero['accent'] as Color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('LOSSLESS', style: TextStyle(color: hero['accent'], fontSize: 8.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })),
        ],
      ),
    );
  }
}
