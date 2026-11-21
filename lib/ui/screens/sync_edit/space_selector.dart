part of '../sync_edit_screen.dart';

class _SpaceCheckboxes extends StatelessWidget {
  final _SyncEditScreenState state;
  const _SpaceCheckboxes({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;

    final localIds = <String>{};
    final localWidgets = <Widget>[];
    for (final s in state.widget.store.spaces) {
      localIds.add(s.id);
      final checked = state._spaceIds!.contains(s.id);
      localWidgets.add(CheckboxListTile(
        contentPadding: const EdgeInsets.only(left: 32, right: 0),
        dense: true,
        value: checked,
        title: Text('${s.icon} ${s.name}'),
        onChanged: state._busy
            ? null
            : (v) => state.setState(() {
                  if (v == true) {
                    state._spaceIds!.add(s.id);
                  } else {
                    state._spaceIds!.remove(s.id);
                  }
                }),
      ));
    }

    final remoteOnly = <({String id, String? name})>[];
    if (state._remoteSpaces != null) {
      for (final entry in state._remoteSpaces!.entries) {
        if (localIds.contains(entry.key)) continue;
        remoteOnly.add((id: entry.key, name: entry.value));
      }
      remoteOnly.sort((a, b) {
        final an = (a.name ?? a.id).toLowerCase();
        final bn = (b.name ?? b.id).toLowerCase();
        return an.compareTo(bn);
      });
    }

    final remoteWidgets = <Widget>[];
    for (final r in remoteOnly) {
      final checked = state._spaceIds!.contains(r.id);
      remoteWidgets.add(CheckboxListTile(
        contentPadding: const EdgeInsets.only(left: 32, right: 0),
        dense: true,
        value: checked,
        title: Row(
          children: [
            Expanded(
              child: Text(
                r.name ?? r.id,
                overflow: TextOverflow.ellipsis,
                style: r.name == null
                    ? theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      )
                    : null,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l.syncEditRemoteOnlyBadge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.name != null)
              Text(
                l.syncEditRemoteId(r.id),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              l.syncEditRemoteOnlySubtitle,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
        onChanged: state._busy
            ? null
            : (v) => state.setState(() {
                  if (v == true) {
                    state._spaceIds!.add(r.id);
                  } else {
                    state._spaceIds!.remove(r.id);
                  }
                }),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [...localWidgets, ...remoteWidgets],
    );
  }
}