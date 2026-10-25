import 'package:dio/dio.dart';
import 'package:smartagri/features/admin/data/stats_repository.dart';
import 'package:smartagri/features/admin/domain/overview.dart';
import 'package:smartagri/features/admin/domain/yield_cell.dart';

class RecordedYieldsQuery {
  const RecordedYieldsQuery({
    this.cropId,
    this.regionId,
    this.seasonYear,
    this.seasonType,
  });

  final int? cropId;
  final int? regionId;
  final int? seasonYear;
  final SeasonType? seasonType;
}

Overview sampleOverview() {
  return const Overview(
    activeUsers30d: 1250,
    diagnostics30d: 340,
    trackedAreaHa: 12500,
    adoption: <RegionAdoption>[
      RegionAdoption(
        regionId: 1,
        regionName: 'Niamey',
        masked: false,
        users: 20,
        plots: 40,
      ),
      RegionAdoption(
        regionId: 2,
        regionName: 'Dosso',
        masked: false,
        users: 10,
        plots: 12,
      ),
      RegionAdoption(regionId: 3, regionName: 'Tahoua', masked: true),
    ],
  );
}

YieldCell sampleYieldCell({
  int cropId = 1,
  String cropName = 'Mil',
  int regionId = 1,
  String regionName = 'Maradi',
  int seasonYear = 2026,
  SeasonType seasonType = SeasonType.rainy,
  bool masked = false,
  int? cycles = 12,
  int? farmers = 5,
  double? avg = 1250,
  double? min = 900,
  double? max = 1600,
}) {
  return YieldCell(
    cropId: cropId,
    cropCode: 'crop_$cropId',
    cropName: cropName,
    regionId: regionId,
    regionName: regionName,
    seasonYear: seasonYear,
    seasonType: seasonType,
    masked: masked,
    cycles: cycles,
    farmers: farmers,
    avgYieldKgPerHa: avg,
    minYieldKgPerHa: min,
    maxYieldKgPerHa: max,
  );
}

class FakeStatsRepository extends StatsRepository {
  FakeStatsRepository({
    Overview? overview,
    List<YieldCell>? yields,
    this.overviewError,
    this.yieldsError,
  }) : overview = overview ?? sampleOverview(),
       yields = yields ?? <YieldCell>[],
       super(dio: Dio());

  Overview overview;
  List<YieldCell> yields;
  Object? overviewError;
  Object? yieldsError;
  int overviewCalls = 0;
  final List<RecordedYieldsQuery> yieldsCalls = <RecordedYieldsQuery>[];

  @override
  Future<Overview> getOverview() async {
    overviewCalls++;
    if (overviewError != null) {
      throw overviewError!;
    }
    return overview;
  }

  @override
  Future<List<YieldCell>> getYields({
    int? cropId,
    int? regionId,
    int? seasonYear,
    SeasonType? seasonType,
  }) async {
    yieldsCalls.add(
      RecordedYieldsQuery(
        cropId: cropId,
        regionId: regionId,
        seasonYear: seasonYear,
        seasonType: seasonType,
      ),
    );
    if (yieldsError != null) {
      throw yieldsError!;
    }
    return yields;
  }
}
