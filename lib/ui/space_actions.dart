import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../platform/file_save.dart';

/// Exports [space] as a zip, then hands it to the platform's save/share
/// mechanism (native dialog on desktop, share sheet on mobile, download
/// on web). Shows a snackbar on failure.
///
/// Used by both the space list row menu and the space feed overflow menu.
Future<void> exportSpaceZip(
  BuildContext context,
  VaultStore store,
  Space space,
) async {
  try {
    final bytes = await store.exportSpaceZip(space.id);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9T]'), '')
        .substring(0, 15);
    await saveOrShareFile(bytes, 'space-${space.name}-$stamp.zip');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}