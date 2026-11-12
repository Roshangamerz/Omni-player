import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import 'audio_stream_service.dart';
import 'echo_innertube_service.dart';
import 'extension_engine.dart';
import 'extension_manager_service.dart';
import 'innertube_service.dart';
import 'listen_together_service.dart';
import 'share_receiver_service.dart';
import 'stats_service.dart';

enum PlaybackRepeatMode { off, all, one }

enum ShuffleMode { off, normal, smart }

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  static const MethodChannel _mediaNotificationChannel =
      MethodChannel('com.omniplayer.music/media_notification');

  final AudioPlayer _playerA = AudioPlayer();
  final AudioPlayer _playerB = AudioPlayer();
  late AudioPlayer _activePlayer = _playerA;
  late AudioPlayer _standbyPlayer = _playerB;

  Track? _currentTrack;
  Track? _preloadedNextTrack;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isBuffering = false;
  bool _isTransitioning = false;

  List<Track> _playlist = [];
  int _currentIndex = 0;

  ShuffleMode _shuffleMode = ShuffleMode.off;
  bool get _isShuffle => _shuffleMode != ShuffleMode.off;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.off;
  double _volume = 1.0;

  final Set<String> _likedTrackIds = {};
  final List<Track> _likedTracks = [];
  final Map<String, List<Track>> _userPlaylists = {};
  final List<Track> _history = [];

  AppThemeMode _themeMode = AppThemeMode.echoRose;
  String _userName = 'Listener';
  String _playerStyle = 'apple'; // 'apple' | 'material'
  bool _isCanvasEnabled = true;
  bool _isOmniBrainEnabled = true;
  String _activeQualityBadge = '256 kbps AAC';
  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;
  bool _isGlassEnabled = true;
  bool _isLiquidGlassEnabled = true;
  bool _isDarkMode = true;
  bool _isDataSaverEnabled = false;
  bool _isLosslessEnabled = true;
  bool _isSilenceTrimEnabled = true;
  bool _isGaplessEnabled = true;
  bool _isAiRemixEnabled = true;

  // Smart Beat Mixing & Crossfade Engine (Apple Music Style)
  bool _isSmartCrossfade = true;
  int _crossfadeSeconds = 5;
  bool _isCrossfading = false;
  Timer? _crossfadeTimer;

  Color? _customPrimaryColor;
  Color? _customBgColor;
  String _marvelHero = 'iron_man';
  bool _isMarvelJarvisHud = true;

  DateTime _lastPositionNotify = DateTime.fromMillisecondsSinceEpoch(0);

  // Getters
  Track? get currentTrack => _currentTrack;
  Track? get preloadedNextTrack => _preloadedNextTrack;
  PlayerState get playerState => _playerState;
  bool get isPlaying => _playerState == PlayerState.playing;
  bool get isPaused => _playerState == PlayerState.paused;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  List<Track> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  ShuffleMode get shuffleMode => _shuffleMode;
  bool get isShuffle => _shuffleMode != ShuffleMode.off;
  bool get isSmartShuffle => _shuffleMode == ShuffleMode.smart;
  PlaybackRepeatMode get repeatMode => _repeatMode;
  double get volume => _volume;
  List<Track> get likedTracks => List.unmodifiable(_likedTracks);
  Map<String, List<Track>> get userPlaylists => Map.unmodifiable(_userPlaylists);
  List<Track> get history => List.unmodifiable(_history);
  AppThemeMode get themeMode => _themeMode;
  String get userName => _userName;
  String get playerStyle => _playerStyle;
  bool get isCanvasEnabled => _isCanvasEnabled;
  bool get isOmniBrainEnabled => _isOmniBrainEnabled;
  String get activeQualityBadge => _activeQualityBadge;
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;
  bool get isGlassEnabled => _isGlassEnabled;
  bool get isLiquidGlassEnabled => _isLiquidGlassEnabled;
  bool get isDarkMode => _isDarkMode;
  bool get isDataSaverEnabled => _isDataSaverEnabled;
  bool get isLosslessEnabled => _isLosslessEnabled;
  bool get isSilenceTrimEnabled => _isSilenceTrimEnabled;
  bool get isGaplessEnabled => _isGaplessEnabled;
  bool get isAiRemixEnabled => _isAiRemixEnabled;
  bool get isSmartCrossfade => _isSmartCrossfade;
  int get crossfadeSeconds => _crossfadeSeconds;
  bool get isCrossfading => _isCrossfading;
  Color? get customPrimaryColor => _customPrimaryColor;
  Color? get customBgColor => _customBgColor;
  String get marvelHero => _marvelHero;
  bool get isMarvelJarvisHud => _isMarvelJarvisHud;

  bool isTrackLiked(String trackId) => _likedTrackIds.contains(trackId);

  Future<void> init() async {
    _activePlayer = _playerA;
    _standbyPlayer = _playerB;

    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );

      await _playerA.setReleaseMode(ReleaseMode.stop);
      await _playerB.setReleaseMode(ReleaseMode.stop);

      _setupPlayerListeners(_playerA);
      _setupPlayerListeners(_playerB);

      // Handle Lock Screen & Notification Shade callbacks + Share Intents + Notification Seeks
      _mediaNotificationChannel.setMethodCallHandler((call) async {
        if (call.method == 'onNotificationAction') {
          final action = call.arguments as String?;
          if (action == 'play') {
            resume();
          } else if (action == 'pause') {
            pause();
          } else if (action == 'next') {
            next();
          } else if (action == 'previous') {
            previous();
          } else if (action == 'stop') {
            stopAndClear();
          }
        } else if (call.method == 'onNotificationSeek') {
          final posMs = call.arguments as int?;
          if (posMs != null) {
            seek(Duration(milliseconds: posMs));
          }
        } else if (call.method == 'onSharedTextReceived') {
          final text = call.arguments?.toString();
          if (text != null && text.trim().isNotEmpty) {
            ShareReceiverService().handleIncomingSharedText(text.trim());
          }
        }
      });
    } catch (e) {
      debugPrint('AudioPlayer platform init error: $e');
    }

    await _loadPersistedData();
  }

  Color _activeThemeColor = const Color(0xFF00FFC6);
  Color get activeThemeColor => _activeThemeColor;

  void updateThemeColor(Color c) {
    _activeThemeColor = c;
    _updateMediaNotification();
  }

  void _updateMediaNotification() {
    try {
      if (_currentTrack != null) {
        _mediaNotificationChannel.invokeMethod('updateNotification', {
          'title': _currentTrack!.title,
          'artist': _currentTrack!.artist,
          'artworkUrl': _currentTrack!.artworkUrl,
          'isPlaying': _playerState == PlayerState.playing,
          'themeColor': _activeThemeColor.toARGB32(),
          'positionMs': _position.inMilliseconds,
          'durationMs': _duration.inMilliseconds,
        });
      } else {
        _mediaNotificationChannel.invokeMethod('clearNotification');
      }
    } catch (_) {}
  }

  void _setupPlayerListeners(AudioPlayer player) {
    player.onPlayerStateChanged.listen((state) {
      if (player == _activePlayer) {
        if (state == PlayerState.playing) {
          _playerState = PlayerState.playing;
          _isBuffering = false;
          _isCrossfading = false;
          _updateMediaNotification();
          notifyListeners();
        } else if (state == PlayerState.paused) {
          _playerState = PlayerState.paused;
          _isBuffering = false;
          _updateMediaNotification();
          notifyListeners();
        } else if (state == PlayerState.completed && !_isCrossfading) {
          _handleTrackCompleted();
        }
      }
    });

    player.onPositionChanged.listen((pos) {
      if (player == _activePlayer) {
        _position = pos;

        // Apple Music Seamless Crossfade Trigger
        _checkAndTriggerCrossfade(pos);

        // Responsive, buttery smooth 250ms position updates (eliminates lag on lower-spec CPUs)
        final now = DateTime.now();
        if (now.difference(_lastPositionNotify).inMilliseconds >= 250) {
          _lastPositionNotify = now;
          notifyListeners();
        }
      }
    });

    player.onDurationChanged.listen((dur) {
      if (player == _activePlayer && dur > Duration.zero) {
        _duration = dur;
        notifyListeners();
      }
    });

    player.onPlayerComplete.listen((_) {
      if (player == _activePlayer && !_isCrossfading) {
        _handleTrackCompleted();
      }
    });
  }

  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedTheme = prefs.getInt('omni_theme_mode');
      if (savedTheme != null && savedTheme < AppThemeMode.values.length) {
        _themeMode = AppThemeMode.values[savedTheme];
      }

      _userName = prefs.getString('omni_user_name') ?? 'Listener';
      _playerStyle = prefs.getString('omni_player_style') ?? 'apple';
      _isCanvasEnabled = prefs.getBool('omni_canvas_enabled') ?? true;
      _isOmniBrainEnabled = prefs.getBool('omni_brain_enabled') ?? true;
      _isGlassEnabled = prefs.getBool('omni_glass_enabled') ?? true;
      _isLiquidGlassEnabled = prefs.getBool('omni_liquid_glass') ?? true;
      _isDarkMode = prefs.getBool('omni_dark_mode') ?? true;
      _isDataSaverEnabled = prefs.getBool('omni_data_saver') ?? false;
      _isLosslessEnabled = prefs.getBool('omni_lossless') ?? true;
      _isSilenceTrimEnabled = prefs.getBool('omni_silence_trim') ?? true;
      _isGaplessEnabled = prefs.getBool('omni_gapless') ?? true;
      _isAiRemixEnabled = prefs.getBool('omni_ai_remix_enabled') ?? true;
      _isSmartCrossfade = prefs.getBool('omni_smart_crossfade') ?? true;
      _crossfadeSeconds = prefs.getInt('omni_crossfade_seconds') ?? 5;
      _marvelHero = prefs.getString('omni_marvel_hero') ?? 'iron_man';
      _isMarvelJarvisHud = prefs.getBool('omni_marvel_hud') ?? true;

      final customPrim = prefs.getInt('omni_custom_primary');
      if (customPrim != null) _customPrimaryColor = Color(customPrim);
      final customBg = prefs.getInt('omni_custom_bg');
      if (customBg != null) _customBgColor = Color(customBg);

      // Load Liked Tracks
      final likedJson = prefs.getString('omni_liked_tracks');
      if (likedJson != null) {
        final list = jsonDecode(likedJson) as List<dynamic>;
        _likedTracks.clear();
        _likedTrackIds.clear();
        for (final item in list) {
          final t = Track.fromJson(item as Map<String, dynamic>);
          _likedTracks.add(t);
          _likedTrackIds.add(t.id);
        }
      }

      // Load User Playlists
      final playlistsJson = prefs.getString('omni_user_playlists');
      if (playlistsJson != null) {
        final map = jsonDecode(playlistsJson) as Map<String, dynamic>;
        _userPlaylists.clear();
        map.forEach((k, v) {
          final trackList = (v as List<dynamic>)
              .map((item) => Track.fromJson(item as Map<String, dynamic>))
              .toList();
          _userPlaylists[k] = trackList;
        });
      } else {
        // Default seed playlist
        _userPlaylists['Daily Mix'] = [];
        _userPlaylists['Chill Vibes'] = [];
      }

      // Load History (strictly music tracks only)
      final historyJson = prefs.getString('omni_history');
      if (historyJson != null) {
        final list = jsonDecode(historyJson) as List<dynamic>;
        _history.clear();
        for (final item in list) {
          final t = Track.fromJson(item as Map<String, dynamic>);
          if (!isNonMusicTrack(t)) {
            _history.add(t);
          }
        }
        _saveHistory();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading persisted audio data: $e');
    }
  }

  static bool isNonMusicTrack(Track track) {
    final lower = '${track.title} ${track.artist} ${track.album}'.toLowerCase();
    final nonMusic = [
      'tutorial', 'how to', 'storage full', 'phone hanging', 'problem solve',
      'live proof', 'unboxing', 'transfer data', 'internal storage', 'sd card',
      'setting', 'whatsapp', 'aud-', 'ptt-', 'call_', 'technical aqeel',
      'technical sunny', 'the random king', 'tech is easy', 'solution',
    ];
    return nonMusic.any((kw) => lower.contains(kw));
  }

  Future<void> _microFadeOut(AudioPlayer player) async {
    try {
      const steps = 4;
      for (int i = steps - 1; i >= 0; i--) {
        await player.setVolume((_volume * (i / steps)).clamp(0.0, 1.0));
        await Future.delayed(const Duration(milliseconds: 20));
      }
    } catch (_) {}
  }

  Future<void> playTrack(Track track, {List<Track>? playlist}) async {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _isCrossfading = false;
    _isTransitioning = false;
    final bool wasPlaying = isPlaying;
    _currentTrack = track;
    _playerState = PlayerState.playing;
    _isBuffering = true;
    _position = Duration.zero;
    _duration = Duration.zero;

    if (playlist != null) {
      _playlist = List.from(playlist);
      _currentIndex = _playlist.indexWhere((t) => t.id == track.id);
      if (_currentIndex == -1) {
        _playlist.insert(0, track);
        _currentIndex = 0;
      }
    } else if (!_playlist.any((t) => t.id == track.id)) {
      _playlist = [track];
      _currentIndex = 0;
    }

    _addToHistory(track);
    StatsService().recordPlay(track);
    ListenTogetherService().broadcastTrackState(track, true, 0);
    _updateMediaNotification();
    notifyListeners();

    if (_isOmniBrainEnabled && _playlist.length - _currentIndex <= 2) {
      _injectSmartRecommendations();
    }

    try {
      if (wasPlaying) {
        await _microFadeOut(_activePlayer);
      }
      await _activePlayer.stop().catchError((_) {});
      await _standbyPlayer.stop().catchError((_) {});

      String activeStreamUrl = await _resolveStreamUrlWithRetry(track);

      if (activeStreamUrl.isEmpty) {
        _playerState = PlayerState.stopped;
        _isBuffering = false;
        _updateMediaNotification();
        notifyListeners();
        // Auto skip to next track after brief delay so broken URLs do not freeze player
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (_currentTrack?.id == track.id && _playerState == PlayerState.stopped) {
            next();
          }
        });
        return;
      }

      Source audioSource = _buildAudioSource(activeStreamUrl);

      await _activePlayer.setVolume(_volume.clamp(0.0, 1.0));
      try {
        await _activePlayer.play(audioSource);
      } catch (playErr) {
        debugPrint('Primary stream play failed, clearing cache and retrying: $playErr');
        AudioStreamService().clearCacheForId(track.id);
        final retryUrl = await _resolveStreamUrlWithRetry(track, forceFresh: true);
        if (retryUrl.isNotEmpty) {
          final retrySource = _buildAudioSource(retryUrl);
          await _activePlayer.play(retrySource);
        } else {
          _playerState = PlayerState.stopped;
          _isBuffering = false;
          notifyListeners();
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (_currentTrack?.id == track.id && _playerState == PlayerState.stopped) {
              next();
            }
          });
          return;
        }
      }

      _playerState = PlayerState.playing;
      _isBuffering = false;
      _updateMediaNotification();
      notifyListeners();

      // Preload upcoming track into standby player
      _preloadNextTrack();
    } catch (e) {
      debugPrint('Audio playback error for ${track.title}: $e');
      _playerState = PlayerState.stopped;
      _isBuffering = false;
      _isTransitioning = false;
      notifyListeners();
    }
  }

  Source _buildAudioSource(String streamUrl) {
    if (streamUrl.startsWith('asset:')) {
      return AssetSource(streamUrl.replaceFirst('asset:', ''));
    } else if (streamUrl.startsWith('file://')) {
      return DeviceFileSource(streamUrl.replaceFirst('file://', ''));
    } else if (streamUrl.startsWith('/')) {
      return DeviceFileSource(streamUrl);
    } else {
      return UrlSource(streamUrl);
    }
  }

  Future<String> _resolveStreamUrlWithRetry(Track track, {bool forceFresh = false}) async {
    String activeStreamUrl = track.streamUrl;
    if (activeStreamUrl.startsWith('file://') || activeStreamUrl.startsWith('/') || activeStreamUrl.startsWith('asset:')) {
      _activeQualityBadge = 'LOCAL HI-FI';
      return activeStreamUrl;
    }

    // Tier 0: Echo Music Custom 320kbps / Lossless FLAC Extension Server Priority
    if (ExtensionManagerService().hasEnabledAddons &&
        (ExtensionManagerService().preferExtensionAudio || track.id.startsWith('addon_'))) {
      try {
        final extStream = await ExtensionManagerService().resolveBestStreamForTrack(track);
        if (extStream != null && extStream.url.isNotEmpty) {
          _activeQualityBadge = extStream.qualityBadge;
          return extStream.url;
        }
      } catch (_) {}
    }

    if (activeStreamUrl.contains('saavncdn.com') || track.id.startsWith('saavn_')) {
      _activeQualityBadge = '320 kbps AAC';
    } else {
      _activeQualityBadge = '256 kbps AAC';
    }

    final isYouTube = track.id.startsWith('yt_') || track.sourcePluginId.toLowerCase().contains('youtube');
    final isSpotify = track.id.startsWith('sp_') || track.sourcePluginId.toLowerCase().contains('spotify');
    final isApplePreview = track.id.startsWith('itunes_') ||
        track.sourcePluginId.toLowerCase().contains('itunes') ||
        track.sourcePluginId.toLowerCase().contains('apple') ||
        activeStreamUrl.contains('mzstatic.com') ||
        activeStreamUrl.contains('apple.com');

    if (forceFresh) {
      AudioStreamService().clearCacheForId(track.id);
    }

    if (activeStreamUrl.isEmpty || isYouTube || isSpotify || isApplePreview || forceFresh) {
      if (isYouTube || track.id.startsWith('yt_')) {
        try {
          final directStream = await AudioStreamService().resolveStreamUrl(track.id);
          if (directStream != null && directStream.isNotEmpty) {
            activeStreamUrl = directStream;
          }
        } catch (_) {}
      }

      if (activeStreamUrl.isEmpty || isApplePreview || isSpotify) {
        try {
          final query = '${track.title} ${track.artist}'.trim();
          // Step 1: Query YouTube Music directly for instant stream resolution
          final ytHits = await InnerTubeService().searchTracks(query);
          if (ytHits.isNotEmpty) {
            final ytDirect = await AudioStreamService().resolveStreamUrl(ytHits.first.id);
            if (ytDirect != null && ytDirect.isNotEmpty) {
              activeStreamUrl = ytDirect;
              if (_currentTrack?.id == track.id && ytHits.first.duration > Duration.zero) {
                _duration = ytHits.first.duration;
              }
            }
          }

          // Step 2: Fallback to other providers
          if (activeStreamUrl.isEmpty || isApplePreview) {
            final fallbackTracks = await ExtensionEngine().searchAcrossAllSources(query);
            if (fallbackTracks.isNotEmpty) {
              final cleanTitle = track.title.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ').trim();
              final titleTokens = cleanTitle.split(' ').where((s) => s.length > 2).toList();

              final matching = fallbackTracks.where((t) {
                if (t.streamUrl.isEmpty || t.streamUrl.startsWith('asset:')) return false;
                if (t.streamUrl.contains('apple.com') || t.streamUrl.contains('mzstatic.com')) return false;
                final candTitle = t.title.toLowerCase();
                if (candTitle.contains(cleanTitle) || cleanTitle.contains(candTitle)) return true;
                return titleTokens.any((token) => candTitle.contains(token));
              }).toList();

              if (matching.isNotEmpty) {
                activeStreamUrl = matching.first.streamUrl;
                if (_currentTrack?.id == track.id && matching.first.duration > Duration.zero) {
                  _duration = matching.first.duration;
                }
              }
            }
          }
        } catch (_) {}
      }
    }
    return activeStreamUrl;
  }

  void _checkAndTriggerCrossfade(Duration pos) {
    if (!_isSmartCrossfade || _isCrossfading || _duration <= const Duration(seconds: 15)) {
      return;
    }

    final remaining = _duration - pos;
    if (remaining <= Duration(seconds: _crossfadeSeconds) && remaining > Duration.zero) {
      final nextTrack = _getNextTrackInQueue();
      if (nextTrack != null) {
        _startCrossfadeToNext(nextTrack);
      }
    }
  }

  Track? _getNextTrackInQueue() {
    if (_playlist.isEmpty) return null;
    if (_repeatMode == PlaybackRepeatMode.one) return _currentTrack;
    if (_isShuffle) {
      if (_playlist.length == 1) return _playlist[0];
      int r = Random().nextInt(_playlist.length);
      if (r == _currentIndex) r = (r + 1) % _playlist.length;
      return _playlist[r];
    }
    int nIdx = _currentIndex + 1;
    if (nIdx >= _playlist.length) {
      if (_repeatMode == PlaybackRepeatMode.all) {
        nIdx = 0;
      } else {
        return null;
      }
    }
    return _playlist[nIdx];
  }

  void _startCrossfadeToNext(Track nextTrack) async {
    if (_isCrossfading || _playlist.isEmpty) return;
    _isCrossfading = true;
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    notifyListeners();

    try {
      String streamUrl = nextTrack.streamUrl;
      if (streamUrl.isEmpty || nextTrack.id.startsWith('yt_') || nextTrack.id.startsWith('sp_')) {
        final resolved = await AudioStreamService().resolveStreamUrl(nextTrack.id);
        if (resolved != null && resolved.isNotEmpty) {
          streamUrl = resolved;
        }
      }

      if (streamUrl.isEmpty) {
        _isCrossfading = false;
        await _activePlayer.setVolume(_volume.clamp(0.0, 1.0));
        notifyListeners();
        return;
      }

      Source nextSource = _buildAudioSource(streamUrl);

      await _standbyPlayer.setVolume(0.0);
      await _standbyPlayer.play(nextSource);

      final totalSteps = 20;
      final stepDuration = Duration(milliseconds: (_crossfadeSeconds * 1000) ~/ totalSteps);

      for (int step = 1; step <= totalSteps; step++) {
        if (!_isCrossfading) return;
        await Future.delayed(stepDuration);
        if (!_isCrossfading) return;

        final progress = (step / totalSteps).clamp(0.0, 1.0);
        final angle = progress * (pi / 2.0);
        final outgoingVol = (cos(angle) * _volume).clamp(0.0, 1.0);
        final incomingVol = (sin(angle) * _volume).clamp(0.0, 1.0);

        _activePlayer.setVolume(outgoingVol).catchError((_) {});
        _standbyPlayer.setVolume(incomingVol).catchError((_) {});
      }

      if (_isCrossfading) {
        await _finishCrossfade(nextTrack);
      }
    } catch (e) {
      debugPrint('Crossfade error: $e');
      _isCrossfading = false;
      await _activePlayer.setVolume(_volume.clamp(0.0, 1.0)).catchError((_) {});
      notifyListeners();
    }
  }

  Future<void> _finishCrossfade(Track nextTrack) async {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;

    final oldActive = _activePlayer;
    final newActive = _standbyPlayer;

    // Swap references
    _activePlayer = newActive;
    _standbyPlayer = oldActive;

    await oldActive.stop();
    await oldActive.setVolume(_volume.clamp(0.0, 1.0));
    await newActive.setVolume(_volume.clamp(0.0, 1.0));

    _currentTrack = nextTrack;
    _currentIndex = _playlist.indexWhere((t) => t.id == nextTrack.id);
    if (_currentIndex == -1 && _playlist.isNotEmpty) {
      _playlist.add(nextTrack);
      _currentIndex = _playlist.length - 1;
    }
    _playerState = PlayerState.playing;
    _isBuffering = false;
    _isCrossfading = false;
    _addToHistory(nextTrack);
    _updateMediaNotification();
    notifyListeners();

    // Preload next upcoming track into newly standby player
    _preloadNextTrack();
  }

  Future<void> _preloadNextTrack() async {
    if (!_isGaplessEnabled || _playlist.isEmpty) return;
    final nextTrack = _getNextTrackInQueue();
    if (nextTrack == null) return;

    _preloadedNextTrack = nextTrack;
    try {
      String streamUrl = nextTrack.streamUrl;
      if (streamUrl.isEmpty || nextTrack.id.startsWith('yt_') || nextTrack.id.startsWith('sp_')) {
        final resolved = await AudioStreamService().resolveStreamUrl(nextTrack.id);
        if (resolved != null && resolved.isNotEmpty) {
          streamUrl = resolved;
        }
      }

      if (streamUrl.isNotEmpty) {
        Source nextSource = _buildAudioSource(streamUrl);
        await _standbyPlayer.setSource(nextSource);
      }
    } catch (e) {
      debugPrint('Preloading error: $e');
    }
  }

  void _addToHistory(Track track) {
    if (isNonMusicTrack(track)) return;
    _history.removeWhere((t) => t.id == track.id);
    _history.insert(0, track);
    if (_history.length > 50) {
      _history.removeLast();
    }
    _saveHistory();
  }

  Future<void> toggleSmartCrossfade(bool enabled) async {
    _isSmartCrossfade = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_smart_crossfade', enabled);
    notifyListeners();
  }

  Future<void> setCrossfadeSeconds(int seconds) async {
    _crossfadeSeconds = seconds.clamp(1, 12);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('omni_crossfade_seconds', _crossfadeSeconds);
    notifyListeners();
  }

  Future<void> toggleLossless(bool enabled) async {
    _isLosslessEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_lossless', enabled);
    notifyListeners();
  }

  Future<void> toggleSilenceTrim(bool enabled) async {
    _isSilenceTrimEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_silence_trim', enabled);
    notifyListeners();
  }

  Future<void> toggleGapless(bool enabled) async {
    _isGaplessEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_gapless', enabled);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_currentTrack == null) {
      if (_playlist.isNotEmpty) {
        await playTrack(_playlist.first, playlist: _playlist);
      }
      return;
    }

    if (isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> pause() async {
    await _activePlayer.pause();
    if (_isCrossfading) {
      await _standbyPlayer.pause();
    }
    _playerState = PlayerState.paused;
    _updateMediaNotification();
    notifyListeners();
  }

  Future<void> resume() async {
    if (_currentTrack == null && _playlist.isNotEmpty) {
      await playTrack(_playlist.first, playlist: _playlist);
      return;
    }
    await _activePlayer.resume();
    if (_isCrossfading) {
      await _standbyPlayer.resume();
    }
    _playerState = PlayerState.playing;
    _updateMediaNotification();
    notifyListeners();
  }

  Future<void> seek(Duration newPosition) async {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _isCrossfading = false;
    _standbyPlayer.stop().catchError((_) {});
    _activePlayer.setVolume(_volume.clamp(0.0, 1.0)).catchError((_) {});
    _position = newPosition;
    notifyListeners();
    try {
      await _activePlayer.seek(newPosition);
    } catch (_) {}
    _updateMediaNotification();
  }

  Future<void> seekBy(Duration delta) async {
    Duration target = _position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    await seek(target);
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final res = await _mediaNotificationChannel.invokeMethod('isIgnoringBatteryOptimizations');
      return res == true;
    } catch (_) {
      return true;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _mediaNotificationChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;

    if (_repeatMode == PlaybackRepeatMode.one) {
      await seek(Duration.zero);
      await _activePlayer.resume();
      return;
    }

    int nextIndex;
    if (_isShuffle) {
      nextIndex = Random().nextInt(_playlist.length);
    } else {
      nextIndex = _currentIndex + 1;
      if (nextIndex >= _playlist.length) {
        if (_repeatMode == PlaybackRepeatMode.all) {
          nextIndex = 0;
        } else {
          return;
        }
      }
    }

    _currentIndex = nextIndex;
    await playTrack(_playlist[_currentIndex], playlist: _playlist);
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _playlist.length - 1;
    }

    _currentIndex = prevIndex;
    await playTrack(_playlist[_currentIndex], playlist: _playlist);
  }

  void cycleShuffleMode() {
    if (_shuffleMode == ShuffleMode.off) {
      _shuffleMode = ShuffleMode.normal;
    } else if (_shuffleMode == ShuffleMode.normal) {
      _shuffleMode = ShuffleMode.smart;
      _injectSmartRecommendations();
    } else {
      _shuffleMode = ShuffleMode.off;
    }
    notifyListeners();
  }

  void toggleShuffle() => cycleShuffleMode();

  Future<void> _injectSmartRecommendations() async {
    if (_currentTrack == null) return;
    try {
      final recs = await getRelatedRecommendations(_currentTrack!);
      if (recs.isNotEmpty) {
        final existingIds = _playlist.map((t) => t.id).toSet();
        final toAdd = recs.where((t) => !existingIds.contains(t.id)).take(6).toList();
        if (toAdd.isNotEmpty) {
          _playlist.addAll(toAdd);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Echo Brain + YouTube Music InnerTube Related Radio Engine
  Future<List<Track>> getRelatedRecommendations(Track track) async {
    final list = <Track>[];
    try {
      // Step 1: Official YouTube Music InnerTube `next` radio queue
      if (track.cleanVideoId.length == 11) {
        final radioTracks = await EchoInnerTubeService().getNextRadioTracks(track.cleanVideoId);
        list.addAll(radioTracks);
      }

      // Step 2: Query related tracks by primary artist & album/movie soundtrack
      if (list.length < 6) {
        String query = track.artist;
        if (track.album.isNotEmpty && !track.album.toLowerCase().contains('single')) {
          query = '${track.album} ${track.artist}';
        }
        final hits = await ExtensionEngine().searchAcrossAllSources(query);
        for (final h in hits) {
          if (h.id != track.id && !h.title.toLowerCase().contains(track.title.toLowerCase())) {
            list.add(h.copyWith(isRecommended: true));
          }
        }
      }

      // Step 3: Query high-affinity artist circle and genre hits
      if (list.length < 6) {
        final circleHits = await ExtensionEngine().searchAcrossAllSources('${track.artist} top trending');
        for (final c in circleHits) {
          if (c.id != track.id && !list.any((x) => x.id == c.id)) {
            list.add(c.copyWith(isRecommended: true));
          }
        }
      }
    } catch (_) {}
    return list;
  }

  void toggleRepeat() {
    if (_repeatMode == PlaybackRepeatMode.off) {
      _repeatMode = PlaybackRepeatMode.all;
    } else if (_repeatMode == PlaybackRepeatMode.all) {
      _repeatMode = PlaybackRepeatMode.one;
    } else {
      _repeatMode = PlaybackRepeatMode.off;
    }
    notifyListeners();
  }

  Future<void> setVolume(double newVolume) async {
    _volume = newVolume.clamp(0.0, 1.0);
    if (!_isCrossfading) {
      await _activePlayer.setVolume(_volume);
    }
    notifyListeners();
  }

  Future<void> setMarvelHero(String hero) async {
    _marvelHero = hero;
    final theme = AppTheme(
      mode: _themeMode,
      isDarkMode: _isDarkMode,
      isGlassEnabled: _isGlassEnabled,
      isLiquidGlassEnabled: _isLiquidGlassEnabled,
      marvelHero: hero,
    );
    _activeThemeColor = theme.primary;
    _updateMediaNotification();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('omni_marvel_hero', hero);
    notifyListeners();
  }

  Future<void> toggleJarvisHub(bool val) async {
    _isMarvelJarvisHud = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_marvel_hud', val);

    if (!val) {
      // When turned OFF: reset theme back to default (Dark Planty / oledNeonLime)
      _themeMode = AppThemeMode.oledNeonLime;
      await prefs.setInt('omni_theme_mode', AppThemeMode.oledNeonLime.index);
    } else {
      // When turned ON: activate Creator's Choice / Jarvis theme
      _themeMode = AppThemeMode.marvels;
      await prefs.setInt('omni_theme_mode', AppThemeMode.marvels.index);
    }
    notifyListeners();
  }

  Future<void> toggleMarvelJarvisHud(bool val) => toggleJarvisHub(val);

  bool get isAiDjEnabled => _isAiRemixEnabled;

  Future<void> toggleAiRemix(bool val) async {
    _isAiRemixEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_ai_remix_enabled', val);
    notifyListeners();
  }

  Future<void> toggleAiDj(bool val) => toggleAiRemix(val);

  void updateQueue(List<Track> newQueue) {
    _playlist = List.from(newQueue);
    _currentIndex = _playlist.indexWhere((t) => t.id == _currentTrack?.id);
    if (_currentIndex == -1 && _playlist.isNotEmpty) {
      _currentIndex = 0;
    }
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _playlist.removeAt(index);
    if (_currentIndex >= _playlist.length) {
      _currentIndex = _playlist.isEmpty ? -1 : _playlist.length - 1;
    } else if (index < _currentIndex) {
      _currentIndex--;
    }
    notifyListeners();
  }

  bool isInQueue(String trackId) {
    return _playlist.any((t) => t.id == trackId);
  }

  bool toggleQueue(Track track) {
    final index = _playlist.indexWhere((t) => t.id == track.id);
    if (index != -1) {
      removeFromQueue(index);
      return false; // Removed
    } else {
      _playlist.add(track);
      notifyListeners();
      return true; // Added
    }
  }

  void addToQueue(Track track) {
    if (!_playlist.any((t) => t.id == track.id)) {
      _playlist.add(track);
      notifyListeners();
    }
  }

  void removeFromQueueByTrackId(String trackId) {
    _playlist.removeWhere((t) => t.id == trackId);
    _currentIndex = _playlist.indexWhere((t) => t.id == _currentTrack?.id);
    if (_currentIndex == -1 && _playlist.isNotEmpty) {
      _currentIndex = 0;
    }
    notifyListeners();
  }

  Future<void> stopAndClear() async {
    try {
      await _microFadeOut(_activePlayer);
      await _activePlayer.stop();
      await _standbyPlayer.stop();
    } catch (_) {}
    _currentTrack = null;
    _playerState = PlayerState.stopped;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isBuffering = false;
    _updateMediaNotification();
    notifyListeners();
  }

  Future<void> toggleLike(Track track) async {
    if (_likedTrackIds.contains(track.id)) {
      _likedTrackIds.remove(track.id);
      _likedTracks.removeWhere((t) => t.id == track.id);
    } else {
      _likedTrackIds.add(track.id);
      _likedTracks.insert(0, track);
    }
    await _saveLikedTracks();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PLAYLISTS CRUD & PERSISTENCE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> playPlaylist(String playlistName) async {
    final list = _userPlaylists[playlistName];
    if (list != null && list.isNotEmpty) {
      await playTrack(list.first, playlist: list);
    }
  }

  Future<void> createPlaylist(String name) async {
    final clean = name.trim();
    if (clean.isNotEmpty && !_userPlaylists.containsKey(clean)) {
      _userPlaylists[clean] = [];
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> savePlaylist(String name, List<Track> tracks) async {
    final clean = name.trim();
    if (clean.isNotEmpty) {
      _userPlaylists[clean] = List.from(tracks);
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> deletePlaylist(String name) async {
    if (_userPlaylists.containsKey(name)) {
      _userPlaylists.remove(name);
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> addToPlaylist(String playlistName, Track track) async {
    if (_userPlaylists.containsKey(playlistName)) {
      if (!_userPlaylists[playlistName]!.any((t) => t.id == track.id)) {
        _userPlaylists[playlistName]!.add(track);
        await _savePlaylists();
        notifyListeners();
      }
    }
  }

  Future<void> removeFromPlaylist(String playlistName, String trackId) async {
    if (_userPlaylists.containsKey(playlistName)) {
      _userPlaylists[playlistName]!.removeWhere((t) => t.id == trackId);
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    _userPlaylists.forEach((k, v) {
      map[k] = v.map((t) => t.toJson()).toList();
    });
    await prefs.setString('omni_user_playlists', jsonEncode(map));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROFILE & SETTINGS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    final theme = AppTheme(
      mode: mode,
      isDarkMode: _isDarkMode,
      isGlassEnabled: _isGlassEnabled,
      isLiquidGlassEnabled: _isLiquidGlassEnabled,
      marvelHero: _marvelHero,
    );
    _activeThemeColor = theme.primary;
    _updateMediaNotification();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('omni_theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('omni_user_name', name);
    notifyListeners();
  }

  Future<void> setPlayerStyle(String style) async {
    _playerStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('omni_player_style', style);
    notifyListeners();
  }

  Future<void> toggleCanvas(bool val) async {
    _isCanvasEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_canvas_enabled', val);
    notifyListeners();
  }

  Future<void> toggleOmniBrain(bool val) async {
    _isOmniBrainEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_brain_enabled', val);
    notifyListeners();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (duration == null || duration <= Duration.zero) {
      _sleepTimerRemaining = null;
      notifyListeners();
      return;
    }
    _sleepTimerRemaining = duration;
    notifyListeners();
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_sleepTimerRemaining == null || _sleepTimerRemaining! <= const Duration(seconds: 1)) {
        t.cancel();
        _sleepTimer = null;
        _sleepTimerRemaining = null;
        pause();
        notifyListeners();
      } else {
        _sleepTimerRemaining = _sleepTimerRemaining! - const Duration(seconds: 1);
        notifyListeners();
      }
    });
  }

  void addToQueueNext(Track track) {
    if (_playlist.isEmpty) {
      playTrack(track, playlist: [track]);
      return;
    }
    final insertIdx = (_currentIndex + 1).clamp(0, _playlist.length);
    _playlist.insert(insertIdx, track);
    notifyListeners();
  }

  void appendToQueue(Track track) {
    if (_playlist.isEmpty) {
      playTrack(track, playlist: [track]);
      return;
    }
    if (!_playlist.any((t) => t.id == track.id)) {
      _playlist.add(track);
      notifyListeners();
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= _playlist.length) return;
    final item = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, item);
    if (_currentTrack != null) {
      _currentIndex = _playlist.indexWhere((t) => t.id == _currentTrack!.id);
    }
    notifyListeners();
  }

  Future<void> toggleGlass(bool val) async {
    _isGlassEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_glass_enabled', val);
    notifyListeners();
  }

  Future<void> toggleLiquidGlass(bool val) async {
    _isLiquidGlassEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_liquid_glass', val);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool val) async {
    _isDarkMode = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_dark_mode', val);
    notifyListeners();
  }

  Future<void> toggleDataSaver(bool val) async {
    _isDataSaverEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_data_saver', val);
    notifyListeners();
  }

  Future<void> setCustomColors({Color? primary, Color? bg}) async {
    if (primary != null) _customPrimaryColor = primary;
    if (bg != null) _customBgColor = bg;
    _themeMode = AppThemeMode.custom;
    final prefs = await SharedPreferences.getInstance();
    if (_customPrimaryColor != null) {
      await prefs.setInt('omni_custom_primary', _customPrimaryColor!.toARGB32());
    }
    if (_customBgColor != null) {
      await prefs.setInt('omni_custom_bg', _customBgColor!.toARGB32());
    }
    await prefs.setInt('omni_theme_mode', _themeMode.index);
    notifyListeners();
  }

  void _handleTrackCompleted() {
    if (_isTransitioning) return;
    _isTransitioning = true;

    if (_repeatMode == PlaybackRepeatMode.one) {
      seek(Duration.zero).then((_) {
        _activePlayer.resume().catchError((_) {});
        _isTransitioning = false;
      }).catchError((_) {
        _isTransitioning = false;
      });
    } else {
      next().then((_) {
        _isTransitioning = false;
      }).catchError((_) {
        _isTransitioning = false;
      });
    }
  }

  Future<void> _saveLikedTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_likedTracks.map((t) => t.toJson()).toList());
    await prefs.setString('omni_liked_tracks', json);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_history.map((t) => t.toJson()).toList());
    await prefs.setString('omni_history', json);
  }

  @override
  void dispose() {
    _crossfadeTimer?.cancel();
    _sleepTimer?.cancel();
    _playerA.dispose();
    _playerB.dispose();
    super.dispose();
  }
}
