import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../data/models.dart';
import '../../data/store.dart';

/// Displays the raw on-disk representation of a post (frontmatter + body)
/// in a scrollable, copyable dialog.
Future<void> showPostSourceDialog(
  BuildContext context,
  VaultStore store,
  Space space,
  Post post,
) async {
  final String source;
  try {
    source = await store.readPostSource(space.id, post.id);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read source: $e')),
      );
    }
    return;
  }
  if (!context.mounted) return;

  // Use the real path from the repository so legacy `posts/` (pre-rename)
  // and current `entries/` both display correctly. Fall back to a
  // constructed path if the file can't be located — shouldn't happen for
  // a post loaded via VaultStore, but avoids a null in a cosmetic field.
  final path = await store.postFilePath(space.id, post.id) ??
      p.join(store.vaultPath, space.id, 'entries', '${post.id}.html');
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _PostSourceDialog(
      source: source,
      postId: post.id,
      path: path,
    ),
  );
}

class _PostSourceDialog extends StatelessWidget {
  final String source;
  final String postId;
  final String path;

  const _PostSourceDialog({
    required this.source,
    required this.postId,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.35,
    );

    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width * 0.9).clamp(320.0, 720.0);
    final height = (screen.height * 0.75).clamp(240.0, 640.0);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.code, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Source · ${postId.substring(0, 8)}…',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: SelectableText(source, style: mono),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Path is now selectable so the user can copy it and paste it
            // into a terminal or file manager. No maxLines — a very long
            // path wraps to a couple of lines, which is preferable to
            // truncating at an ellipsis and hiding the end of the path.
            SelectableText(
              path,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: source));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Source copied')),
              );
            }
          },
          icon: const Icon(Icons.copy_all, size: 16),
          label: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}