import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:ovrld_core/ovrld_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repo.dart';

/// Whole-app backup as one JSON file. Shared through the system sheet
/// (Drive, email, Files), restored by picking the file.
abstract final class Backup {
  static Future<void> export(Repo repo) async {
    final data = await repo.exportAll();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'ovrld-backup-${dayKey(DateTime.now())}.json'));
    await file.writeAsString(jsonEncode(data));
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'OVRLD backup'));
  }

  /// Returns false when the user cancelled the picker.
  static Future<bool> import(Repo repo) async {
    final pick = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (pick == null || pick.files.isEmpty) return false;
    final f = pick.files.single;
    final bytes = f.bytes ?? await File(f.path!).readAsBytes();
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('That file is not a readable OVRLD backup.');
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('That file is not an OVRLD backup.');
    }
    await repo.importAll(json);
    return true;
  }
}
