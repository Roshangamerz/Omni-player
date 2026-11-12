import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_player_service.dart';
import '../services/extension_engine.dart';
import '../theme/animated_touch.dart';
import 'home_shell.dart';

class OnboardingScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final ExtensionEngine extensionEngine;

  const OnboardingScreen({
    super.key,
    required this.playerService,
    required this.extensionEngine,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  int _selectedPreset = 0;
  final _customNameCtrl = TextEditingController();
  final _customUrlCtrl = TextEditingController();
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _errorMessage;

  late AnimationController _pulseCtrl;
  late AnimationController _vinylCtrl;

  final List<Map<String, String>> _repoPresets = [
    {
      'title': 'SoundBound Experimental',
      'tag': 'VERIFIED • 320K LOSSLESS',
      'desc': 'Community resolvers, 320k audio streams & synced lyrics.',
      'url': 'https://gitlab.com/shabinder/soundbound/-/raw/main/Experimental-Sources/sources.json',
      'icon': '⚡',
    },
    {
      'title': 'JioSaavn & Vercel Lossless API',
      'tag': 'FAST • 320K FLAC/AAC',
      'desc': 'Direct studio audio API integration with 320kbps streams.',
      'url': 'https://jiosaavn-api.vercel.app',
      'icon': '🚀',
    },
    {
      'title': 'Custom Vercel / Repo / M3U URL',
      'tag': 'ALL REPO FORMATS',
      'desc': 'Connect your private API, SoundBound JSON, or M3U playlist.',
      'url': '',
      'icon': '➕',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _vinylCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _pulseCtrl.dispose();
    _vinylCtrl.dispose();
    _customNameCtrl.dispose();
    _customUrlCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    _pageCtrl.animateToPage(
      _currentPage + 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _connectAndFinish() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    String repoName = '';
    String repoUrl = '';

    if (_selectedPreset == 2) {
      repoName = _customNameCtrl.text.trim();
      repoUrl = _customUrlCtrl.text.trim();
      if (repoName.isEmpty || repoUrl.isEmpty) {
        setState(() {
          _isConnecting = false;
          _errorMessage = 'Please provide both repository name and URL';
        });
        return;
      }
    } else {
      repoName = _repoPresets[_selectedPreset]['title']!;
      repoUrl = _repoPresets[_selectedPreset]['url']!;
    }

    try {
      if (repoUrl.isNotEmpty) {
        // Fast background add
        widget.extensionEngine.addRepository(repoUrl, customName: repoName);
      }
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 250));
      _finish();
    } catch (e) {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondaryAnim) => HomeShell(
          playerService: widget.playerService,
          extensionEngine: widget.extensionEngine,
        ),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // Theme Glowing Gradient Background
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0284C7), Color(0xFF10B981)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'OMNI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      // Progress Dots
                      Row(
                        children: [
                          Container(
                            width: _currentPage == 0 ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == 0 ? const Color(0xFF38BDF8) : Colors.white24,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: _currentPage == 1 ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == 1 ? const Color(0xFF38BDF8) : Colors.white24,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _finish,
                        child: const Text('Skip', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _buildWelcomePage(),
                      _buildRepositoryPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Glowing Vinyl Core
          AnimatedBuilder(
            animation: Listenable.merge([_pulseCtrl, _vinylCtrl]),
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220 + (_pulseCtrl.value * 20),
                    height: 220 + (_pulseCtrl.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.35 * _pulseCtrl.value),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Transform.rotate(
                    angle: _vinylCtrl.value * 2 * math.pi,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF020617)],
                        ),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 3),
                      ),
                      child: Center(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF10B981)],
                            ),
                          ),
                          child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 36),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, color: Color(0xFF38BDF8), size: 16),
                SizedBox(width: 4),
                Text('NEXT-GEN AUDIO ENGINE', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Music Without\nBoundaries.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Connect any music repository, stream in lossless 320k audio, and enjoy pure studio fidelity.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 36),

          // Feature Highlights
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeatureBadge(icon: '🌐', label: 'Repo Hub'),
              _FeatureBadge(icon: '💎', label: '320k Lossless'),
              _FeatureBadge(icon: '⚡', label: 'Zero Lag'),
              _FeatureBadge(icon: '🦸', label: 'Marvel HUD'),
            ],
          ),
          const SizedBox(height: 36),

          AnimatedTouch(
            onTap: _nextPage,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Get Started', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepositoryPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Connect Music Hub',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select a verified source repository or API to instantly access music streams:',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 20),

            // Presets List
            ...List.generate(_repoPresets.length, (idx) {
              final preset = _repoPresets[idx];
              final isSelected = _selectedPreset == idx;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: AnimatedTouch(
                  onTap: () => setState(() => _selectedPreset = idx),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.15) : const Color(0xFF0F172A).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF38BDF8) : Colors.white12,
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0284C7) : Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text(preset['icon']!, style: const TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset['title']!,
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    preset['tag']!,
                                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? const Color(0xFF38BDF8) : Colors.white30,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset['desc']!,
                          style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                        ),

                        // Custom URL fields when custom selected
                        if (idx == 2 && isSelected) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _customNameCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Repository Name (e.g. My Saavn API)',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                              filled: true,
                              fillColor: Colors.black26,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _customUrlCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'https://jiosaavn-apii-piczu7bd4-omin-player.vercel.app',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                              filled: true,
                              fillColor: Colors.black26,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],

            const SizedBox(height: 20),

            // Connect & Launch Button
            AnimatedTouch(
              onTap: _isConnecting ? null : _connectAndFinish,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isConnected
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFF0284C7), const Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isConnecting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _isConnected ? '✓ Connected!' : 'Connect & Launch →',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Center(
              child: TextButton(
                onPressed: _finish,
                child: const Text('I\'ll configure repositories later in Settings', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final String icon;
  final String label;

  const _FeatureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
