part of '../drive.dart';

class _DriveListTile extends StatelessWidget {
  final DriveFile file;
  final bool isUsed;
  final bool isOffloaded;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(String action) onMenuAction;

  const _DriveListTile({
    super.key,
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
    return ListTile(
      selected: selectionMode && isSelected,
      selectedTileColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      leading: selectionMode
          ? Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            )
          : Icon(iconForCategory(categoryFor(file.name))),
      title: Text(file.name, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Text('${(file.sizeBytes / 1024).toStringAsFixed(1)} KB'),
          const SizedBox(width: 8),
          Icon(
            isUsed ? Icons.link : Icons.link_off,
            size: 12,
            color: isUsed
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 3),
          Text(
            isUsed ? l.driveUsageUsed : l.driveUsageUnused,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isUsed
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
          if (file.isMissing) ...[
            const SizedBox(width: 8),
            Icon(Icons.cloud_off, size: 12, color: theme.colorScheme.error),
            const SizedBox(width: 3),
            Text(l.driveStatusMissing,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ] else if (isOffloaded) ...[
            const SizedBox(width: 8),
            Icon(Icons.cloud,
                size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 3),
            Text(l.driveStatusRemote,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: selectionMode
          ? null
          : PopupMenuButton<String>(
              onSelected: onMenuAction,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'open', child: Text(l.driveOpen)),
                if (isUsed)
                  PopupMenuItem(
                      value: 'usage', child: Text(l.driveUsageAction)),
                PopupMenuItem(
                    value: 'share', child: Text(l.driveShareAction)),
                PopupMenuItem(
                    value: 'delete', child: Text(l.driveDeleteAction)),
              ],
            ),
    );
  }
}