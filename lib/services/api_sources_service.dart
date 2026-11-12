import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiNode {
  final String name;
  final String baseUrl;
  final String notes;
  final bool streamsAudio;
  bool isHealthy;
  int latencyMs;

  ApiNode({
    required this.name,
    required this.baseUrl,
    required this.notes,
    required this.streamsAudio,
    this.isHealthy = true,
    this.latencyMs = -1,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'baseUrl': baseUrl,
        'notes': notes,
        'streamsAudio': streamsAudio,
      };

  factory ApiNode.fromJson(Map<String, dynamic> json) => ApiNode(
        name: json['name'] ?? '',
        baseUrl: json['baseUrl'] ?? '',
        notes: json['notes'] ?? '',
        streamsAudio: json['streamsAudio'] ?? true,
      );
}

class ApiSourcesService extends ChangeNotifier {
  static final ApiSourcesService _instance = ApiSourcesService._internal();
  factory ApiSourcesService() => _instance;
  ApiSourcesService._internal();

  static const String _preferredPipedKey = 'omni_preferred_piped_node';
  static const String _preferredSaavnKey = 'omni_preferred_saavn_node';

  final List<ApiNode> _allSources = [
    ApiNode(
      name: 'JioSaavn Direct Hi-Fi (320kbps Master)',
      baseUrl: 'https://www.jiosaavn.com',
      notes: 'Official ultra-fast regional & global 320k DES lossless stream nodes.',
      streamsAudio: true,
    ),
    ApiNode(
      name: 'JioSaavn Hosted API Node',
      baseUrl: 'https://saavn.dev/api',
      notes: 'High-speed hosted instance of the JioSaavn API for metadata & direct links.',
      streamsAudio: true,
    ),
    ApiNode(
      name: 'YouTube / YT Music (Piped PrivacyDev)',
      baseUrl: 'https://api.piped.privacydev.net',
      notes: 'Instantly returns direct .m4a and .opus audio streams.',
      streamsAudio: true,
    ),
    ApiNode(
      name: 'YouTube (Piped Tokhmi)',
      baseUrl: 'https://pipedapi.tokhmi.xyz',
      notes: 'High-speed backup node for global streams.',
      streamsAudio: true,
    ),
    ApiNode(
      name: 'YouTube (Piped Garuda)',
      baseUrl: 'https://piped-api.garudalinux.org',
      notes: 'High-availability backup instance for streaming.',
      streamsAudio: true,
    ),
    ApiNode(
      name: 'Audius (Decentralized Gateway)',
      baseUrl: 'https://api.audius.co',
      notes: 'Official public gateway. Returns raw 320kbps streams instantly. No keys needed.',
      streamsAudio: true,
    ),
    ApiNode(
      name: 'Apple Music (iTunes Search API)',
      baseUrl: 'https://itunes.apple.com',
      notes: 'Completely free Apple API for metadata, cover art, and previews.',
      streamsAudio: false,
    ),
  ];

  String _currentPipedBase = 'https://api.piped.privacydev.net';
  String _currentSaavnBase = 'https://www.jiosaavn.com';

  List<ApiNode> get sources => List.unmodifiable(_allSources);
  String get currentPipedBase => _currentPipedBase;
  String get currentSaavnBase => _currentSaavnBase;

  List<String> get pipedInstances => [
        'https://api.piped.privacydev.net',
        'https://pipedapi.tokhmi.xyz',
        'https://piped-api.garudalinux.org',
        'https://pipedapi.adminforge.de',
        'https://pipedapi.smnz.de',
      ];

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentPipedBase = prefs.getString(_preferredPipedKey) ?? 'https://api.piped.privacydev.net';
      _currentSaavnBase = prefs.getString(_preferredSaavnKey) ?? 'https://www.jiosaavn.com';
    } catch (_) {}
  }

  Future<void> setPreferredPipedNode(String url) async {
    _currentPipedBase = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredPipedKey, url);
    } catch (_) {}
    notifyListeners();
  }

  /// Check node health and ping in background
  Future<void> benchmarkNodes() async {
    for (final node in _allSources) {
      final sw = Stopwatch()..start();
      try {
        final resp = await http.get(Uri.parse(node.baseUrl)).timeout(const Duration(seconds: 3));
        sw.stop();
        node.latencyMs = sw.elapsedMilliseconds;
        node.isHealthy = resp.statusCode < 500;
      } catch (_) {
        node.latencyMs = -1;
        node.isHealthy = false;
      }
    }
    notifyListeners();
  }
}
