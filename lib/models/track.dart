class LyricWord {
  final Duration start;
  final Duration end;
  final String text;

  const LyricWord({
    required this.start,
    required this.end,
    required this.text,
  });
}

class LyricLine {
  final Duration time;
  final String text;
  final List<LyricWord> words;
  final bool isBackground;
  final String? agent;
  final String? translation;

  const LyricLine({
    required this.time,
    required this.text,
    this.words = const [],
    this.isBackground = false,
    this.agent,
    this.translation,
  });

  LyricLine copyWith({
    Duration? time,
    String? text,
    List<LyricWord>? words,
    bool? isBackground,
    String? agent,
    String? translation,
  }) {
    return LyricLine(
      time: time ?? this.time,
      text: text ?? this.text,
      words: words ?? this.words,
      isBackground: isBackground ?? this.isBackground,
      agent: agent ?? this.agent,
      translation: translation ?? this.translation,
    );
  }
}

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String artworkUrl;
  final String streamUrl;
  final String sourcePluginId;
  final String? rawLyrics;
  final List<LyricLine> lyrics;
  final bool isRecommended;
  final String? artistId;
  final String? albumId;
  final String? qualityBadge;
  final String? canvasUrl;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    required this.duration,
    required this.artworkUrl,
    required this.streamUrl,
    this.sourcePluginId = 'built-in',
    this.rawLyrics,
    this.lyrics = const [],
    this.isRecommended = false,
    this.artistId,
    this.albumId,
    this.qualityBadge,
    this.canvasUrl,
  });

  String get cleanVideoId {
    if (id.startsWith('yt_')) return id.substring(3);
    if (id.startsWith('ytm_')) return id.substring(4);
    return id;
  }

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? artworkUrl,
    String? streamUrl,
    String? sourcePluginId,
    String? rawLyrics,
    List<LyricLine>? lyrics,
    bool? isRecommended,
    String? artistId,
    String? albumId,
    String? qualityBadge,
    String? canvasUrl,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      sourcePluginId: sourcePluginId ?? this.sourcePluginId,
      rawLyrics: rawLyrics ?? this.rawLyrics,
      lyrics: lyrics ?? this.lyrics,
      isRecommended: isRecommended ?? this.isRecommended,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
      qualityBadge: qualityBadge ?? this.qualityBadge,
      canvasUrl: canvasUrl ?? this.canvasUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': duration.inMilliseconds,
      'artworkUrl': artworkUrl,
      'streamUrl': streamUrl,
      'sourcePluginId': sourcePluginId,
      'rawLyrics': rawLyrics,
      if (artistId != null) 'artistId': artistId,
      if (albumId != null) 'albumId': albumId,
      if (qualityBadge != null) 'qualityBadge': qualityBadge,
      if (canvasUrl != null) 'canvasUrl': canvasUrl,
    };
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final rawLyrics = json['rawLyrics'] as String?;
    return Track(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Track',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String? ?? '',
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 180000),
      artworkUrl: json['artworkUrl'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
      sourcePluginId: json['sourcePluginId'] as String? ?? 'built-in',
      rawLyrics: rawLyrics,
      lyrics: rawLyrics != null ? parseLrc(rawLyrics) : const [],
      artistId: json['artistId'] as String?,
      albumId: json['albumId'] as String?,
      qualityBadge: json['qualityBadge'] as String?,
      canvasUrl: json['canvasUrl'] as String?,
    );
  }

  /// Parses standard LRC, enhanced LRC (<mm:ss.xx>word), and Paxsenix/Echo <word:start:end|...> lines
  static List<LyricLine> parseLrc(String lrcContent) {
    final lines = lrcContent.split('\n');
    final rawParsed = <LyricLine>[];
    final tagRegex = RegExp(r'\[(\d{1,2}):(\d{1,2}(?:\.\d+)?)\]');
    final wordTagRegex = RegExp(r'<(\d{1,2}):(\d{1,2}(?:\.\d+)?)>([^<]+)');

    for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx].trim();
      if (line.isEmpty) continue;

      if (RegExp(r'^\[(ar|ti|al|by|offset|length|re|ve):', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      // Skip standalone Paxsenix <word:start:end|...> lines (attached to previous line below)
      if (line.startsWith('<') && line.endsWith('>') && line.contains(':') && !line.contains('[')) {
        continue;
      }

      final matches = tagRegex.allMatches(line).toList();
      if (matches.isEmpty) continue;

      var body = line.replaceAll(tagRegex, '').trim();
      if (body.isEmpty) continue;

      bool isBg = false;
      String? agent;
      if (body.contains('{bg}')) {
        isBg = true;
        body = body.replaceAll('{bg}', '').trim();
      }
      final agentMatch = RegExp(r'\{agent:(v\d+)\}').firstMatch(body);
      if (agentMatch != null) {
        agent = agentMatch.group(1);
        body = body.replaceAll(agentMatch.group(0)!, '').trim();
      }

      // Check inline <mm:ss.xx> enhanced LRC word timings
      final parsedWords = <LyricWord>[];
      final inlineWordMatches = wordTagRegex.allMatches(body).toList();
      if (inlineWordMatches.isNotEmpty) {
        for (int w = 0; w < inlineWordMatches.length; w++) {
          final m = inlineWordMatches[w];
          final min = int.tryParse(m.group(1) ?? '0') ?? 0;
          final sec = double.tryParse(m.group(2) ?? '0') ?? 0.0;
          final startMs = (min * 60 * 1000) + (sec * 1000).toInt();
          int endMs = startMs + 500;
          if (w + 1 < inlineWordMatches.length) {
            final nm = inlineWordMatches[w + 1];
            final nMin = int.tryParse(nm.group(1) ?? '0') ?? 0;
            final nSec = double.tryParse(nm.group(2) ?? '0') ?? 0.0;
            endMs = (nMin * 60 * 1000) + (nSec * 1000).toInt();
          }
          final wText = (m.group(3) ?? '').trim();
          if (wText.isNotEmpty) {
            parsedWords.add(LyricWord(
              start: Duration(milliseconds: startMs),
              end: Duration(milliseconds: endMs > startMs ? endMs : startMs + 350),
              text: wText,
            ));
          }
        }
        body = body.replaceAll(RegExp(r'<\d{1,2}:\d{1,2}(?:\.\d+)?>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      } else if (lineIdx + 1 < lines.length) {
        // Check next line for Echo/Paxsenix <word:startSec:endSec|...>
        final nextLine = lines[lineIdx + 1].trim();
        if (nextLine.startsWith('<') && nextLine.endsWith('>') && nextLine.contains('|')) {
          final inner = nextLine.substring(1, nextLine.length - 1);
          for (final token in inner.split('|')) {
            final parts = token.split(':');
            if (parts.length >= 3) {
              final endSec = double.tryParse(parts.last);
              final startSec = double.tryParse(parts[parts.length - 2]);
              final wordText = parts.sublist(0, parts.length - 2).join(':').trim();
              if (startSec != null && endSec != null && wordText.isNotEmpty) {
                parsedWords.add(LyricWord(
                  start: Duration(milliseconds: (startSec * 1000).round()),
                  end: Duration(milliseconds: (endSec * 1000).round()),
                  text: wordText,
                ));
              }
            }
          }
        }
      }

      if (body.isEmpty) continue;

      for (final m in matches) {
        final min = int.tryParse(m.group(1) ?? '0') ?? 0;
        final secDouble = double.tryParse(m.group(2) ?? '0') ?? 0.0;
        final totalMs = (min * 60 * 1000) + (secDouble * 1000).toInt();
        rawParsed.add(LyricLine(
          time: Duration(milliseconds: totalMs),
          text: body,
          words: parsedWords,
          isBackground: isBg,
          agent: agent,
        ));
      }
    }

    rawParsed.sort((a, b) => a.time.compareTo(b.time));

    final result = <LyricLine>[];
    for (int i = 0; i < rawParsed.length; i++) {
      result.add(rawParsed[i]);
      if (i < rawParsed.length - 1) {
        final currentLine = rawParsed[i];
        final nextLine = rawParsed[i + 1];
        final gapMs = nextLine.time.inMilliseconds - currentLine.time.inMilliseconds;
        final words = currentLine.text.split(RegExp(r'\s+')).length;
        final estimatedSingingMs = (words * 380 + 800).clamp(2000, 6000);

        if (gapMs > estimatedSingingMs + 4500) {
          final pauseStartMs = currentLine.time.inMilliseconds + estimatedSingingMs + 500;
          result.add(LyricLine(
            time: Duration(milliseconds: pauseStartMs),
            text: '♪  •  •  •  ♪',
          ));
        }
      }
    }

    return result;
  }
}

/// Represents an Album, Movie Soundtrack, Series OST, Artist Discography, or Playlist
class AudioCollection {
  final String id;
  final String title;
  final String creator;
  final String type; // 'soundtrack', 'album', 'playlist', 'artist'
  final String artworkUrl;
  final List<Track> tracks;
  final String? params;

  const AudioCollection({
    required this.id,
    required this.title,
    required this.creator,
    required this.type,
    required this.artworkUrl,
    required this.tracks,
    this.params,
  });

  int get trackCount => tracks.length;
}
