class DailyForecast {
  final String date;
  final double maxTempC;
  final double minTempC;
  final double precipitationSumMm;
  final double et0Mm;

  DailyForecast({
    required this.date,
    required this.maxTempC,
    required this.minTempC,
    required this.precipitationSumMm,
    required this.et0Mm,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: json['date'],
      maxTempC: (json['max_temp_c'] as num).toDouble(),
      minTempC: (json['min_temp_c'] as num).toDouble(),
      precipitationSumMm: (json['precipitation_sum_mm'] as num).toDouble(),
      et0Mm: (json['et0_mm'] as num).toDouble(),
    );
  }
}

class Weather {
  final int farmId;
  final double currentTempC;
  final double currentHumidityPercent;
  final double currentPrecipitationMm;
  final double currentWindSpeedKmh;
  final double currentSoilMoisture;
  final int currentWeatherCode;
  final List<DailyForecast> forecast;
  final String riskLevel;

  Weather({
    required this.farmId,
    required this.currentTempC,
    required this.currentHumidityPercent,
    required this.currentPrecipitationMm,
    required this.currentWindSpeedKmh,
    required this.currentSoilMoisture,
    required this.currentWeatherCode,
    required this.forecast,
    required this.riskLevel,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    var list = json['forecast'] as List;
    List<DailyForecast> forecastList = list.map((i) => DailyForecast.fromJson(i)).toList();

    return Weather(
      farmId: json['farm_id'],
      currentTempC: (json['current_temp_c'] as num).toDouble(),
      currentHumidityPercent: (json['current_humidity_percent'] as num).toDouble(),
      currentPrecipitationMm: (json['current_precipitation_mm'] as num).toDouble(),
      currentWindSpeedKmh: (json['current_wind_speed_kmh'] as num).toDouble(),
      currentSoilMoisture: (json['current_soil_moisture'] as num).toDouble(),
      currentWeatherCode: json['current_weather_code'] as int,
      forecast: forecastList,
      riskLevel: json['risk_level'],
    );
  }
}
