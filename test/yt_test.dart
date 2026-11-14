import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:omni_player/services/extension_engine.dart';

void main() {
  test('Test YouTube link to 320kbps stream matching pipeline', () async {
    final videoIds = [
      'dQw4w9WgXcQ', // Never Gonna Give You Up
      'rrmDvnwPlKY', // Raftaar - NO CHINA
      'kJQP7kiw5Fk', // Despacito
    ];

    final saavn = JioSaavnMusicSource();

    for (final id in videoIds) {
      final sw = Stopwatch()..start();
      final url = 'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$id&format=json';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final title = data['title'] as String;
      final author = data['author_name'] as String;

      print('Original YT Video: "$title" by "$author"');

      // Clean title for search (remove (Official Music Video), (4K Remaster), ft., etc.)
      final cleanTitle = title
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .replaceAll(RegExp(r'\|.*'), '')
          .replaceAll('ft.', '')
          .replaceAll('feat.', '')
          .trim();

      print('Cleaned Query: "$cleanTitle"');

      final searchHits = await saavn.searchTracks('$cleanTitle $author');
      print('Saavn hits: ${searchHits.length}');
      if (searchHits.isNotEmpty) {
        final top = searchHits.first;
        print(' -> Matched Saavn 320k: "${top.title}" by "${top.artist}"');
        print(' -> Stream URL: ${top.streamUrl.substring(0, 50)}...');
        expect(top.streamUrl.startsWith('http'), true);
        print(' -> Match duration: ${sw.elapsedMilliseconds}ms');
      }
    }
  });
}
