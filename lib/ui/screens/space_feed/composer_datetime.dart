part of 'composer.dart';

class _DateTimeChip extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateTimeChip({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final v = value;

    if (v == null) {
      return IconButton(
        icon: const Icon(Icons.schedule),
        tooltip: l.composerSetDateTime,
        onPressed: () async {
          final picked = await _pickPostDateTime(context);
          if (picked != null) onChanged(picked);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final picked = await _pickPostDateTime(context, initial: v);
            if (picked != null) onChanged(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule,
                    size: 14, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 4),
                Text(
                  _formatPostDateTime(context, v),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onChanged(null),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close,
                        size: 12,
                        color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateTimeRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final v = value;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.composerPostedAt,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  v == null
                      ? l.composerPostedNow
                      : _formatPostDateTime(context, v),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (v != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: l.composerResetTime,
              onPressed: () => onChanged(null),
            ),
          TextButton(
            onPressed: () async {
              final picked = await _pickPostDateTime(context, initial: v);
              if (picked != null) onChanged(picked);
            },
            child: Text(
              v == null ? l.composerSetTime : l.composerChangeTime,
            ),
          ),
        ],
      ),
    );
  }
}