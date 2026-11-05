import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Git's blob SHA-1: `sha1("blob <length>\0" + content)`.
///
/// This is the identifier both GitHub and GitLab expose for blob content,
/// so comparing [gitBlobSha] of a local file against the SHA returned by
/// `listRemoteFiles` tells us whether it needs to be pushed.
String gitBlobSha(Uint8List content) {
  final header = utf8.encode('blob ${content.length}\u0000');
  final full = Uint8List(header.length + content.length)
    ..setRange(0, header.length, header)
    ..setRange(header.length, header.length + content.length, content);
  return sha1.convert(full).toString();
}