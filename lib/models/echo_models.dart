import 'track.dart';

class EchoMoodChip {
  final String title;
  final String? browseId;
  final String? params;

  const EchoMoodChip({
    required this.title,
    this.browseId,
    this.params,
  });
}

class EchoHomeSection {
  final String title;
  final String? subtitle;
  final String? browseId;
  final String? params;
  final List<Track> tracks;
  final List<AudioCollection> collections;

  const EchoHomeSection({
    required this.title,
    this.subtitle,
    this.browseId,
    this.params,
    this.tracks = const [],
    this.collections = const [],
  });

  EchoHomeSection copyWith({
    String? title,
    String? subtitle,
    String? browseId,
    String? params,
    List<Track>? tracks,
    List<AudioCollection>? collections,
  }) {
    return EchoHomeSection(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      browseId: browseId ?? this.browseId,
      params: params ?? this.params,
      tracks: tracks ?? this.tracks,
      collections: collections ?? this.collections,
    );
  }
}

class EchoHomeFeed {
  final List<EchoMoodChip> chips;
  final List<EchoHomeSection> sections;

  const EchoHomeFeed({
    this.chips = const [],
    this.sections = const [],
  });
}

class EchoMoodGenreItem {
  final String title;
  final int stripeColorValue;
  final String browseId;
  final String? params;

  const EchoMoodGenreItem({
    required this.title,
    required this.stripeColorValue,
    required this.browseId,
    this.params,
  });
}

class EchoExploreData {
  final List<AudioCollection> newReleaseAlbums;
  final List<EchoMoodGenreItem> moodsAndGenres;
  final List<EchoHomeSection> chartSections;

  const EchoExploreData({
    this.newReleaseAlbums = const [],
    this.moodsAndGenres = const [],
    this.chartSections = const [],
  });
}

class AppleTopEntry {
  final int rank;
  final String title;
  final String artist;
  final String artworkUrl;
  final String appleUrl;

  const AppleTopEntry({
    required this.rank,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.appleUrl,
  });
}

class CanvasArtworkResult {
  final String? videoUrl;
  final String? staticUrl;
  final String provider;

  const CanvasArtworkResult({
    this.videoUrl,
    this.staticUrl,
    required this.provider,
  });

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
}

class MusicDnaInfo {
  final String title;
  final String artist;
  final String album;
  final String aboutSong;
  final String artistBio;
  final String? geniusUrl;

  const MusicDnaInfo({
    required this.title,
    required this.artist,
    required this.album,
    required this.aboutSong,
    required this.artistBio,
    this.geniusUrl,
  });
}

class ShazamMatchResult {
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String shazamUrl;
  final String genre;
  final String releaseYear;
  final DateTime timestamp;

  const ShazamMatchResult({
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.shazamUrl,
    this.genre = '',
    this.releaseYear = '',
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'album': album,
        'artworkUrl': artworkUrl,
        'shazamUrl': shazamUrl,
        'genre': genre,
        'releaseYear': releaseYear,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ShazamMatchResult.fromJson(Map<String, dynamic> json) => ShazamMatchResult(
        title: json['title'] as String? ?? 'Unknown Song',
        artist: json['artist'] as String? ?? 'Unknown Artist',
        album: json['album'] as String? ?? '',
        artworkUrl: json['artworkUrl'] as String? ?? '',
        shazamUrl: json['shazamUrl'] as String? ?? '',
        genre: json['genre'] as String? ?? '',
        releaseYear: json['releaseYear'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

class ExtensionAddon {
  final String id;
  final String name;
  final String url;
  final bool enabled;

  const ExtensionAddon({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
  });

  ExtensionAddon copyWith({String? id, String? name, String? url, bool? enabled}) {
    return ExtensionAddon(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'enabled': enabled,
      };

  factory ExtensionAddon.fromJson(Map<String, dynamic> json) => ExtensionAddon(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Custom Addon',
        url: json['url'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
      );
}

class WeatherSnapshot {
  final String city;
  final double tempC;
  final int weatherCode;
  final bool isDay;
  final String moodLabel;
  final String recommendedQuery;

  const WeatherSnapshot({
    required this.city,
    required this.tempC,
    required this.weatherCode,
    required this.isDay,
    required this.moodLabel,
    required this.recommendedQuery,
  });
}

class ServiceHealthStatus {
  final String name;
  final String category;
  final String url;
  final List<String> fallbackUrls;
  final bool isChecking;
  final bool isOnline;
  final int? latencyMs;

  const ServiceHealthStatus({
    required this.name,
    required this.category,
    required this.url,
    this.fallbackUrls = const [],
    this.isChecking = true,
    this.isOnline = false,
    this.latencyMs,
  });

  ServiceHealthStatus copyWith({
    bool? isChecking,
    bool? isOnline,
    int? latencyMs,
  }) {
    return ServiceHealthStatus(
      name: name,
      category: category,
      url: url,
      fallbackUrls: fallbackUrls,
      isChecking: isChecking ?? this.isChecking,
      isOnline: isOnline ?? this.isOnline,
      latencyMs: latencyMs,
    );
  }
}
