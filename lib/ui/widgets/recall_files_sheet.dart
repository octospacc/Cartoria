import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../util/file_category.dart';
import 'file_thumbnail.dart';

/// Bottom sheet for selecting files from a space's drive to attach to a
/// post, reply, or edit. Consistent with the drive browsing screen: same
/// thumbnail rendering, grid-by-default with a grid/list toggle.
class RecallFilesSheet extends StatefulWidget {
  final VaultStore store;
  final Space space;

  const RecallFilesSheet({
    super.key,
    required this.store,
    required this.space,
  });

  /// Shows the sheet and returns the IDs of the selected files.
  /// Returns an empty list if the user cancels or selects nothing.
  static Future<List<String>> show(
    BuildContext context,
    VaultStore store,
    Space space,
  ) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RecallFilesSheet(store: store, space: space),
    );
    return result ?? const [];
  }

  @override
  State<RecallFilesSheet> createState() => _RecallFilesSheetState();
}

class _RecallFilesSheetState extends State<RecallFilesSheet> {
  bool _grid = true;
  final Set<String> _selected = {};

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = widget.store.filesForSpace(widget.space.id);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recall files',
                            style: theme.textTheme.titleMedium),
                        Text(
                          '${widget.space.name} · ${files.length} '
                          '${files.length == 1 ? "file" : "files"}',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                    tooltip: _grid ? 'List view' : 'Grid view',
                    onPressed: () => setState(() => _grid = !_grid),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: files.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Drive is empty',
                            textAlign: TextAlign.center),
                      ),
                    )
                  : (_grid
                      ? _buildGrid(files, scrollController)
                      : _buildList(files, scrollController)),
            ),
            // Footer
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Text(
                      _selected.isEmpty
                          ? 'No files selected'
                          : '${_selected.length} selected',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, _selected.toList()),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Attach'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrid(List<DriveFile> files, ScrollController controller) {
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final f = files[i];
        return _RecallGridTile(
          key: ValueKey(f.id),
          store: widget.store,
          spaceId: widget.space.id,
          file: f,
          selected: _selected.contains(f.id),
          onTap: () => _toggle(f.id),
        );
      },
    );
  }

  Widget _buildList(List<DriveFile> files, ScrollController controller) {
    return ListView.builder(
      controller: controller,
      itemCount: files.length,
      itemBuilder: (context, i) {
        final f = files[i];
        return CheckboxListTile(
          value: _selected.contains(f.id),
          onChanged: (_) => _toggle(f.id),
          secondary: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(iconForCategory(categoryFor(f.name)), size: 20),
          ),
          title: Text(f.name, overflow: TextOverflow.ellipsis),
          subtitle: Text('${(f.sizeBytes / 1024).toStringAsFixed(1)} KB'),
        );
      },
    );
  }
}

class _RecallGridTile extends StatelessWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  final bool selected;
  final VoidCallback onTap;

  const _RecallGridTile({
    super.key,
    required this.store,
    required this.spaceId,
    required this.file,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: selected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: FileThumbnail(
                    store: store,
                    spaceId: spaceId,
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
              right: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color:
                      selected ? theme.colorScheme.primary : Colors.black45,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}