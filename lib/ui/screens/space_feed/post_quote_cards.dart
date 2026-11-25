part of 'post_card.dart';

class _QuotedOwnCard extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final String quotedPostId;
  final String? quotedSpaceId;
  final void Function(String postId, String spaceId)? onTap;

  const _QuotedOwnCard({
    required this.store,
    required this.space,
    required this.quotedPostId,
    this.quotedSpaceId,
    this.onTap,
  });

  String get _effectiveSpaceId => quotedSpaceId ?? space.id;
  // ...build stays the same except:
  // onTap!(quotedPostId, _effectiveSpaceId)
  // Post? _find() uses _effectiveSpaceId

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final quoted = _find();

    final inner = Padding(
      padding: const EdgeInsets.all(10),
      child: quoted == null
          ? Row(
              children: [
                Icon(Icons.link_off,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  l.postQuotedUnavailable,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          : _quotedContent(context, theme, quoted, l),
    );

    final decorated = Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );

    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap!(quotedPostId, _effectiveSpaceId),
        borderRadius: BorderRadius.circular(8),
        child: decorated,
      ),
    );
  }

  Widget _quotedContent(
    BuildContext context,
    ThemeData theme,
    Post quoted,
    AppLocalizations l,
  ) {
    final icon =
        quoted.kind == PostKind.bookmark ? Icons.bookmark_outline : Icons.notes;
    final preview = _previewOf(quoted);
    final media = _mediaPreview(context, quoted);
    final mediaFiles = _mediaFiles(quoted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.postQuotedFromSpace,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_outward,
                  size: 12, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            preview,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ],
        if (mediaFiles.isNotEmpty) media,
        if (quoted.quotedExternals.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            l.postQuotedIncludesAnother,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  List<DriveFile> _mediaFiles(Post quoted) {
    return quoted.fileIds
        .map((id) => store.fileById(space.id, id))
        .whereType<DriveFile>()
        .where((f) {
          final cat = categoryFor(f.name);
          return cat == FileCategory.image || cat == FileCategory.video;
        })
        .take(4)
        .toList();
  }

  Widget _mediaPreview(BuildContext context, Post quoted) {
    final files = _mediaFiles(quoted);
    if (files.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: files.map((f) {
          final isVideo = categoryFor(f.name) == FileCategory.video;
          return SizedBox(
            width: 56,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isVideo)
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.videocam,
                        size: 24,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    FileThumbnail(
                      store: store,
                      spaceId: space.id,
                      file: f,
                      iconSize: 24,
                    ),
                  if (isVideo)
                    Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _previewOf(Post p) {
    if (p.plaintext.isNotEmpty) return p.plaintext;
    if (p.title != null && p.title!.isNotEmpty) return p.title!;
    if (p.description != null && p.description!.isNotEmpty) {
      return p.description!;
    }
    if (p.url != null) return p.url!;
    return '';
  }

  Post? _find() {
    for (final p in store.postsForSpace(_effectiveSpaceId)) {
      if (p.id == quotedPostId) return p;
    }
    return null;
  }
}

class _QuotedExternalCard extends StatelessWidget {
  final QuotedExternal quote;

  const _QuotedExternalCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final hasUri = quote.uri != null && quote.uri!.isNotEmpty;
    final label = (quote.author != null && quote.author!.isNotEmpty)
        ? quote.author!
        : l.postQuotedExternal;

    final content = quote.text.isNotEmpty
        ? quote.text
        : (hasUri ? l.postQuotedOpenHint : '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasUri ? () => _open(context, quote.uri!) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.25),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.format_quote,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasUri)
                    Icon(Icons.open_in_new,
                        size: 12, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  content,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    fontStyle: quote.text.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String atUri) async {
    final httpUrl = _atUriToHttp(atUri);
    if (httpUrl == null) return;
    final uri = Uri.tryParse(httpUrl);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $httpUrl')),
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

  static String? _atUriToHttp(String atUri) {
    if (!atUri.startsWith('at://')) return null;
    final rest = atUri.substring(5);
    final parts = rest.split('/');
    if (parts.length != 3) return null;
    final did = parts[0];
    final collection = parts[1];
    final rkey = parts[2];
    if (collection != 'app.bsky.feed.post') return null;
    return 'https://bsky.app/profile/$did/post/$rkey';
  }
}