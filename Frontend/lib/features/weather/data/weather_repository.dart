import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/weather.dart';

abstract interface class WeatherRepository {
  Weather current();
}

class FakeWeatherRepository implements WeatherRepository {
  const FakeWeatherRepository();

  @override
  Weather current() {
    return const Weather(
      temperatureC: 34,
      rainRiskPercent: 10,
      windKmh: 15,
      soilStatus: SoilStatus.good,
    );
  }
}

final Provider<WeatherRepository> weatherRepositoryProvider =
    Provider<WeatherRepository>((Ref ref) => const FakeWeatherRepository());

final Provider<Weather> weatherProvider = Provider<Weather>(
  (Ref ref) => ref.watch(weatherRepositoryProvider).current(),
);
