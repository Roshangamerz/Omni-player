import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

class LocalMusicService extends ChangeNotifier {
  static final LocalMusicService _instance = LocalMusicService._internal();
  factory LocalMusicService() => _instance;
  LocalMusicService._internal() {
    _loadCachedLocalTracks();
  }

  static const MethodChannel _channel = MethodChannel('com.omniplayer.music/media_notification');

  final List<Track> _localTracks = [];
  bool _isScanning = false;
  bool _hasPermission = false;
  DateTime? _lastScanTime;

  List<Track> get localTracks => List.unmodifiable(_localTracks);
  bool get isScanning => _isScanning;
  bool get hasPermission => _hasPermission;
  DateTime? get lastScanTime => _lastScanTime;

  static const supportedAudioExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.wma',
  };

  Future<void> _loadCachedLocalTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('omni_local_tracks_cache');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _localTracks.clear();
        for (final item in list) {
          final t = Track.fromJson(item as Map<String, dynamic>);
          final lower = '${t.title} ${t.artist} ${t.streamUrl}'.toLowerCase();
          if (lower.contains('tutorial') ||
              lower.contains('how to') ||
              lower.contains('storage full') ||
              lower.contains('phone hanging') ||
              lower.contains('transfer data') ||
              lower.contains('problem solve') ||
              lower.contains('technical aqeel') ||
              lower.contains('whatsapp') ||
              lower.contains('aud-') ||
              lower.contains('ptt-')) {
            continue;
          }
          // Verify file still exists on disk
          final filePath = t.streamUrl.replaceFirst('file://', '');
          if (File(filePath).existsSync()) {
            _localTracks.add(t);
          }
        }
        await _saveLocalTracksCache();
        final lastScanMs = prefs.getInt('omni_last_scan_time');
        if (lastScanMs != null) {
          _lastScanTime = DateTime.fromMillisecondsSinceEpoch(lastScanMs);
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveLocalTracksCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _localTracks.map((t) => t.toJson()).toList();
      await prefs.setString('omni_local_tracks_cache', jsonEncode(jsonList));
      if (_lastScanTime != null) {
        await prefs.setInt('omni_last_scan_time', _lastScanTime!.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  /// Request permissions and scan local device storage for music tracks
  Future<bool> scanLocalLibrary() async {
    _isScanning = true;
    notifyListeners();

    try {
      bool permissionGranted = false;
      if (Platform.isAndroid) {
        final audioStatus = await Permission.audio.request();
        if (audioStatus.isGranted) {
          permissionGranted = true;
        } else {
          final storageStatus = await Permission.storage.request();
          permissionGranted = storageStatus.isGranted;
        }
      } else {
        final status = await Permission.storage.request();
        permissionGranted = status.isGranted;
      }

      _hasPermission = permissionGranted;

      // Common device music directories on Android and other OS
      final candidatePaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Audio',
        '/storage/emulated/0/Podcasts',
        '/storage/emulated/0/Recordings',
        '/sdcard/Music',
        '/sdcard/Download',
      ];

      final scannedFiles = <File>[];

      for (final dirPath in candidatePaths) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          try {
            await for (final entity in dir.list(recursive: true, followLinks: false)) {
              if (entity is File) {
                final lower = entity.path.toLowerCase();
                if (supportedAudioExtensions.any((ext) => lower.endsWith(ext))) {
                  scannedFiles.add(entity);
                }
              }
            }
          } catch (_) {}
        }
      }

      for (final file in scannedFiles) {
        final lower = file.path.toLowerCase();
        // Skip WhatsApp audio, voice notes, call recordings, and video tutorials
        if (lower.contains('whatsapp') ||
            lower.contains('aud-') ||
            lower.contains('ptt-') ||
            lower.contains('call_') ||
            lower.contains('voice_') ||
            lower.contains('tutorial') ||
            lower.contains('how to') ||
            lower.contains('storage full') ||
            lower.contains('phone hanging') ||
            lower.contains('transfer data') ||
            lower.contains('problem solve')) {
          continue;
        }

        final track = _parseTrackFromFile(file);
        if (!_localTracks.any((t) => t.streamUrl == track.streamUrl)) {
          _localTracks.add(track);
        }
      }

      _lastScanTime = DateTime.now();
      await _saveLocalTracksCache();
    } catch (e) {
      debugPrint('LocalMusicService scan error: $e');
    }

    _isScanning = false;
    notifyListeners();
    return _localTracks.isNotEmpty;
  }

  /// Let user select specific audio files from device file picker
  Future<int> pickAudioFiles() async {
    try {
      final List<dynamic>? paths = await _channel.invokeMethod('pickAudioFiles');
      if (paths != null && paths.isNotEmpty) {
        int added = 0;
        for (final p in paths) {
          final filePath = p.toString();
          if (filePath.isNotEmpty) {
            final file = File(filePath);
            if (await file.exists()) {
              final track = _parseTrackFromFile(file);
              if (!_localTracks.any((t) => t.streamUrl == track.streamUrl)) {
                _localTracks.insert(0, track);
                added++;
              }
            }
          }
        }
        if (added > 0) {
          _lastScanTime = DateTime.now();
          await _saveLocalTracksCache();
          notifyListeners();
        }
        return added;
      }
    } catch (e) {
      debugPrint('Error picking audio files: $e');
    }
    return 0;
  }

  /// Let user pick a specific folder on their phone to index
  Future<int> pickFolderAndScan() async {
    try {
      final String? dirPath = await _channel.invokeMethod('pickAudioFolder');
      if (dirPath != null && dirPath.isNotEmpty) {
        return await scanDirectory(dirPath);
      }
    } catch (e) {
      debugPrint('Error picking folder: $e');
    }
    return 0;
  }

  /// Add individual audio file path
  void addFilePath(String path) {
    if (path.isEmpty) return;
    final file = File(path);
    final track = _parseTrackFromFile(file);

    if (!_localTracks.any((t) => t.streamUrl == track.streamUrl)) {
      _localTracks.insert(0, track);
      _saveLocalTracksCache();
      notifyListeners();
    }
  }

  /// Scan a specific custom directory path
  Future<int> scanDirectory(String dirPath) async {
    int addedCount = 0;
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final lower = entity.path.toLowerCase();
            if (supportedAudioExtensions.any((ext) => lower.endsWith(ext))) {
              final track = _parseTrackFromFile(entity);
              if (!_localTracks.any((t) => t.streamUrl == track.streamUrl)) {
                _localTracks.insert(0, track);
                addedCount++;
              }
            }
          }
        }
        if (addedCount > 0) {
          _lastScanTime = DateTime.now();
          await _saveLocalTracksCache();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('LocalMusicService scanDirectory error: $e');
    }
    return addedCount;
  }

  Track _parseTrackFromFile(File file) {
    final path = file.path;
    final filename = path.split(Platform.pathSeparator).last;
    final cleanName = filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');

    String title = cleanName;
    String artist = 'Device Music';
    String album = 'Local Audio';

    // Parse "Artist - Title" or "01 - Artist - Title" patterns
    if (cleanName.contains(' - ')) {
      final parts = cleanName.split(' - ');
      if (parts.length == 2) {
        artist = parts[0].trim().replaceAll(RegExp(r'^\d+\.?\s*'), '');
        title = parts[1].trim();
      } else if (parts.length >= 3) {
        artist = parts[1].trim();
        title = parts.sublist(2).join(' - ').trim();
      }
    } else if (cleanName.contains(' _ ')) {
      final parts = cleanName.split(' _ ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts[1].trim();
      }
    }

    // Use parent folder name as album if valid
    final parentDir = file.parent.path.split(Platform.pathSeparator).last;
    if (parentDir.isNotEmpty && parentDir != '0' && parentDir != 'emulated' && parentDir != 'Music') {
      album = parentDir;
    }

    return Track(
      id: 'local_${path.hashCode.abs()}',
      title: title.isNotEmpty ? title : 'Local Track',
      artist: artist.isNotEmpty ? artist : 'Device Storage',
      album: album,
      duration: const Duration(seconds: 210),
      artworkUrl: '',
      streamUrl: 'file://$path',
      sourcePluginId: 'Local Files',
    );
  }
}
