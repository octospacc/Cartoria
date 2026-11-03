import 'dart:typed_data';

/// On web, file pickers always return bytes directly — there is no path.
Future<Uint8List?> readFileFromPath(String path) async => null;