import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/echo_models.dart';
import '../models/track.dart';

/// Reverse-engineered Echo Music Custom Extension Addon Protocol (ExtensionManager.kt)
/// Supports 320kbps & Lossless FLAC extension servers implementing /manifest.json, /search, /stream/:id
class ExtensionManagerService extends ChangeNotifier {
  static final ExtensionManagerService _instance = ExtensionManagerService._internal();
  factory ExtensionManagerService() => _instance;
  ExtensionManagerService._internal();

  static const String _addonsKey = 'echo_extension_addons_v1';
  static const String _preferAddonKey = 'echo_prefer_extension_audio';

  final List<ExtensionAddon> _addons = [];
  bool _preferExtensionAudio = true;

  List<ExtensionAddon> get addons => List.unmodifiable(_addons);
  bool get preferExtensionAudio => _preferExtensionAudio;
  bool get hasEnabledAddons => _addons.any((a) => a.enabled);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferExtensionAudio = prefs.getBool(_preferAddonKey) ?? true;
      final raw = prefs.getString(_addonsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _addons
          ..clear()
          ..addAll(list.map((e) => ExtensionAddon.fromJson(e as Map<String, dynamic>)));
      }
      notifyListeners();
    } catch (_) {}
  }

  String sanitizeUrl(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    u = u.replaceAll(RegExp(r'/+$'), '');
    if (u.toLowerCase().endsWith('/manifest.json')) {
      u = u.substring(0, u.length - '/manifest.json'.length);
    }
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  Future<String?> fetchManifestName(String baseUrl) async {
    try {
      final clean = sanitizeUrl(baseUrl);
      final resp = await http
          .get(Uri.parse('$clean/manifest.json'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final name = json['name']?.toString().trim();
        if (name != null && name.isNotEmpty) return name;
      }
    } catch (_) {}
    return null;
  }

  Future<void> addAddon({required String name, required String url}) async {
    final cleanUrl = sanitizeUrl(url);
    final resolvedName =
        name.trim().isNotEmpty ? name.trim() : (await fetchManifestName(cleanUrl) ?? 'Custom Server');
    final id = 'ext_${DateTime.now().millisecondsSinceEpoch}';
    _addons.add(ExtensionAddon(id: id, name: resolvedName, url: cleanUrl, enabled: true));
    await _save();
    notifyListeners();
  }

  Future<void> toggleAddon(String id, bool enabled) async {
    for (int i = 0; i < _addons.length; i++) {
      if (_addons[i].id == id) {
        _addons[i] = _addons[i].copyWith(enabled: enabled);
      }
    }
    await _save();
    notifyListeners();
  }

  Future<void> removeAddon(String id) async {
    _addons.removeWhere((a) => a.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> setPreferExtensionAudio(bool value) async {
    _preferExtensionAudio = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferAddonKey, value);
    notifyListeners();
  }

  Future<List<Track>> searchAddons(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    final results = <Track>[];

    for (final addon in _addons.where((a) => a.enabled)) {
      try {
        final uri = Uri.parse('${addon.url}/search?q=${Uri.encodeQueryComponent(clean)}');
        final resp = await http.get(uri).timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body);
          final tracks = json['tracks'] as List<dynamic>? ?? const [];
          for (final item in tracks) {
            if (item is! Map<String, dynamic>) continue;
            final tid = item['id']?.toString() ?? '';
            if (tid.isEmpty) continue;
            final title = item['title']?.toString() ?? 'Unknown';
            final artist = item['artist']?.toString() ?? 'Unknown Artist';
            final durSec = (item['duration'] as num?)?.toInt() ?? 210;
            final art = (item['artworkURL'] ?? item['albumArtworkURL'])?.toString() ?? '';
            results.add(Track(
              id: 'addon_${addon.id}_$tid',
              title: title,
              artist: artist,
              duration: Duration(seconds: durSec),
              artworkUrl: art,
              streamUrl: '',
              sourcePluginId: addon.name,
              qualityBadge: 'LOSSLESS',
            ));
          }
        }
      } catch (e) {
        debugPrint('Addon search error (${addon.name}): $e');
      }
    }
    return results;
  }

  /// Resolves high-bitrate / FLAC stream URL from enabled custom extension servers
  Future<({String url, String qualityBadge})?> resolveBestStreamForTrack(Track track) async {
    if (!hasEnabledAddons) return null;

    // Direct addon track ID match
    if (track.id.startsWith('addon_')) {
      final rest = track.id.substring('addon_'.length);
      for (final addon in _addons.where((a) => a.enabled)) {
        if (rest.startsWith('${addon.id}_')) {
          final rawId = rest.substring(addon.id.length + 1);
          return _fetchStreamFromAddon(addon, rawId);
        }
      }
    }

    if (!_preferExtensionAudio) return null;

    // Cross-match YouTube track on enabled Lossless / 320k addon servers
    final cleanTitle = track.title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
    final cleanArtist = track.artist.split(RegExp(r'[,&•]')).first.trim();
    final candidates = await searchAddons('$cleanTitle $cleanArtist');
    if (candidates.isEmpty) return null;

    final match = candidates.firstWhere(
      (c) =>
          c.title.toLowerCase().contains(cleanTitle.toLowerCase()) ||
          cleanTitle.toLowerCase().contains(c.title.toLowerCase()),
      orElse: () => candidates.first,
    );

    final rest = match.id.substring('addon_'.length);
    for (final addon in _addons.where((a) => a.enabled)) {
      if (rest.startsWith('${addon.id}_')) {
        final rawId = rest.substring(addon.id.length + 1);
        return _fetchStreamFromAddon(addon, rawId);
      }
    }
    return null;
  }

  Future<({String url, String qualityBadge})?> _fetchStreamFromAddon(
      ExtensionAddon addon, String rawId) async {
    try {
      final uri = Uri.parse(
          '${addon.url}/stream/${Uri.encodeComponent(rawId)}?quality=LOSSLESS');
      final resp = await http.get(uri).timeout(const Duration(seconds: 7));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final url = json['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          final q = (json['audioQuality'] ??
                  json['streamQuality'] ??
                  json['quality'] ??
                  json['format'] ??
                  'LOSSLESS')
              .toString()
              .toUpperCase();
          return (url: url, qualityBadge: q);
        }
      }
    } catch (e) {
      debugPrint('Addon stream error (${addon.name}): $e');
    }
    return null;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_addonsKey, jsonEncode(_addons.map((a) => a.toJson()).toList()));
    } catch (_) {}
  }
}
