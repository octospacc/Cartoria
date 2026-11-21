part of '../drive.dart';

class _GridTile extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final DriveFile file;
  final bool isUsed;
  final bool isOffloaded;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(String action) onMenuAction;

  const _GridTile({
    super.key,
    required this.store,
    required this.space,
    required this.file,
    required this.isUsed,
    required this.isOffloaded,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: FileThumbnail(
                    store: store,
                    spaceId: space.id,
                    file: file,
                    iconSize: 40,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                  child: Text(
                    file.name,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isUsed ? Colors.black45 : theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  isUsed ? Icons.link : Icons.link_off,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
            if (isOffloaded)
              Positioned(
                top: 4,
                left: 30,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.cloud, size: 12, color: Colors.white),
                ),
              ),
            Positioned(
              top: 0,
              right: 0,
              child: selectionMode
                  ? Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    )
                  : Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        tooltip: l.driveMoreTooltip,
                        onSelected: onMenuAction,
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'open', child: Text(l.driveOpen)),
                          if (isUsed)
                            PopupMenuItem(
                                value: 'usage',
                                child: Text(l.driveUsageAction)),
                          PopupMenuItem(
                              value: 'share',
                              child: Text(l.driveShareAction)),
                          PopupMenuItem(
                              value: 'delete',
                              child: Text(l.driveDeleteAction)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}