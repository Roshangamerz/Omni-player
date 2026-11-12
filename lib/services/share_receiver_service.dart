import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'audio_player_service.dart';
import 'link_parser_service.dart';

class ShareReceiverService {
  static final ShareReceiverService _instance = ShareReceiverService._internal();
  factory ShareReceiverService() => _instance;
  ShareReceiverService._internal();

  static const MethodChannel _channel = MethodChannel('com.omniplayer.music/media_notification');

  final StreamController<String> _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    // Listen for incoming share intents while app is running
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedTextReceived') {
        final text = call.arguments?.toString();
        if (text != null && text.trim().isNotEmpty) {
          handleIncomingSharedText(text.trim());
        }
      }
    });

    // Check if app was launched via a Share Intent (cold start)
    _checkInitialSharedText();
  }

  Future<void> _checkInitialSharedText() async {
    try {
      final initialText = await _channel.invokeMethod<String>('getInitialSharedText');
      if (initialText != null && initialText.trim().isNotEmpty) {
        // Allow player initialization to settle before loading
        await Future.delayed(const Duration(milliseconds: 600));
        handleIncomingSharedText(initialText.trim());
      }
    } catch (e) {
      debugPrint('Error getting initial shared text: $e');
    }
  }

  /// Process any shared text, YouTube link, Spotify URL, etc.
  Future<void> handleIncomingSharedText(String text) async {
    debugPrint('ShareReceiverService: Processing shared text -> $text');
    _statusController.add('⚡ Parsing shared music link...');

    try {
      // Extract URL if surrounded by extra text like "Check out this video: https://..."
      final urlReg = RegExp(r'https?:\/\/[^\s]+');
      final match = urlReg.firstMatch(text);
      final target = match != null ? match.group(0)! : text;

      final result = await LinkParserService().parseUrl(target);

      if (result.isTrack && result.track != null) {
        final track = result.track!;
        _statusController.add('▶ Playing "${track.title}"');
        await AudioPlayerService().playTrack(track);
      } else if (result.isPlaylist && result.playlist != null) {
        final pl = result.playlist!;
        if (pl.tracks.isNotEmpty) {
          _statusController.add('✓ Imported "${pl.title}" (${pl.tracks.length} tracks)');
          // Save playlist to user's library
          await AudioPlayerService().savePlaylist(pl.title, pl.tracks);
          // Start playing
          await AudioPlayerService().playTrack(pl.tracks.first, playlist: pl.tracks);
        } else {
          _statusController.add('Could not find playable tracks in this playlist.');
        }
      } else {
        _statusController.add(result.errorMessage ?? 'Could not resolve audio from shared link.');
      }
    } catch (e) {
      debugPrint('ShareReceiverService handling error: $e');
      _statusController.add('Error playing shared content: $e');
    }
  }
}
