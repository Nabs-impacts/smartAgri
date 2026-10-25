import 'package:dio/dio.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_repository.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_status.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_summary.dart';
import 'package:smartagri/features/diagnostics/domain/severity.dart';

typedef FakeDiagnosticsListHandler = DiagnosticsPage Function(String? cursor);

class FakeDiagnosticsRepository extends DiagnosticsRepository {
  FakeDiagnosticsRepository({
    List<DiagnosticSummary>? items,
    this.nextCursor,
    this.listHandler,
  }) : items = items ?? <DiagnosticSummary>[],
       super(dio: Dio());

  List<DiagnosticSummary> items;
  String? nextCursor;
  FakeDiagnosticsListHandler? listHandler;
  ApiException? listError;
  ApiException? deleteError;
  int listCalls = 0;
  int deleteCalls = 0;
  final List<String?> requestedCursors = <String?>[];
  final List<int> requestedLimits = <int>[];
  final List<String?> requestedPlotIds = <String?>[];
  final List<DiagnosticStatus?> requestedStatuses = <DiagnosticStatus?>[];
  final List<String> deletedIds = <String>[];

  @override
  Future<DiagnosticsPage> list({
    String? cursor,
    int limit = 20,
    String? plotId,
    DiagnosticStatus? status,
  }) async {
    listCalls++;
    requestedCursors.add(cursor);
    requestedLimits.add(limit);
    requestedPlotIds.add(plotId);
    requestedStatuses.add(status);
    if (listError != null) {
      throw listError!;
    }
    if (listHandler != null) {
      return listHandler!(cursor);
    }
    return DiagnosticsPage(
      items: List<DiagnosticSummary>.of(items),
      nextCursor: nextCursor,
    );
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls++;
    if (deleteError != null) {
      throw deleteError!;
    }
    deletedIds.add(id);
    items = items.where((DiagnosticSummary item) => item.id != id).toList();
  }
}

DiagnosticSummary sampleSummary({
  String id = 'diag-1',
  DiagnosticStatus status = DiagnosticStatus.done,
  Severity? severity = Severity.high,
  double? confidence = 0.92,
  DateTime? createdAt,
  String? plotId,
  String? labelName,
  String? thumbnailUrl,
}) {
  return DiagnosticSummary(
    id: id,
    status: status,
    confidence: confidence,
    severity: severity,
    createdAt: createdAt ?? DateTime(2026, 10, 24, 14, 5),
    plotId: plotId,
    labelName: labelName,
    thumbnailUrl: thumbnailUrl,
  );
}
