import 'dart:typed_data';

Future<String> prepareMediaUri(Uint8List bytes, String name) async {
  throw UnsupportedError('Media playback not supported on this platform');
}

Future<void> releaseMediaUri(String uri) async {}