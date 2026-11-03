import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models.dart';

class LinkPreviewCard extends StatelessWidget {
  final Post post;
  const LinkPreviewCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = post.thumbnail;
    final hasThumb = thumbnail != null && thumbnail.isNotEmpty;
    final domain = _domainOf(post.url!);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openUrl(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 400;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasThumb)
                      SizedBox(
                        width: 112,
                        height: 112,
                        child: _thumb(theme, thumbnail),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _textContent(theme, domain),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasThumb)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _thumb(theme, thumbnail),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: _textContent(theme, domain),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _thumb(ThemeData theme, String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.broken_image_outlined,
            color: theme.colorScheme.onSurfaceVariant),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _textContent(ThemeData theme, String domain) {
    final title = post.title;
    final description = post.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null && title.isNotEmpty)
          Text(
            title,
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.link, size: 12, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                domain,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _domainOf(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }

  Future<void> _openUrl(BuildContext context) async {
    final url = post.url;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }
}