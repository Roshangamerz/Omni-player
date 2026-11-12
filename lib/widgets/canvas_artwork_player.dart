import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/track.dart';
import '../services/canvas_service.dart';
import 'echo_components.dart';

/// Echo Music Looping Canvas Video Player layered seamlessly over Album Art
class CanvasArtworkPlayer extends StatefulWidget {
  final Track track;
  final bool enabled;
  final bool isPlaying;
  final BoxFit fit;
  final double borderRadius;

  const CanvasArtworkPlayer({
    super.key,
    required this.track,
    this.enabled = true,
    this.isPlaying = true,
    this.fit = BoxFit.cover,
    this.borderRadius = 24,
  });

  @override
  State<CanvasArtworkPlayer> createState() => _CanvasArtworkPlayerState();
}

class _CanvasArtworkPlayerState extends State<CanvasArtworkPlayer> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  String _lastTrackKey = '';
  String? _activeProvider;

  @override
  void initState() {
    super.initState();
    _loadCanvas();
  }

  @override
  void didUpdateWidget(covariant CanvasArtworkPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id || oldWidget.enabled != widget.enabled) {
      _loadCanvas();
    } else if (_controller != null && _videoReady) {
      if (widget.isPlaying && !_controller!.value.isPlaying) {
        _controller!.play();
      } else if (!widget.isPlaying && _controller!.value.isPlaying) {
        _controller!.pause();
      }
    }
  }

  Future<void> _loadCanvas() async {
    final key = '${widget.track.id}|${widget.enabled}';
    if (_lastTrackKey == key) return;
    _lastTrackKey = key;

    await _disposeController();
    if (!widget.enabled) return;

    try {
      final res = await CanvasService().getCanvasForTrack(
        song: widget.track.title,
        artist: widget.track.artist,
        album: widget.track.album,
      );
      if (!mounted || _lastTrackKey != key) return;
      if (res != null && res.hasVideo) {
        final ctrl = VideoPlayerController.networkUrl(Uri.parse(res.videoUrl!));
        await ctrl.initialize();
        if (!mounted || _lastTrackKey != key) {
          await ctrl.dispose();
          return;
        }
        await ctrl.setVolume(0.0);
        await ctrl.setLooping(true);
        if (widget.isPlaying) await ctrl.play();
        setState(() {
          _controller = ctrl;
          _videoReady = true;
          _activeProvider = res.provider;
        });
      }
    } catch (_) {
      await _disposeController();
    }
  }

  Future<void> _disposeController() async {
    final old = _controller;
    _controller = null;
    if (mounted) {
      setState(() {
        _videoReady = false;
        _activeProvider = null;
      });
    }
    if (old != null) {
      try {
        await old.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          EchoArtwork(
            url: widget.track.artworkUrl,
            size: 600,
            radius: widget.borderRadius,
          ),
          if (_videoReady && _controller != null)
            AnimatedOpacity(
              opacity: _videoReady ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 450),
              child: FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller!.value.size.width > 0
                      ? _controller!.value.size.width
                      : 512,
                  height: _controller!.value.size.height > 0
                      ? _controller!.value.size.height
                      : 512,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          if (_activeProvider != null)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _activeProvider!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
