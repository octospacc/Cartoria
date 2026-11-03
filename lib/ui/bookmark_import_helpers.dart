import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/bookmarks.dart';
import '../data/repos/bookmarks_importer.dart';
import '../platform/file_read.dart';

/// Opens the system file picker filtered to `.html` / `.htm`, reads the
/// chosen file, and parses it. Returns `null` if the user cancelled or
/// something went wrong (in which case a SnackBar has already been shown).
Future<BookmarkFile?> pickAndParseBookmarkFile(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
    );
    if (result == null) return null;
    final picked = result.files.single;
    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      bytes = await readFileFromPath(picked.path!);
    }
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected file')),
        );
      }
      return null;
    }
    return BookmarkFileParser.parse(
      utf8.decode(bytes, allowMalformed: true),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not parse file: $e')),
      );
    }
    return null;
  }
}

/// Human-readable one-liner for the result snackbar.
String bookmarkImportSummary(BookmarkImportResult r) {
  if (r.total == 0) return 'No bookmarks found in file';
  if (r.added == 0 && r.skippedDuplicates == r.total) {
    return 'All ${r.total} bookmarks already present';
  }
  final parts = <String>[
    '${r.added} ${r.added == 1 ? "bookmark" : "bookmarks"} added',
  ];
  if (r.skippedDuplicates > 0) {
    parts.add(
      '${r.skippedDuplicates} duplicate${r.skippedDuplicates == 1 ? "" : "s"} '
      'skipped',
    );
  }
  if (r.skippedInvalid > 0) {
    parts.add('${r.skippedInvalid} invalid skipped');
  }
  return parts.join(' · ');
}