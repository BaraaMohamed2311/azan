import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Mobile implementation — stores surah recordings under the app documents
/// directory (mirrors the original expo-file-system logic).
class MobileIo {
  Future<String> audioDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/athan-libya-audio');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<bool> fileExists(String path) async => File(path).existsSync();

  Future<void> writeFile(String path, List<int> bytes) async {
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
  }
}
