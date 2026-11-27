part of '../store.dart';

extension ArchiveOps on VaultStore {
  Future<Uint8List> exportSpaceZip(
    String spaceId, {
    ExportMediaMode mode = ExportMediaMode.full,
  }) async {
    final offloadedBlobs = <String, Uint8List>{};

    if (mode == ExportMediaMode.full) {
      final offloaded = _offloadedIdsBySpace[spaceId] ?? const <String>{};
      for (final fileId in offloaded) {
        try {
          offloadedBlobs[fileId] = await _drive.readBytes(spaceId, fileId);
        } catch (e) {
          throw StateError(
              'Could not fetch offloaded file $fileId for full export. '
              'Check the sync config and token, or export with a mode '
              'that skips offloaded files.');
        }
      }
    }

    return _archive.exportSpace(
      spaceId,
      mode: mode,
      offloadedBlobs: offloadedBlobs,
    );
  }

  Future<String> importSpaceZip(Uint8List zipBytes) async {
    final id = await _archive.importSpace(zipBytes);
    await reload();
    return id;
  }

  Future<SpaceImportResult> importSpaceZipIntoExistingSpace({
    required String targetSpaceId,
    required Uint8List zipBytes,
  }) async {
    final extracted = await _archive.readSpaceArchive(zipBytes);

    final existingPosts = _postCache[targetSpaceId] ?? const <Post>[];
    final existingIds = {for (final p in existingPosts) p.id};
    final existingUrls = <String>{
      for (final p in existingPosts)
        if (p.kind == PostKind.bookmark && p.url != null) p.url!,
    };
    final existingFileIds = <String>{
      for (final f in _fileCache[targetSpaceId] ?? const <DriveFile>[])
        if (!f.isMissing) f.id,
    };

    final referencedParents = <String>{
      for (final p in extracted.posts)
        if (p.parentId != null) p.parentId!,
    };

    final toImportPosts = <Post>[];
    var skippedDuplicates = 0;
    for (final p in extracted.posts) {
      if (existingIds.contains(p.id)) {
        skippedDuplicates++;
        continue;
      }
      if (p.kind == PostKind.bookmark &&
          p.url != null &&
          existingUrls.contains(p.url) &&
          !referencedParents.contains(p.id)) {
        skippedDuplicates++;
        continue;
      }
      toImportPosts.add(p);
    }

    final importedFiles = await _drive.importExistingFiles(
      spaceId: targetSpaceId,
      files: extracted.files,
      driveMeta: extracted.driveMeta,
      existingIds: existingFileIds,
    );
    final filesSkipped = extracted.files.length - importedFiles.length;

    final importedPosts = <Post>[];
    var failedPosts = 0;
    for (final p in toImportPosts) {
      try {
        final imported =
            await _posts.importExisting(spaceId: targetSpaceId, post: p);
        importedPosts.add(imported);
      } catch (e) {
        debugPrint('Failed to import post ${p.id}: $e');
        failedPosts++;
      }
    }

    if (importedPosts.isNotEmpty) {
      final seen = <String>{};
      final merged = <Post>[];
      for (final p in [
        ...(_postCache[targetSpaceId] ?? const <Post>[]),
        ...importedPosts,
      ]) {
        if (seen.add(p.id)) merged.add(p);
      }
      merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _postCache[targetSpaceId] = merged;
    }
    if (importedFiles.isNotEmpty) {
      _fileCache[targetSpaceId] = [
        ...(_fileCache[targetSpaceId] ?? const <DriveFile>[]),
        ...importedFiles,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final f in importedFiles) {
        _fileIndex.putIfAbsent(targetSpaceId, () => {})[f.id] = f;
      }
    }

    _resortSpacesByUsage();
    notifyInternal();

    return SpaceImportResult(
      total: extracted.posts.length,
      imported: importedPosts.length,
      skippedDuplicates: skippedDuplicates + failedPosts,
      filesImported: importedFiles.length,
      filesSkipped: filesSkipped,
    );
  }

  Future<Post> importPostFromSource({
    required String spaceId,
    required String source,
  }) async {
    final post = PostRepository.parseInlinePost(source);
    final existing = _postCache[spaceId] ?? const <Post>[];

    if (existing.any((p) => p.id == post.id)) {
      throw const FormatException(
        'A post with this ID already exists in this space.',
      );
    }
    if (post.kind == PostKind.bookmark && post.url != null) {
      if (existing.any(
          (p) => p.kind == PostKind.bookmark && p.url == post.url)) {
        throw const FormatException(
          'A bookmark with this URL already exists in this space.',
        );
      }
    }

    final imported =
        await _posts.importExisting(spaceId: spaceId, post: post);
    final list = _postCache.putIfAbsent(spaceId, () => []);
    if (!list.any((p) => p.id == imported.id)) {
      list.add(imported);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    _resortSpacesByUsage();
    notifyInternal();
    return imported;
  }

  Future<BookmarkImportResult> importBookmarksIntoSpace({
    required String spaceId,
    required BookmarkFile file,
  }) async {
    final existing = _postCache[spaceId] ?? const <Post>[];
    final existingUrls = {
      for (final p in existing)
        if (p.kind == PostKind.bookmark && p.url != null) p.url!,
    };
    final r = await _bookmarksImporter.importInto(
        spaceId: spaceId,
        bookmarks: file.bookmarks,
        existingUrls: existingUrls);
    if (r.created.isNotEmpty) {
      final seen = <String>{};
      final merged = <Post>[];
      for (final p in [...existing, ...r.created]) {
        if (seen.add(p.id)) merged.add(p);
      }
      merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _postCache[spaceId] = merged;
      _resortSpacesByUsage();
      notifyInternal();
    }
    return r.result;
  }

  Future<Space> importBookmarksAsNewSpace({
    required BookmarkFile file,
    required String spaceName,
    String icon = '📚',
  }) async {
    final space = await createSpace(name: spaceName, icon: icon);
    final r = await _bookmarksImporter.importInto(
        spaceId: space.id, bookmarks: file.bookmarks, existingUrls: const {});
    if (r.created.isNotEmpty) {
      _postCache[space.id] = List.of(r.created)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _resortSpacesByUsage();
      notifyInternal();
    }
    return space;
  }
}