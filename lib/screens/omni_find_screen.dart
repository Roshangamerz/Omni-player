import 'package:flutter/material.dart';
import '../models/echo_models.dart';
import '../services/audio_player_service.dart';
import '../services/echo_innertube_service.dart';
import '../services/odesli_service.dart';
import '../services/omni_find_service.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/echo_components.dart';

/// Echo Music "Echo Find" (ShazamKit Acoustic Fingerprinting Screen)
class OmniFindScreen extends StatefulWidget {
  final AudioPlayerService playerService;

  const OmniFindScreen({super.key, required this.playerService});

  @override
  State<OmniFindScreen> createState() => _OmniFindScreenState();
}

class _OmniFindScreenState extends State<OmniFindScreen> with SingleTickerProviderStateMixin {
  final OmniFindService _findService = OmniFindService();
  late final AnimationController _pulseCtrl;
  ShazamMatchResult? _latestMatch;
  String? _errorMsg;
  bool _resolvingTrack = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _findService.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _findService.removeListener(_onUpdate);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _startRecognition() async {
    setState(() {
      _errorMsg = null;
      _latestMatch = null;
    });
    try {
      final match = await _findService.recognizeFromMicrophone();
      if (!mounted) return;
      setState(() => _latestMatch = match);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _playIdentified(ShazamMatchResult match) async {
    setState(() => _resolvingTrack = true);
    try {
      final results = await EchoInnerTubeService()
          .searchTracks('${match.title} ${match.artist}', filterParams: EchoInnerTubeService.filterSongs);
      if (results.isNotEmpty) {
        await widget.playerService.playTrack(results.first, playlist: results);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playing "${results.first.title}"')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _resolvingTrack = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeProvider.of(context);
    final isListening = _findService.isListening;

    return Container(
      decoration: BoxDecoration(gradient: theme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: theme.textPrimary,
          title: const Text('Omni Find', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            if (_findService.history.isNotEmpty)
              IconButton(
                tooltip: 'Clear History',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _findService.clearHistory,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: isListening ? _findService.cancelListening : _startRecognition,
                child: SizedBox(
                  width: 210,
                  height: 210,
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) {
                      final t = _pulseCtrl.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isListening)
                            for (int ring = 0; ring < 3; ring++)
                              Opacity(
                                opacity: (1.0 - ((t + ring * 0.33) % 1.0)).clamp(0.0, 0.5),
                                child: Container(
                                  width: 120 + (((t + ring * 0.33) % 1.0) * 90),
                                  height: 120 + (((t + ring * 0.33) % 1.0) * 90),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: theme.primary, width: 2.5),
                                  ),
                                ),
                              ),
                          Container(
                            width: 132,
                            height: 132,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [theme.primary, theme.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primary.withValues(alpha: 0.35),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                              size: 54,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _findService.statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            if (_latestMatch != null) ...[
              const SizedBox(height: 22),
              EchoSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        EchoArtwork(url: _latestMatch!.artworkUrl, size: 74, radius: 16),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _latestMatch!.title,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _latestMatch!.artist,
                                style: TextStyle(color: theme.textSecondary, fontSize: 14),
                              ),
                              if (_latestMatch!.album.isNotEmpty)
                                Text(
                                  '${_latestMatch!.album}${_latestMatch!.releaseYear.isNotEmpty ? " • ${_latestMatch!.releaseYear}" : ""}',
                                  style: TextStyle(
                                      color: theme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.primary,
                              foregroundColor: theme.primaryForeground,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: _resolvingTrack ? null : () => _playIdentified(_latestMatch!),
                            icon: _resolvingTrack
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play in Omni'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: () => OdesliService.sharePlainText(
                            _latestMatch!.title,
                            'Found "${_latestMatch!.title}" by ${_latestMatch!.artist} via Omni Find\n${_latestMatch!.shazamUrl}',
                          ),
                          icon: const Icon(Icons.share_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            Text(
              'RECENT RECOGNITIONS',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            if (_findService.history.isEmpty)
              EchoSurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Songs you identify with Omni Find appear here.',
                  style: TextStyle(color: theme.textSecondary, fontSize: 13),
                ),
              )
            else
              EchoSurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final item in _findService.history)
                      ListTile(
                        leading: EchoArtwork(url: item.artworkUrl, size: 48, radius: 12),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          item.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                        trailing: Icon(Icons.play_circle_fill_rounded, color: theme.primary),
                        onTap: () => _playIdentified(item),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
