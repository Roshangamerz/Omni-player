import 'package:flutter_test/flutter_test.dart';
import 'package:omni_player/models/track.dart';
import 'package:omni_player/services/echo_innertube_service.dart';
import 'package:omni_player/services/extension_manager_service.dart';
import 'package:omni_player/services/uptime_service.dart';
import 'package:omni_player/theme/app_theme.dart';

void main() {
  group('Echo Music reverse-engineered models & parsers', () {
    test('Track.parseLrc parses standard and enhanced word-by-word LRC', () {
      const lrc = '''
[ar:Arijit Singh]
[00:10.50]<00:10.50>Tum <00:11.00>hi <00:11.40>ho
[00:15.00]{bg}Ab tum hi ho
''';
      final lines = Track.parseLrc(lrc);
      expect(lines.length, 2);
      expect(lines[0].text, 'Tum hi ho');
      expect(lines[0].words.length, 3);
      expect(lines[0].words[1].text, 'hi');
      expect(lines[1].isBackground, isTrue);
      expect(lines[1].text, 'Ab tum hi ho');
    });

    test('Track.parseLrc parses Paxsenix word-timed lines', () {
      const paxLrc = '''
[00:05.00]{agent:v1}Hello world
<Hello:5.0:5.5|world:5.5:6.2>
''';
      final lines = Track.parseLrc(paxLrc);
      expect(lines.length, 1);
      expect(lines.first.agent, 'v1');
      expect(lines.first.words.length, 2);
      expect(lines.first.words[1].end.inMilliseconds, 6200);
    });

    test('ExtensionManagerService sanitizes server URLs', () {
      final mgr = ExtensionManagerService();
      expect(mgr.sanitizeUrl('example.vercel.app/manifest.json/'), 'https://example.vercel.app');
      expect(mgr.sanitizeUrl('https://320kbps.echomusic.fun/'), 'https://320kbps.echomusic.fun');
    });

    test('UptimeService lists all reverse-engineered services', () {
      final list = UptimeService.initialServices();
      expect(list.length, greaterThanOrEqualTo(12));
      expect(list.any((s) => s.name.contains('BetterLyrics')), isTrue);
      expect(list.any((s) => s.name.contains('ShazamKit')), isTrue);
      expect(list.any((s) => s.name.contains('Tidal')), isTrue);
    });

    test('EchoInnerTubeService minSongDurationSeconds filters short clips', () {
      expect(EchoInnerTubeService.minSongDurationSeconds, 40);
      const shortTrack = Track(
        id: 'yt_short123',
        title: 'Short Ringtone Clip',
        artist: 'Tester',
        duration: Duration(seconds: 25),
        artworkUrl: 'https://img.youtube.com/vi/short123/hqdefault.jpg',
        streamUrl: '',
      );
      const normalTrack = Track(
        id: 'yt_full123',
        title: 'Full Master Track',
        artist: 'Tester',
        duration: Duration(seconds: 215),
        artworkUrl: 'https://img.youtube.com/vi/full123/hqdefault.jpg',
        streamUrl: '',
      );
      expect(shortTrack.duration.inSeconds < EchoInnerTubeService.minSongDurationSeconds, isTrue);
      expect(normalTrack.duration.inSeconds >= EchoInnerTubeService.minSongDurationSeconds, isTrue);
    });

    test('AppThemeMode.midnightLuxe defines luxury champagne and obsidian palette', () {
      final theme = AppTheme(mode: AppThemeMode.midnightLuxe);
      expect(theme.primary.toARGB32(), 0xFFE2B170); // Champagne Gold
      expect(theme.scaffoldBg.toARGB32(), 0xFF07070A); // Deep Obsidian
      expect(theme.premiumAccentGradient.colors.length, greaterThanOrEqualTo(2));
    });
  });
}
