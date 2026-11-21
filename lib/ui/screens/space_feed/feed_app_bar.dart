part of '../space_feed.dart';

extension _FeedAppBarExt on _SpaceFeedScreenState {
  PreferredSizeWidget _buildAppBar() {
    final l = context.l10n;
    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l.feedExitSelection,
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          _selectedPostIds.isEmpty
              ? l.feedSelectPosts
              : l.feedSelectedCount(_selectedPostIds.length),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l.feedDeleteSelected,
            onPressed: _selectedPostIds.isEmpty ? null : _deleteSelectedPosts,
          ),
        ],
      );
    }

    return AppBar(
      leading: _searchActive
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: l.feedSearchClose,
              onPressed: () => _setStateSafe(() {
                _searchCtrl.clear();
                _searchActive = false;
              }),
            )
          : null,
      title: _searchActive
          ? TextField(
              controller: _searchCtrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.feedSearchHint,
                border: InputBorder.none,
              ),
              onChanged: (_) => _setStateSafe(() {}),
            )
          : Text('${_space.icon} ${_space.name}'),
      actions: _searchActive
          ? [
              if (_searchCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l.feedSearchClear,
                  onPressed: () => _setStateSafe(_searchCtrl.clear),
                ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: l.feedSelect,
                onPressed: () => _enterSelectionMode(),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: l.feedSearchHint,
                onPressed: () => _setStateSafe(() => _searchActive = true),
              ),
              IconButton(
                icon: const Icon(Icons.folder),
                tooltip: l.feedDrive,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriveScreen(
                      store: widget.store,
                      space: _space,
                      onViewPostInFeed: (postId) {
                        Navigator.of(context).pop();
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (mounted) _scrollToPost(postId);
                        });
                      },
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'stats') {
                    SpaceStatsDialog.show(context, widget.store, _space);
                  }
                  if (v == 'edit') _editSpace();
                  if (v == 'import') _importFile();
                  if (v == 'import-source') _pastePostSource();
                  if (v == 'export') {
                    exportSpaceZip(context, widget.store, _space);
                  }
                  if (v == 'delete') _deleteSpace();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'stats', child: Text(l.spacesStatistics)),
                  PopupMenuItem(value: 'edit', child: Text(l.spacesEdit)),
                  PopupMenuItem(value: 'import', child: Text(l.feedMenuImport)),
                  PopupMenuItem(
                      value: 'import-source',
                      child: Text(l.feedMenuImportSource)),
                  PopupMenuItem(value: 'export', child: Text(l.spacesExport)),
                  PopupMenuItem(value: 'delete', child: Text(l.spacesDelete)),
                ],
              ),
            ],
    );
  }
}