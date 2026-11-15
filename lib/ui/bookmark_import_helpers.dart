import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/bookmarks.dart';
import '../data/store.dart';

/// Universal file picker for the unified import flow. Returns the raw
/// bytes and filename; the caller dispatches on extension.
Future<({Uint8List bytes, String name})?> pickImportFile(
  BuildContext context,
) async {
  try {
    const group = XTypeGroup(
      label: 'Import files',
      extensions: ['zip', 'html', 'htm'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected file is empty')),
        );
      }
      return null;
    }
    return (bytes: bytes, name: file.name);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read file: $e')),
      );
    }
    return null;
  }
}

/// Multi-file picker for the space-feed Import… flow. Returns one entry
/// per non-empty file the user selected. Files that fail to read are
/// logged and skipped; if nothing readable came back the user gets a
/// single snackbar explaining that.
Future<List<({Uint8List bytes, String name})>> pickImportFiles(
  BuildContext context,
) async {
  try {
    const group = XTypeGroup(
      label: 'Import files',
      extensions: ['zip', 'html', 'htm'],
    );
    final files = await openFiles(acceptedTypeGroups: [group]);
    if (files.isEmpty) return const [];

    final result = <({Uint8List bytes, String name})>[];
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        result.add((bytes: bytes, name: file.name));
      } catch (e) {
        debugPrint('Could not read ${file.name}: $e');
      }
    }
    if (result.isEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No readable files selected')),
      );
    }
    return result;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read files: $e')),
      );
    }
    return const [];
  }
}

/// Human-readable one-liner for a bookmark import result.
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

/// Human-readable one-liner for a space-zip import result.
String spaceImportSummary(SpaceImportResult r) {
  if (r.total == 0) return 'No posts found in the zip';
  if (r.imported == 0 && r.skippedDuplicates == r.total) {
    return 'All ${r.total} ${r.total == 1 ? "item" : "items"} already present';
  }
  final parts = <String>[
    '${r.imported} ${r.imported == 1 ? "item" : "items"} imported',
  ];
  if (r.skippedDuplicates > 0) {
    parts.add(
      '${r.skippedDuplicates} duplicate'
      '${r.skippedDuplicates == 1 ? "" : "s"} skipped',
    );
  }
  if (r.filesImported > 0) {
    parts.add(
      '${r.filesImported} file${r.filesImported == 1 ? "" : "s"} imported',
    );
  }
  return parts.join(' · ');
}