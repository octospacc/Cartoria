import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

final _active = <String>{};

Future<String> prepareMediaUri(Uint8List bytes, String name) async {
  final tmp = await getTemporaryDirectory();
  final dir = Directory(p.join(tmp.path, 'vault-media'));
  if (!await dir.exists()) await dir.create(recursive: true);
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'bin';
  final file = File(p.join(dir.path, '${const Uuid().v7()}.$ext'));
  await file.writeAsBytes(bytes, flush: true);
  _active.add(file.path);
  return Uri.file(file.path).toString();
}

Future<void> releaseMediaUri(String uri) async {
  try {
    final parsed = Uri.parse(uri);
    if (!parsed.isScheme('file')) return;
    final file = File.fromUri(parsed);
    if (_active.remove(file.path) && await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}