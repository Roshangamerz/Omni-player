import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EqBand {
  final int index;
  final int centerFreqHz;
  int levelMb;

  EqBand({required this.index, required this.centerFreqHz, required this.levelMb});

  String get label => centerFreqHz >= 1000
      ? '${(centerFreqHz / 1000).toStringAsFixed(1).replaceAll('.0', '')}k'
      : '$centerFreqHz';
}

/// Native Android AudioFX Equalizer + Echo Music AutoEq Headphone Presets
class EqualizerService extends ChangeNotifier {
  static final EqualizerService _instance = EqualizerService._internal();
  factory EqualizerService() => _instance;
  EqualizerService._internal();

  static const MethodChannel _channel = MethodChannel('com.omniplayer.music/audio_fx');

  bool _supported = false;
  bool _enabled = false;
  int _minMb = -1500;
  int _maxMb = 1500;
  int _bassBoost = 0; // 0..1000
  int _loudnessGain = 0; // 0..1500 mB
  String _activePreset = 'Flat';
  final List<EqBand> _bands = [];

  bool get supported => _supported;
  bool get enabled => _enabled;
  int get minMb => _minMb;
  int get maxMb => _maxMb;
  int get bassBoost => _bassBoost;
  int get loudnessGain => _loudnessGain;
  String get activePreset => _activePreset;
  List<EqBand> get bands => List.unmodifiable(_bands);

  static const Map<String, List<double>> builtInPresets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Echo Bass': [0.7, 0.45, 0.0, 0.25, 0.4],
    'Apple Spatial': [0.35, 0.15, 0.2, 0.45, 0.55],
    'Vocal Clarity': [-0.2, 0.15, 0.55, 0.45, 0.1],
    'Rock / Live': [0.55, 0.25, -0.1, 0.35, 0.6],
    'Electronic': [0.65, 0.35, 0.05, 0.3, 0.55],
    'Late Night': [0.25, 0.1, 0.3, 0.15, -0.1],
  };

  /// Curated AutoEq profiles (mirrors AutoEqBottomSheet.kt)
  static const List<({String name, String path})> autoEqModels = [
    (name: 'Sony WH-1000XM5', path: 'oratory1990/harman_over-ear_2018/Sony WH-1000XM5'),
    (name: 'Apple AirPods Pro 2', path: 'oratory1990/harman_in-ear_2019v2/Apple AirPods Pro (2nd generation)'),
    (name: 'Samsung Galaxy Buds2 Pro', path: 'oratory1990/harman_in-ear_2019v2/Samsung Galaxy Buds2 Pro'),
    (name: 'Sennheiser HD 650', path: 'oratory1990/harman_over-ear_2018/Sennheiser HD 650'),
    (name: 'Nothing Ear (2)', path: 'rtings/rtings_harman_in-ear_2019v2/Nothing Ear (2)'),
  ];

  Future<void> init() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('initEq');
      if (res != null && res['supported'] == true) {
        _supported = true;
        _enabled = res['enabled'] == true;
        _minMb = (res['minMb'] as num?)?.toInt() ?? -1500;
        _maxMb = (res['maxMb'] as num?)?.toInt() ?? 1500;
        final rawBands = res['bands'] as List<dynamic>? ?? const [];
        _bands
          ..clear()
          ..addAll(rawBands.map((b) {
            final m = Map<String, dynamic>.from(b as Map);
            return EqBand(
              index: (m['index'] as num).toInt(),
              centerFreqHz: (m['centerFreqHz'] as num).toInt(),
              levelMb: (m['levelMb'] as num).toInt(),
            );
          }));
      }
      final prefs = await SharedPreferences.getInstance();
      _activePreset = prefs.getString('omni_eq_preset') ?? 'Flat';
      _bassBoost = prefs.getInt('omni_eq_bass') ?? 0;
      _loudnessGain = prefs.getInt('omni_eq_loudness') ?? 0;
      final savedEnabled = prefs.getBool('omni_eq_enabled') ?? false;
      if (_supported && savedEnabled) {
        await setEnabled(true);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Equalizer init error: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('omni_eq_enabled', value);
    try {
      await _channel.invokeMethod('setEqEnabled', {'enabled': value});
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setBandLevel(int bandIndex, int levelMb) async {
    final clamped = levelMb.clamp(_minMb, _maxMb);
    if (bandIndex >= 0 && bandIndex < _bands.length) {
      _bands[bandIndex].levelMb = clamped;
      _activePreset = 'Custom';
    }
    try {
      await _channel.invokeMethod('setBandLevel', {'band': bandIndex, 'levelMb': clamped});
    } catch (_) {}
    notifyListeners();
  }

  Future<void> applyPreset(String name) async {
    final curve = builtInPresets[name];
    if (curve == null) return;
    _activePreset = name;
    if (!_enabled) await setEnabled(true);
    for (int i = 0; i < _bands.length; i++) {
      final norm = i < curve.length ? curve[i] : curve.last;
      final targetMb = (norm * _maxMb).round().clamp(_minMb, _maxMb);
      _bands[i].levelMb = targetMb;
      try {
        await _channel.invokeMethod('setBandLevel', {'band': i, 'levelMb': targetMb});
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('omni_eq_preset', name);
    notifyListeners();
  }

  /// Fetch real AutoEq GraphicEQ curve from jaakkopasanen/AutoEq GitHub repo
  Future<bool> applyAutoEqProfile(String name, String repoPath) async {
    try {
      final fileName = Uri.encodeComponent('$name GraphicEQ.txt');
      final url =
          'https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/$repoPath/$fileName';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 7));
      if (resp.statusCode == 200 && resp.body.contains('GraphicEQ:')) {
        final raw = resp.body.split('GraphicEQ:').last.trim();
        final pairs = raw.split(';');
        final freqGains = <({double freq, double db})>[];
        for (final p in pairs) {
          final parts = p.trim().split(RegExp(r'\s+'));
          if (parts.length == 2) {
            final f = double.tryParse(parts[0]);
            final g = double.tryParse(parts[1]);
            if (f != null && g != null) freqGains.add((freq: f, db: g));
          }
        }
        if (freqGains.isNotEmpty) {
          if (!_enabled) await setEnabled(true);
          _activePreset = 'AutoEq: $name';
          for (final band in _bands) {
            // Find nearest AutoEq frequency point
            var best = freqGains.first;
            var bestDiff = (best.freq - band.centerFreqHz).abs();
            for (final fg in freqGains) {
              final d = (fg.freq - band.centerFreqHz).abs();
              if (d < bestDiff) {
                best = fg;
                bestDiff = d;
              }
            }
            final mb = (best.db * 100).round().clamp(_minMb, _maxMb);
            band.levelMb = mb;
            await _channel.invokeMethod('setBandLevel', {'band': band.index, 'levelMb': mb});
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('omni_eq_preset', _activePreset);
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('AutoEq fetch error: $e');
    }
    return false;
  }

  Future<void> setBassBoost(int strength) async {
    _bassBoost = strength.clamp(0, 1000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('omni_eq_bass', _bassBoost);
    try {
      await _channel.invokeMethod('setBassBoost', {'strength': _bassBoost});
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setLoudnessGain(int gainMb) async {
    _loudnessGain = gainMb.clamp(0, 1500);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('omni_eq_loudness', _loudnessGain);
    try {
      await _channel.invokeMethod('setLoudnessGain', {'gainMb': _loudnessGain});
    } catch (_) {}
    notifyListeners();
  }
}
