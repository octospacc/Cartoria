import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveOrShareFile(Uint8List bytes, String filename) async {
  // Desktop: native save dialog. Sandboxed macOS apps can only write
  // inside their container or to user-selected paths, so a save dialog
  // is the correct primitive.
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $filename',
      fileName: filename,
    );
    if (path == null) return;
    await File(path).writeAsBytes(bytes, flush: true);
    return;
  }

  // Mobile: share sheet.
  final tmp = await getTemporaryDirectory();
  final file = File(p.join(tmp.path, filename));
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path)], subject: filename);
}