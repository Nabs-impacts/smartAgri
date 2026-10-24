import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/weather/data/weather_repository.dart';
import 'package:smartagri/features/weather/domain/weather.dart';

void main() {
  test('the fake weather contains the demo values', () {
    const FakeWeatherRepository repository = FakeWeatherRepository();

    final Weather weather = repository.current();

    expect(weather.temperatureC, 34);
    expect(weather.rainRiskPercent, 10);
    expect(weather.windKmh, 15);
    expect(weather.soilStatus, SoilStatus.good);
  });

  test('the weather provider reads the repository', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final Weather weather = container.read(weatherProvider);

    expect(weather.temperatureC, 34);
    expect(weather.soilStatus, SoilStatus.good);
  });
}
