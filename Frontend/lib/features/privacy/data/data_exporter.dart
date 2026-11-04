import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class DataExporter {
  Future<void> saveOrShare(Uint8List bytes, String fileName);
}

class MobileDataExporter implements DataExporter {
  const MobileDataExporter();

  @override
  Future<void> saveOrShare(Uint8List bytes, String fileName) async {
    final Directory directory = await getTemporaryDirectory();
    final File file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        fileNameOverrides: <String>[fileName],
      ),
    );
  }
}

class DesktopDataExporter implements DataExporter {
  const DesktopDataExporter();

  @override
  Future<void> saveOrShare(Uint8List bytes, String fileName) async {
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'JSON', extensions: <String>['json']),
      ],
    );
    if (location == null) {
      return;
    }
    await File(location.path).writeAsBytes(bytes, flush: true);
  }
}

final Provider<DataExporter> dataExporterProvider = Provider<DataExporter>((
  Ref ref,
) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return const MobileDataExporter();
  }
  return const DesktopDataExporter();
});
