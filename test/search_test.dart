import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_player/services/extension_engine.dart';
import 'package:omni_player/services/lyrics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  HttpOverrides.global = _RealHttpOverrides();
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('Search and Lyrics Test', () async {
    final engine = ExtensionEngine();
    await engine.init();

    final tracks = await engine.searchAcrossAllSources('Cruel Summer');
    if (tracks.isNotEmpty) {
      final lyrics = await LyricsService.getLyricsForTrack(tracks.first);
      expect(lyrics.isNotEmpty, true);
    }
  });
}
