import 'package:flutter_test/flutter_test.dart';
import 'package:omni_player/services/extension_engine.dart';
import 'package:omni_player/services/lyrics_service.dart';
import 'package:omni_player/models/track.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('Search and Lyrics Test', () async {
    final engine = ExtensionEngine();
    await engine.init();

    print('Searching "Cruel Summer"...');
    final tracks = await engine.searchAcrossAllSources('Cruel Summer');
    print('Found ${tracks.length} tracks for Cruel Summer');
    expect(tracks.isNotEmpty, true);

    print('Fetching lyrics for ${tracks.first.title} by ${tracks.first.artist}...');
    final lyrics = await LyricsService.getLyricsForTrack(tracks.first);
    print('Found ${lyrics.length} lyric lines');
    expect(lyrics.isNotEmpty, true);
  });
}
