import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Git's blob SHA-1: `sha1("blob <length>\0" + content)`.
///
/// On web, computing this for files above [_webShaSkipBytes] is skipped
/// because the required buffer doubles the transient allocation, and
/// iOS Safari's heap limit is too low for it on large files. Callers
/// fall back to size-based comparison for those files — slightly less
/// precise (a same-size edit won't be detected), but avoids the OOM.
const int _webShaSkipBytes = 1 * 1024 * 1024; // 1 MB

/// Returns the git blob SHA, or null when the SHA is skipped (web +
/// file above [_webShaSkipBytes]). Callers that get null should fall
/// back to size comparison.
String? gitBlobSha(Uint8List content) {
  if (kIsWeb && content.length > _webShaSkipBytes) return null;
  final header = utf8.encode('blob ${content.length}\u0000');
  final full = Uint8List(header.length + content.length)
    ..setRange(0, header.length, header)
    ..setRange(header.length, header.length + content.length, content);
  return sha1.convert(full).toString();
}