import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Collects the single [Digest] emitted by a chunked SHA-1 conversion.
/// Simpler than pulling `AccumulatorSink` from an extra dependency.
class _DigestSink implements Sink<Digest> {
  late Digest digest;
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
}

/// Git's blob SHA-1: `sha1("blob <length>\0" + content)`.
///
/// Uses chunked conversion (`sha1.startChunkedConversion`) so no second
/// buffer equal to the file size is allocated. The previous version
/// built `full = header + content` and hashed that; peak memory was 2×
/// the file size, which was the reason for the removed `size:N` sentinel
/// on web — and that sentinel was itself the source of the "every push
/// re-uploads large files" bug. Chunked conversion brings peak down to
/// ~1× and removes the need for the sentinel.
String gitBlobSha(Uint8List content) {
  final sink = _DigestSink();
  final input = sha1.startChunkedConversion(sink);
  input.add(utf8.encode('blob ${content.length}\u0000'));
  input.add(content);
  input.close();
  return sink.digest.toString();
}