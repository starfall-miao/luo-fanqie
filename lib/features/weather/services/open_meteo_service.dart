import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_snapshot.dart';

class OpenMeteoService {
  const OpenMeteoService();

  Future<WeatherSnapshot> fetch(WeatherCity city) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${city.latitude}',
      'longitude': '${city.longitude}',
      'current': 'temperature_2m,weather_code,is_day',
      'timezone': 'auto',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('天气服务返回 HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('天气数据格式不正确');
    final current = decoded['current'];
    if (current is! Map) throw const FormatException('天气数据缺少 current');
    final code = (current['weather_code'] as num?)?.toInt() ?? 3;
    return WeatherSnapshot(
      city: city.name,
      condition: WeatherSnapshot.conditionFromCode(code),
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 20,
      isDay: (current['is_day'] as num?)?.toInt() != 0,
      fetchedAt: DateTime.now(),
    );
  }
}
