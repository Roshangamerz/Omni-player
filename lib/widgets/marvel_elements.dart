import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track.dart';
import '../theme/animated_touch.dart';

/// Interactive Pulsing Arc Reactor Widget (Tony Stark's Core)
class ArcReactorWidget extends StatefulWidget {
  final double size;
  final bool isInteractive;
  final VoidCallback? onTap;

  const ArcReactorWidget({
    super.key,
    this.size = 100,
    this.isInteractive = true,
    this.onTap,
  });

  @override
  State<ArcReactorWidget> createState() => _ArcReactorWidgetState();
}

class _ArcReactorWidgetState extends State<ArcReactorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  void _triggerJarvisVoice(BuildContext context) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.95),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.psychology_rounded, color: Color(0xFF38BDF8), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('JARVIS PROTOCOL', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  SizedBox(height: 2),
                  Text('Arc Reactor at 400% capacity. Audio output optimized, Sir.', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedTouch(
      onTap: widget.onTap ?? () => _triggerJarvisVoice(context),
      scaleDown: 0.94,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _rotateCtrl,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer Cyan Glow Aura
                Container(
                  width: widget.size * 0.95,
                  height: widget.size * 0.95,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                        blurRadius: widget.size * 0.35,
                        spreadRadius: widget.size * 0.08,
                      ),
                    ],
                  ),
                ),

                // Rotating Stark Tech Ring 1 (Clockwise)
                Transform.rotate(
                  angle: _rotateCtrl.value * 2 * math.pi,
                  child: Container(
                    width: widget.size * 0.90,
                    height: widget.size * 0.90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: List.generate(8, (i) {
                        final angle = (i * math.pi / 4);
                        return Transform.rotate(
                          angle: angle,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              width: 3,
                              height: widget.size * 0.12,
                              color: const Color(0xFFFFB703),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                // Rotating Ring 2 (Counter-Clockwise)
                Transform.rotate(
                  angle: -_rotateCtrl.value * 2 * math.pi * 1.5,
                  child: Container(
                    width: widget.size * 0.65,
                    height: widget.size * 0.65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFB703).withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                // Inner Glowing Core (Cyan / White Palladium Core)
                Container(
                  width: widget.size * 0.40,
                  height: widget.size * 0.40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white,
                        Color(0xFFE0F2FE),
                        Color(0xFF38BDF8),
                        Color(0xFF0284C7),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: widget.size * 0.18,
                      height: widget.size * 0.18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
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

/// 6 Glowing Infinity Stones Selector & Snap Easter Egg Bar
class InfinityStonesBar extends StatelessWidget {
  final ValueChanged<String>? onStoneSelected;

  const InfinityStonesBar({super.key, this.onStoneSelected});

  static const List<Map<String, dynamic>> stones = [
    {'name': 'Space', 'color': Color(0xFF3B82F6), 'glow': Color(0xFF60A5FA), 'power': 'Tesseract Audio Stream'},
    {'name': 'Mind', 'color': Color(0xFFEAB308), 'glow': Color(0xFFFDE047), 'power': 'Neural Synced Lyrics'},
    {'name': 'Reality', 'color': Color(0xFFEF4444), 'glow': Color(0xFFF87171), 'power': 'Quantum Equalizer'},
    {'name': 'Power', 'color': Color(0xFFA855F7), 'glow': Color(0xFFC084FC), 'power': '320kbps Hi-Res Boost'},
    {'name': 'Time', 'color': Color(0xFF10B981), 'glow': Color(0xFF34D399), 'power': 'Zero Latency Gapless'},
    {'name': 'Soul', 'color': Color(0xFFF97316), 'glow': Color(0xFFFB923C), 'power': 'Acoustic Soul Resonance'},
  ];

  void _triggerSnapEasterEgg(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('💎', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Text('INFINITY GAUNTLET', style: TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"I am inevitable."\n\n...And I am Iron Man. 🫰',
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.5, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'All 6 Infinity Stones channeled. All audio streams boosted to max lossless fidelity.',
              style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Whatever It Takes', style: TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Gauntlet Snap icon
          GestureDetector(
            onTap: () => _triggerSnapEasterEgg(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFACC15).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🫰', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 8),

          // 6 Stones
          ...stones.map((s) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onStoneSelected?.call(s['name']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 1),
                    backgroundColor: s['color'],
                    content: Text('${s['name']} Stone: ${s['power']}'),
                  ),
                );
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s['color'],
                  boxShadow: [
                    BoxShadow(
                      color: (s['glow'] as Color).withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// JARVIS HUD Overlay in Now Playing
class JarvisHudOverlay extends StatelessWidget {
  final Track track;
  final Duration position;
  final Duration duration;

  const JarvisHudOverlay({
    super.key,
    required this.track,
    required this.position,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'STARK IND. HUD DIAGNOSTICS',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('ARMOR 100%', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hudStat('ARC FLUX', '400%'),
              _hudStat('REPULSOR', '44.1 kHz'),
              _hudStat('BITRATE', '320 kbps'),
              _hudStat('SOURCE', track.sourcePluginId.toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hudStat(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 1),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// Marvel Hero Quotes Banner
class MarvelQuoteCard extends StatelessWidget {
  const MarvelQuoteCard({super.key});

  static const List<String> quotes = [
    '“I love you 3000.” — Tony Stark',
    '“I can do this all day.” — Captain America',
    '“Bring me Thanos!” — Thor',
    '“With great power comes great music.” — Spider-Man',
    '“Maximum Effort!” — Deadpool',
    '“Proof that Tony Stark has a heart.”',
  ];

  @override
  Widget build(BuildContext context) {
    final quote = quotes[DateTime.now().second % quotes.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F1D1D), Color(0xFF991B1B), Color(0xFFB45309)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB703).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE63946).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              quote,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
