import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/echo_models.dart';

/// Reverse-engineered Echo Music Weather-Aware Ambient Service
/// Uses ipwho.is / ipapi.co + api.open-meteo.com (no API key needed)
class WeatherAmbientService {
  static final WeatherAmbientService _instance = WeatherAmbientService._internal();
  factory WeatherAmbientService() => _instance;
  WeatherAmbientService._internal();

  WeatherSnapshot? _cached;
  DateTime? _expiry;

  Future<WeatherSnapshot?> getCurrentWeatherMood() async {
    if (_cached != null && _expiry != null && DateTime.now().isBefore(_expiry!)) {
      return _cached;
    }

    double? lat;
    double? lon;
    String city = 'Your Area';

    try {
      final r1 = await http.get(Uri.parse('https://ipwho.is/')).timeout(const Duration(seconds: 4));
      if (r1.statusCode == 200) {
        final j = jsonDecode(r1.body);
        if (j['success'] == true) {
          lat = (j['latitude'] as num?)?.toDouble();
          lon = (j['longitude'] as num?)?.toDouble();
          city = j['city']?.toString() ?? city;
        }
      }
    } catch (_) {}

    if (lat == null || lon == null) {
      try {
        final r2 = await http
            .get(Uri.parse('https://ipapi.co/json/'))
            .timeout(const Duration(seconds: 4));
        if (r2.statusCode == 200) {
          final j = jsonDecode(r2.body);
          lat = (j['latitude'] as num?)?.toDouble();
          lon = (j['longitude'] as num?)?.toDouble();
          city = j['city']?.toString() ?? city;
        }
      } catch (_) {}
    }

    if (lat == null || lon == null) return null;

    try {
      final wUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,is_day,weather_code',
      );
      final wResp = await http.get(wUri).timeout(const Duration(seconds: 5));
      if (wResp.statusCode == 200) {
        final j = jsonDecode(wResp.body);
        final cur = j['current'] as Map<String, dynamic>?;
        if (cur != null) {
          final temp = (cur['temperature_2m'] as num?)?.toDouble() ?? 24.0;
          final code = (cur['weather_code'] as num?)?.toInt() ?? 0;
          final isDay = (cur['is_day'] as num?)?.toInt() == 1;
          final mood = _mapWeatherToMood(code, isDay);
          _cached = WeatherSnapshot(
            city: city,
            tempC: temp,
            weatherCode: code,
            isDay: isDay,
            moodLabel: mood.$1,
            recommendedQuery: mood.$2,
          );
          _expiry = DateTime.now().add(const Duration(minutes: 25));
          return _cached;
        }
      }
    } catch (_) {}
    return null;
  }

  (String, String) _mapWeatherToMood(int code, bool isDay) {
    if (code >= 51 && code <= 99) {
      return ('Rainy Mood', 'rainy day lofi acoustic chill');
    }
    if (code >= 1 && code <= 3) {
      return isDay
          ? ('Cloudy Chill', 'indie chill acoustic vibes')
          : ('Night Drive', 'late night synthwave chill');
    }
    return isDay
        ? ('Sunny Energy', 'feel good upbeat hits 2026')
        : ('Midnight Flow', 'midnight lo-fi slow reverb');
  }
}
