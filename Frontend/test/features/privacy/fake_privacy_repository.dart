import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:smartagri/features/privacy/data/data_exporter.dart';
import 'package:smartagri/features/privacy/data/privacy_repository.dart';

class FakePrivacyRepository extends Mock implements PrivacyRepository {}

class RecordingDataExporter implements DataExporter {
  final List<Uint8List> bytes = <Uint8List>[];
  final List<String> fileNames = <String>[];
  Object? error;

  @override
  Future<void> saveOrShare(Uint8List data, String fileName) async {
    if (error != null) {
      throw error!;
    }
    bytes.add(data);
    fileNames.add(fileName);
  }
}
