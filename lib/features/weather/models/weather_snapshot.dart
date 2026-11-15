enum WeatherCondition { clear, partlyCloudy, cloudy, rain, thunder, snow, fog }

class WeatherCity {
  const WeatherCity(this.name, this.latitude, this.longitude);

  final String name;
  final double latitude;
  final double longitude;
}

const weatherCities = <WeatherCity>[
  WeatherCity('北京', 39.9042, 116.4074),
  WeatherCity('上海', 31.2304, 121.4737),
  WeatherCity('广州', 23.1291, 113.2644),
  WeatherCity('深圳', 22.5431, 114.0579),
  WeatherCity('杭州', 30.2741, 120.1551),
  WeatherCity('成都', 30.5728, 104.0668),
  WeatherCity('武汉', 30.5928, 114.3055),
  WeatherCity('西安', 34.3416, 108.9398),
  WeatherCity('南京', 32.0603, 118.7969),
  WeatherCity('重庆', 29.5630, 106.5516),
  WeatherCity('香港', 22.3193, 114.1694),
  WeatherCity('台北', 25.0330, 121.5654),
];

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.city,
    required this.condition,
    required this.temperature,
    required this.isDay,
    required this.fetchedAt,
  });

  final String city;
  final WeatherCondition condition;
  final double temperature;
  final bool isDay;
  final DateTime fetchedAt;

  String get label => switch (condition) {
    WeatherCondition.clear => '晴',
    WeatherCondition.partlyCloudy => '多云',
    WeatherCondition.cloudy => '阴',
    WeatherCondition.rain => '雨',
    WeatherCondition.thunder => '雷雨',
    WeatherCondition.snow => '雪',
    WeatherCondition.fog => '雾',
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'city': city,
    'condition': condition.name,
    'temperature': temperature,
    'isDay': isDay,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final fetchedAt =
        DateTime.tryParse(json['fetchedAt'] as String? ?? '') ?? DateTime.now();
    return WeatherSnapshot(
      city: json['city'] as String? ?? '上海',
      condition: WeatherCondition.values.firstWhere(
        (item) => item.name == json['condition'],
        orElse: () => WeatherCondition.partlyCloudy,
      ),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 20,
      isDay: json['isDay'] as bool? ?? true,
      fetchedAt: fetchedAt,
    );
  }

  static WeatherCondition conditionFromCode(int code) {
    if (code == 0) return WeatherCondition.clear;
    if (code <= 2) return WeatherCondition.partlyCloudy;
    if (code == 3) return WeatherCondition.cloudy;
    if (code >= 45 && code <= 48) return WeatherCondition.fog;
    if (code >= 51 && code <= 67) return WeatherCondition.rain;
    if (code >= 71 && code <= 77) return WeatherCondition.snow;
    if (code >= 80 && code <= 82) return WeatherCondition.rain;
    if (code >= 85 && code <= 86) return WeatherCondition.snow;
    if (code >= 95) return WeatherCondition.thunder;
    return WeatherCondition.cloudy;
  }
}
