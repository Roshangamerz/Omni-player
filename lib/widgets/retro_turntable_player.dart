import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

/// Ultra-Detailed Retro-Futuristic Turntable Player
/// Features a realistic spinning vinyl record with anisotropic light reflection,
/// a tone arm that lowers onto the groove when playing,
/// a futuristic horizontal deck unit with a glowing cyan/green LED dot-matrix scrolling display,
/// debossed industrial hardware details, exposed wiring, and complete tactile audio controls.
class RetroTurntablePlayer extends StatefulWidget {
  final Track track;
  final AudioPlayerService playerService;
  final AppTheme theme;
  final VoidCallback onToggleLyrics;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenEqualizer;

  const RetroTurntablePlayer({
    super.key,
    required this.track,
    required this.playerService,
    required this.theme,
    required this.onToggleLyrics,
    required this.onOpenQueue,
    required this.onOpenEqualizer,
  });

  @override
  State<RetroTurntablePlayer> createState() => _RetroTurntablePlayerState();
}

class _RetroTurntablePlayerState extends State<RetroTurntablePlayer>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _armCtrl;
  late final AnimationController _ledBlinkCtrl;
  late final ScrollController _ledScrollCtrl;

  bool _isDraggingSlider = false;
  double _sliderDragFraction = 0.0;

  @override
  void initState() {
    super.initState();

    // Vinyl 33 RPM continuous rotation
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Tone arm movement: 0.0 = Rest position (lifted), 1.0 = Tracking on record
    _armCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // LED status light pulsing
    _ledBlinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _ledScrollCtrl = ScrollController();

    if (widget.playerService.isPlaying) {
      _spinCtrl.repeat();
      _armCtrl.forward();
    } else {
      _armCtrl.reverse();
    }

    _startLedScroll();
  }

  void _startLedScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loopLedScroll();
    });
  }

  void _loopLedScroll() async {
    while (mounted) {
      if (_ledScrollCtrl.hasClients) {
        final maxScroll = _ledScrollCtrl.position.maxScrollExtent;
        if (maxScroll > 0) {
          await _ledScrollCtrl.animateTo(
            maxScroll,
            duration: Duration(milliseconds: (maxScroll * 40).toInt().clamp(2500, 10000)),
            curve: Curves.linear,
          );
          await Future.delayed(const Duration(milliseconds: 800));
          if (_ledScrollCtrl.hasClients) {
            _ledScrollCtrl.jumpTo(0.0);
            await Future.delayed(const Duration(milliseconds: 400));
          }
        } else {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  @override
  void didUpdateWidget(covariant RetroTurntablePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerService.isPlaying) {
      if (!_spinCtrl.isAnimating) _spinCtrl.repeat();
      if (_armCtrl.value < 1.0) _armCtrl.forward();
    } else {
      if (_spinCtrl.isAnimating) _spinCtrl.stop();
      if (_armCtrl.value > 0.0) _armCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _armCtrl.dispose();
    _ledBlinkCtrl.dispose();
    _ledScrollCtrl.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ps = widget.playerService;
    final track = widget.track;
    final isPlaying = ps.isPlaying;
    final isBuffering = ps.isBuffering;
    final isLiked = ps.isTrackLiked(track.id);

    final dur = ps.duration.inMilliseconds > 0 ? ps.duration : track.duration;
    final pos = ps.position;
    final fraction = _isDraggingSlider
        ? _sliderDragFraction
        : (dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        // Calculate dynamic turntable dimension
        final turntableSize = (screenWidth * 0.90).clamp(280.0, 420.0);

        return Column(
          children: [
            const SizedBox(height: 8),

            // Top Turntable Canvas Area
            Expanded(
              flex: 11,
              child: Center(
                child: SizedBox(
                  width: turntableSize,
                  height: turntableSize,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Spinning Vinyl Record (The Disk)
                      Positioned(
                        left: (turntableSize * 0.02),
                        child: AnimatedBuilder(
                          animation: _spinCtrl,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _spinCtrl.value * 2 * math.pi,
                              child: _buildVinylDisk(turntableSize * 0.84, track),
                            );
                          },
                        ),
                      ),

                      // 2. The Futuristic Turntable Deck & LED Unit (Mounted horizontally across)
                      Positioned(
                        right: 0,
                        top: (turntableSize * 0.32),
                        child: _buildFuturisticDeckUnit(turntableSize * 0.68, track),
                      ),

                      // 3. The Animated Tone Arm
                      Positioned(
                        right: (turntableSize * 0.16),
                        top: (turntableSize * 0.44),
                        child: AnimatedBuilder(
                          animation: _armCtrl,
                          builder: (context, child) {
                            // Arm angle: 0.0 (rest position = -32 deg) to 1.0 (on record = -4 deg to +6 deg tracking song)
                            final trackingAngle = -4.0 + (fraction * 10.0);
                            final currentAngle =
                                -32.0 + ((trackingAngle - (-32.0)) * _armCtrl.value);
                            return Transform.rotate(
                              angle: currentAngle * (math.pi / 180.0),
                              alignment: Alignment.topRight,
                              child: _buildToneArm(turntableSize * 0.46),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tactile Seek Bar & Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Seek Bar Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(pos),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2B170).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          ps.activeQualityBadge,
                          style: const TextStyle(
                            color: Color(0xFFE2B170),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(dur),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: const Color(0xFFE2B170),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: Colors.white,
                      overlayColor: const Color(0xFFE2B170).withValues(alpha: 0.25),
                    ),
                    child: Slider(
                      value: fraction,
                      onChangeStart: (v) {
                        setState(() {
                          _isDraggingSlider = true;
                          _sliderDragFraction = v;
                        });
                      },
                      onChanged: (v) {
                        setState(() => _sliderDragFraction = v);
                      },
                      onChangeEnd: (v) {
                        setState(() => _isDraggingSlider = false);
                        if (dur > Duration.zero) {
                          ps.seek(Duration(milliseconds: (v * dur.inMilliseconds).round()));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Main Playback Controls Dock
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Shuffle
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: ps.isShuffle ? const Color(0xFFE2B170) : Colors.white38,
                      size: 24,
                    ),
                    onPressed: ps.cycleShuffleMode,
                  ),

                  // Previous
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 38),
                    onPressed: ps.previous,
                  ),

                  // Play / Pause glowing button
                  GestureDetector(
                    onTap: ps.togglePlayPause,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFDE68A), Color(0xFFE2B170), Color(0xFFC08430)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE2B170).withValues(alpha: isPlaying ? 0.45 : 0.2),
                            blurRadius: isPlaying ? 22 : 12,
                            spreadRadius: isPlaying ? 2 : 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: isBuffering
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                              )
                            : Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: const Color(0xFF07070A),
                                size: 42,
                              ),
                      ),
                    ),
                  ),

                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 38),
                    onPressed: ps.next,
                  ),

                  // Repeat
                  IconButton(
                    icon: Icon(
                      ps.repeatMode == PlaybackRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: ps.repeatMode != PlaybackRepeatMode.off
                          ? const Color(0xFFE2B170)
                          : Colors.white38,
                      size: 24,
                    ),
                    onPressed: ps.toggleRepeat,
                  ),
                ],
              ),
            ),

            // Bottom Actions Bar (Lyrics, Like, Equalizer, Queue)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Lyrics',
                    icon: const Icon(Icons.lyrics_rounded, color: Colors.white70, size: 22),
                    onPressed: widget.onToggleLyrics,
                  ),
                  IconButton(
                    tooltip: 'Equalizer',
                    icon: const Icon(Icons.equalizer_rounded, color: Colors.white70, size: 22),
                    onPressed: widget.onOpenEqualizer,
                  ),
                  IconButton(
                    tooltip: 'Favorite',
                    icon: Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? const Color(0xFFF43F5E) : Colors.white70,
                      size: 22,
                    ),
                    onPressed: () => ps.toggleLike(track),
                  ),
                  IconButton(
                    tooltip: 'Up Next Queue',
                    icon: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 24),
                    onPressed: widget.onOpenQueue,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the realistic spinning vinyl record
  Widget _buildVinylDisk(double diameter, Track track) {
    final labelDiameter = diameter * 0.40;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 28,
            spreadRadius: 6,
            offset: const Offset(4, 12),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _VinylDiskPainter(),
        child: Center(
          child: Container(
            width: labelDiameter,
            height: labelDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD32F2F), width: 5.5), // Signature Red Ring
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 8, spreadRadius: 1),
              ],
            ),
            child: ClipOval(
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  // Album Artwork
                  if (track.artworkUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: track.artworkUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: const Color(0xFF1C1C1E)),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF2C2C2E),
                        child: const Icon(Icons.music_note, color: Colors.white54),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF2C2C2E),
                      child: const Icon(Icons.album_rounded, color: Colors.white54, size: 40),
                    ),

                  // Center Spindle Hole
                  Center(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF07070A),
                        border: Border.all(color: const Color(0xFFD1D1D6), width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the horizontal futuristic deck unit with LED ticker and industrial accents
  Widget _buildFuturisticDeckUnit(double width, Track track) {
    const height = 66.0;

    return SizedBox(
      width: width,
      height: height + 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Top Curved Yellow Audio Wire
          Positioned(
            left: (width * 0.28),
            top: -16,
            child: CustomPaint(
              size: const Size(64, 26),
              painter: _CurvedWirePainter(color: const Color(0xFFFFB800), strokeWidth: 3.0),
            ),
          ),

          // Main Horizontal Chassis Dock
          Positioned(
            left: 0,
            right: 18,
            top: 4,
            height: height,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(33),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F0F14), Color(0xFF1A1A22), Color(0xFF252530)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Left Capsule: Glowing Digital LED Dot-Matrix Display
                  Expanded(
                    flex: 14,
                    child: Container(
                      margin: const EdgeInsets.all(5),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF050B08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF00FFC6).withValues(alpha: 0.35)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FFC6).withValues(alpha: 0.15),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Scrolling Ticker Text
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _ledScrollCtrl,
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Row(
                                children: [
                                  Text(
                                    'NOW PLAYING: ${track.title.toUpperCase()} / ${track.artist.toUpperCase()}    •    ',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: Color(0xFF00FFC6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      shadows: [
                                        Shadow(color: Color(0xFF00FFC6), blurRadius: 6),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'NOW PLAYING: ${track.title.toUpperCase()} / ${track.artist.toUpperCase()}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: Color(0xFF00FFC6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      shadows: [
                                        Shadow(color: Color(0xFF00FFC6), blurRadius: 6),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Dual Pulsing Green Status LEDs
                          AnimatedBuilder(
                            animation: _ledBlinkCtrl,
                            builder: (context, _) {
                              final opacity =
                                  widget.playerService.isPlaying ? (0.35 + (_ledBlinkCtrl.value * 0.65)) : 0.2;
                              return Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF00FF66).withValues(alpha: opacity),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00FF66).withValues(alpha: opacity),
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF00FF66).withValues(alpha: opacity),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00FF66).withValues(alpha: opacity),
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Section: Industrial Chassis with vents and model badge
                  Expanded(
                    flex: 9,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6D6DE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white60),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 3x4 Vent Dots Grid
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              3,
                              (_) => Row(
                                children: List.generate(
                                  3,
                                  (_) => Container(
                                    width: 3.5,
                                    height: 3.5,
                                    margin: const EdgeInsets.all(1.2),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF48484A),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Industrial Model Text
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'EUR-MAN',
                                style: TextStyle(
                                  color: Color(0xFF1C1C1E),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '(S) (Y)',
                                style: TextStyle(
                                  color: Color(0xFF48484A),
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Far Right Vertical Motor Housing & Cylinder
          Positioned(
            right: 0,
            top: -4,
            width: 22,
            height: height + 16,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE5E5EA), Color(0xFFA1A1A8), Color(0xFF58585E)],
                ),
                border: Border.all(color: Colors.white70, width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 4)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                  (_) => Container(
                    width: 14,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Metallic Antenna / Support Rod
          Positioned(
            right: 4,
            top: -26,
            width: 4,
            height: 28,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.black26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the realistic tone arm with pivot, metallic arm, and cartridge head
  Widget _buildToneArm(double length) {
    return SizedBox(
      width: length,
      height: length * 0.72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Tone Arm Pivot Base (Top-Right)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFF8E8E93), Color(0xFF3A3A3C)],
                ),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(1, 2)),
                ],
              ),
            ),
          ),

          // Arm Shaft & Stylus Needle Head Drawn with Custom Painter
          Positioned.fill(
            child: CustomPaint(
              painter: _ToneArmPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for the Vinyl Record Grooves and Specular Anisotropic Sheen
class _VinylDiskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer Vinyl Base
    final basePaint = Paint()
      ..color = const Color(0xFF0D0D10)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    // Realistic Micro-Grooves (Concentric Circles)
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (double r = radius * 0.42; r < radius - 3; r += 2.8) {
      final alpha = (0.025 + (math.sin(r * 0.45).abs() * 0.055)).clamp(0.0, 1.0);
      groovePaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(center, r, groovePaint);
    }

    // Outer Rim Highlight
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawCircle(center, radius - 1.5, rimPaint);

    // Anisotropic Specular Light Reflection (Bowtie Sheen)
    final sheenShader = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.16),
        Colors.transparent,
        Colors.white.withValues(alpha: 0.16),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 0.7, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    final sheenPaint = Paint()
      ..shader = sheenShader
      ..blendMode = BlendMode.screen;

    // Draw opposing conical sheen wedges
    final path = Path();
    path.moveTo(center.dx, center.dy);
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      -0.5,
      1.0,
      false,
    );
    path.close();

    path.moveTo(center.dx, center.dy);
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      math.pi - 0.5,
      1.0,
      false,
    );
    path.close();

    canvas.drawPath(path, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tone Arm Painter (Metallic arm shaft, elbow angle, and cartridge stylus)
class _ToneArmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width - 10, 10);
    final elbow = Offset(size.width * 0.42, size.height * 0.65);
    final cartridge = Offset(size.width * 0.16, size.height * 0.88);

    // Arm shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(pivot + const Offset(3, 6), elbow + const Offset(3, 6), shadowPaint);
    canvas.drawLine(elbow + const Offset(3, 6), cartridge + const Offset(3, 6), shadowPaint);

    // Metallic Tone Arm Tube
    final armPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFD1D1D6), Color(0xFF8E8E93)],
      ).createShader(Rect.fromPoints(pivot, cartridge))
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(pivot, elbow, armPaint);
    canvas.drawLine(elbow, cartridge, armPaint);

    // Stylus Cartridge Head
    final cartridgePaint = Paint()
      ..color = const Color(0xFF1C1C1E)
      ..style = PaintingStyle.fill;

    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: cartridge, width: 14, height: 20),
      const Radius.circular(3),
    );
    canvas.drawRRect(headRect, cartridgePaint);

    // Cartridge Chrome Accent
    final headAccent = Paint()
      ..color = const Color(0xFF00FFC6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(cartridge + const Offset(-4, 6), cartridge + const Offset(4, 6), headAccent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Curved Wire Painter for exposed hardware aesthetic
class _CurvedWirePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _CurvedWirePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.cubicTo(
      size.width * 0.35,
      0,
      size.width * 0.65,
      size.height * 1.1,
      size.width,
      size.height * 0.2,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
