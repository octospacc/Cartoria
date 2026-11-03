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
    final domain = post.domain;

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
                        // Wide layout: decode at the exact display size.
                        child: _thumb(context, theme, thumbnail, 112),
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
                      // Narrow layout: thumb spans the card width.
                      child: _thumb(
                          context, theme, thumbnail, constraints.maxWidth),
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

  Widget _thumb(
    BuildContext context,
    ThemeData theme,
    String url,
    double logicalWidth,
  ) {
    // Cap the decode size at the *actual* display size × DPR. A 1280×720
    // YouTube maxresdefault in the wide 112px slot decodes to 112×112×DPR²
    // rather than the full 3.6MB RGBA.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (logicalWidth * dpr).round();

    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: cacheW,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.broken_image_outlined,
            color: theme.colorScheme.onSurfaceVariant),
      ),
      // No spinner: during a fast scroll, 50 animating CircularProgress-
      // Indicators per frame is measurable raster cost. A flat colour
      // placeholder is visually acceptable and costs nothing to paint.
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: theme.colorScheme.surfaceContainerHighest);
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
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
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