import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  final path = '${store.vaultPath}/${space.id}/posts/${post.id}.html';
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
            Text(
              path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
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