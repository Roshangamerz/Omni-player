import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

class DownloadItem {
  final Track track;
  final String localFilePath;
  final double progress;
  final bool isCompleted;
  final bool isFailed;

  const DownloadItem({
    required this.track,
    required this.localFilePath,
    this.progress = 0.0,
    this.isCompleted = false,
    this.isFailed = false,
  });
}

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  static const String _savedDownloadsKey = 'omni_downloaded_tracks_v1';
  final Map<String, Track> _downloadedTracks = {};
  final Map<String, double> _activeDownloads = {};
  String? _downloadDirectoryPath;

  List<Track> get downloadedTracks => _downloadedTracks.values.toList();
  Map<String, double> get activeDownloads => Map.unmodifiable(_activeDownloads);

  bool isDownloaded(String trackId) => _downloadedTracks.containsKey(trackId);
  bool isDownloading(String trackId) => _activeDownloads.containsKey(trackId);
  double getProgress(String trackId) => _activeDownloads[trackId] ?? 0.0;
  String? getLocalPath(String trackId) => _downloadedTracks[trackId]?.streamUrl;

  Future<void> init() async {
    try {
      // Find app storage directory
      final baseDir = Directory('/sdcard/Music/OmniPlayer');
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }
      _downloadDirectoryPath = baseDir.path;
    } catch (_) {
      try {
        final fallbackDir = Directory.systemTemp;
        _downloadDirectoryPath = fallbackDir.path;
      } catch (_) {}
    }

    // Load saved downloads registry from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_savedDownloadsKey);
      if (list != null) {
        for (final itemStr in list) {
          try {
            final json = jsonDecode(itemStr);
            final track = Track.fromJson(json);
            // Verify local file exists
            if (track.streamUrl.startsWith('/') && File(track.streamUrl).existsSync()) {
              _downloadedTracks[track.id] = track;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Download an individual track
  Future<bool> downloadTrack(Track track) async {
    if (isDownloaded(track.id) || isDownloading(track.id)) return true;

    _activeDownloads[track.id] = 0.05;
    notifyListeners();

    try {
      final cleanTitle = track.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final cleanArtist = track.artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final dir = _downloadDirectoryPath ?? Directory.systemTemp.path;
      final filePath = '$dir/${cleanArtist}_$cleanTitle.mp3';
      final file = File(filePath);

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(track.streamUrl));
      final response = await client.send(request);

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 5000000;
        int receivedBytes = 0;
        final sink = file.openWrite();

        await response.stream.listen((chunk) {
          receivedBytes += chunk.length;
          sink.add(chunk);
          _activeDownloads[track.id] = (receivedBytes / totalBytes).clamp(0.05, 0.99);
          notifyListeners();
        }).asFuture();

        await sink.flush();
        await sink.close();

        final downloadedTrack = track.copyWith(
          streamUrl: filePath,
        );

        _downloadedTracks[track.id] = downloadedTrack;
        _activeDownloads.remove(track.id);
        await _saveRegistry();
        notifyListeners();
        return true;
      } else {
        _activeDownloads.remove(track.id);
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Download failed for ${track.title}: $e');
      _activeDownloads.remove(track.id);
      notifyListeners();
      return false;
    }
  }

  /// 1-Click Batch Playlist Downloader
  Future<void> downloadPlaylist(String playlistName, List<Track> tracks) async {
    for (final track in tracks) {
      if (!isDownloaded(track.id)) {
        await downloadTrack(track);
      }
    }
  }

  /// Remove a downloaded track
  Future<void> removeDownload(String trackId) async {
    final track = _downloadedTracks.remove(trackId);
    if (track != null) {
      try {
        final file = File(track.streamUrl);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      await _saveRegistry();
      notifyListeners();
    }
  }

  Future<void> _saveRegistry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _downloadedTracks.values.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_savedDownloadsKey, list);
    } catch (_) {}
  }
}
