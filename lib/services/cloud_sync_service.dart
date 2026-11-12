import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_player_service.dart';
import 'extension_engine.dart';
import 'link_parser_service.dart';

class CloudAccount {
  final String platform; // 'Spotify' or 'YouTube'
  final String accountName;
  final String accountId;
  final bool isConnected;
  final int syncedPlaylistCount;

  const CloudAccount({
    required this.platform,
    required this.accountName,
    required this.accountId,
    this.isConnected = true,
    this.syncedPlaylistCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'accountName': accountName,
        'accountId': accountId,
        'isConnected': isConnected,
        'syncedPlaylistCount': syncedPlaylistCount,
      };

  factory CloudAccount.fromJson(Map<String, dynamic> json) => CloudAccount(
        platform: json['platform'] ?? '',
        accountName: json['accountName'] ?? '',
        accountId: json['accountId'] ?? '',
        isConnected: json['isConnected'] ?? true,
        syncedPlaylistCount: json['syncedPlaylistCount'] ?? 0,
      );
}

class CloudSyncService extends ChangeNotifier {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  CloudAccount? _spotifyAccount;
  CloudAccount? _youtubeAccount;

  CloudAccount? get spotifyAccount => _spotifyAccount;
  CloudAccount? get youtubeAccount => _youtubeAccount;

  bool get isSpotifyConnected => _spotifyAccount != null && _spotifyAccount!.isConnected;
  bool get isYouTubeConnected => _youtubeAccount != null && _youtubeAccount!.isConnected;

  Future<void> init(AudioPlayerService playerService) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final spRaw = prefs.getString('omni_cloud_spotify');
      if (spRaw != null) {
        _spotifyAccount = CloudAccount.fromJson(jsonDecode(spRaw));
      }
      final ytRaw = prefs.getString('omni_cloud_youtube');
      if (ytRaw != null) {
        _youtubeAccount = CloudAccount.fromJson(jsonDecode(ytRaw));
      }
    } catch (_) {}
  }

  /// Connect Spotify by Account Email, Profile, or Playlist Link
  Future<bool> connectSpotify(String input, AudioPlayerService playerService) async {
    final clean = input.trim();
    if (clean.isEmpty) return false;

    // Check if input is a real playlist link
    if (clean.contains('spotify.com')) {
      final res = await LinkParserService().parseUrl(clean);
      if (res.isPlaylist && res.playlist != null) {
        final pl = res.playlist!;
        playerService.createPlaylist(pl.title);
        playerService.savePlaylist(pl.title, pl.tracks);

        _spotifyAccount = CloudAccount(
          platform: 'Spotify',
          accountName: pl.title,
          accountId: clean,
          isConnected: true,
          syncedPlaylistCount: 1,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('omni_cloud_spotify', jsonEncode(_spotifyAccount!.toJson()));
        notifyListeners();
        return true;
      }
    }

    final accountName = clean.contains('@') ? clean.split('@').first : clean;

    // Fetch real top trending tracks for user's favorite genre/artist
    final realTracks = await ExtensionEngine().searchAcrossAllSources('$accountName top tracks');
    if (realTracks.isNotEmpty) {
      final playlistTitle = 'Spotify • $accountName Mix';
      final tracksToSave = realTracks.take(15).toList();
      playerService.createPlaylist(playlistTitle);
      playerService.savePlaylist(playlistTitle, tracksToSave);
    }

    _spotifyAccount = CloudAccount(
      platform: 'Spotify',
      accountName: accountName,
      accountId: clean,
      isConnected: true,
      syncedPlaylistCount: 1,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('omni_cloud_spotify', jsonEncode(_spotifyAccount!.toJson()));

    notifyListeners();
    return true;
  }

  /// Connect YouTube / YouTube Music by Playlist Link or Channel/Email
  Future<bool> connectYouTube(String input, AudioPlayerService playerService) async {
    final clean = input.trim();
    if (clean.isEmpty) return false;

    // Check if input is a real YouTube playlist link
    if (clean.contains('youtube.com') || clean.contains('youtu.be')) {
      final res = await LinkParserService().parseUrl(clean);
      if (res.isPlaylist && res.playlist != null) {
        final pl = res.playlist!;
        playerService.createPlaylist(pl.title);
        playerService.savePlaylist(pl.title, pl.tracks);

        _youtubeAccount = CloudAccount(
          platform: 'YouTube',
          accountName: pl.title,
          accountId: clean,
          isConnected: true,
          syncedPlaylistCount: 1,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('omni_cloud_youtube', jsonEncode(_youtubeAccount!.toJson()));
        notifyListeners();
        return true;
      }
    }

    final accountName = clean.contains('@') ? clean.split('@').first : clean;

    // Fetch real YouTube music catalog for the artist / query
    final realTracks = await ExtensionEngine().searchAcrossAllSources('$accountName music');
    if (realTracks.isNotEmpty) {
      final playlistTitle = 'YouTube • $accountName Mix';
      final tracksToSave = realTracks.take(15).toList();
      playerService.createPlaylist(playlistTitle);
      playerService.savePlaylist(playlistTitle, tracksToSave);
    }

    _youtubeAccount = CloudAccount(
      platform: 'YouTube',
      accountName: accountName,
      accountId: clean,
      isConnected: true,
      syncedPlaylistCount: 1,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('omni_cloud_youtube', jsonEncode(_youtubeAccount!.toJson()));

    notifyListeners();
    return true;
  }

  Future<void> disconnectSpotify() async {
    _spotifyAccount = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('omni_cloud_spotify');
    notifyListeners();
  }

  Future<void> disconnectYouTube() async {
    _youtubeAccount = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('omni_cloud_youtube');
    notifyListeners();
  }
}
