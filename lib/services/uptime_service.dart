import 'package:http/http.dart' as http;
import '../models/echo_models.dart';

/// Reverse-engineered Echo Music Uptime Monitor (UptimeScreen.kt)
class UptimeService {
  static List<ServiceHealthStatus> initialServices() => const [
        ServiceHealthStatus(
          name: 'YouTube Music InnerTube',
          category: 'Music Streaming',
          url: 'https://music.youtube.com',
        ),
        ServiceHealthStatus(
          name: 'JioSaavn 320k Direct',
          category: 'Music Streaming',
          url: 'https://www.jiosaavn.com',
        ),
        ServiceHealthStatus(
          name: 'Tidal Video Canvas',
          category: 'Canvas & Motion',
          url: 'https://api.tidal.com/v1/',
        ),
        ServiceHealthStatus(
          name: 'EchoMusic Canvas',
          category: 'Canvas & Motion',
          url: 'https://canvas.echomusic.fun/canvas.json',
        ),
        ServiceHealthStatus(
          name: 'BetterLyrics (TTML)',
          category: 'Lyrics Providers',
          url: 'https://lyrics-api.boidu.dev',
        ),
        ServiceHealthStatus(
          name: 'YouLyPlus (KPoe)',
          category: 'Lyrics Providers',
          url: 'https://lyricsplus.prjktla.my.id',
          fallbackUrls: [
            'https://lyricsplus.atomix.one',
            'https://lyricsplus.binimum.org',
            'https://lyricsplus.prjktla.workers.dev',
          ],
        ),
        ServiceHealthStatus(
          name: 'SimpMusic Lyrics',
          category: 'Lyrics Providers',
          url: 'https://api-lyrics.simpmusic.org',
        ),
        ServiceHealthStatus(
          name: 'Paxsenix Apple Lyrics',
          category: 'Lyrics Providers',
          url: 'https://lyrics.paxsenix.org',
        ),
        ServiceHealthStatus(
          name: 'LRCLib',
          category: 'Lyrics Providers',
          url: 'https://lrclib.net',
        ),
        ServiceHealthStatus(
          name: 'Unison Lyrics',
          category: 'Lyrics Providers',
          url: 'https://unison.boidu.dev',
        ),
        ServiceHealthStatus(
          name: 'KuGou Lyrics',
          category: 'Lyrics Providers',
          url: 'https://lyrics.kugou.com',
        ),
        ServiceHealthStatus(
          name: 'Apple Music AMP & RSS',
          category: 'Discovery & DNA',
          url: 'https://amp-api.music.apple.com',
        ),
        ServiceHealthStatus(
          name: 'Omni Find (ShazamKit)',
          category: 'Discovery & DNA',
          url: 'https://amp.shazam.com',
        ),
        ServiceHealthStatus(
          name: 'Genius & Wikipedia DNA',
          category: 'Discovery & DNA',
          url: 'https://genius.com',
        ),
      ];

  static Future<ServiceHealthStatus> checkService(ServiceHealthStatus service) async {
    final urls = [service.url, ...service.fallbackUrls];
    for (final u in urls) {
      try {
        final sw = Stopwatch()..start();
        final resp = await http.head(Uri.parse(u)).timeout(const Duration(seconds: 5));
        sw.stop();
        if (resp.statusCode >= 200 && resp.statusCode <= 405) {
          return service.copyWith(
            isChecking: false,
            isOnline: true,
            latencyMs: sw.elapsedMilliseconds,
          );
        }
      } catch (_) {}
    }
    return service.copyWith(isChecking: false, isOnline: false, latencyMs: null);
  }
}
