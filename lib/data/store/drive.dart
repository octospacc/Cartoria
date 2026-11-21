part of '../store.dart';

extension DriveOps on VaultStore {
  Future<DriveFile> addFileFromBytes({
    required String spaceId,
    required Uint8List bytes,
    required String name,
  }) async {
    final file =
        await _drive.addBytes(spaceId: spaceId, bytes: bytes, name: name);
    _fileCache.putIfAbsent(spaceId, () => []).insert(0, file);
    _fileIndex.putIfAbsent(spaceId, () => {})[file.id] = file;
    notifyInternal();
    return file;
  }

  Future<Uint8List> readFileBytes(String spaceId, String fileId) =>
      _drive.readBytes(spaceId, fileId);

  Future<Uint8List> readImageBytes(String spaceId, String fileId) async {
    final key = '$spaceId:$fileId';
    final cached = _imageCache[key];
    if (cached != null) return cached;
    final bytes = await _drive.readBytes(spaceId, fileId);
    _imageCache[key] = bytes;
    return bytes;
  }

  Future<void> deleteFile(String spaceId, String fileId) async {
    await _drive.delete(spaceId, fileId);
    _fileCache[spaceId]?.removeWhere((x) => x.id == fileId);
    _fileIndex[spaceId]?.remove(fileId);
    _offloadedIdsBySpace[spaceId]?.remove(fileId);
    _imageCache.remove('$spaceId:$fileId');
    _imageAspectCache.remove('$spaceId:$fileId');
    _thumbBytesCache.remove('$spaceId:$fileId');
    notifyInternal();
  }

  Future<void> deleteFiles(String spaceId, Set<String> fileIds) async {
    if (fileIds.isEmpty) return;
    await _drive.deleteMultiple(spaceId, fileIds);
    _fileCache[spaceId]?.removeWhere((f) => fileIds.contains(f.id));
    for (final id in fileIds) {
      _fileIndex[spaceId]?.remove(id);
      _offloadedIdsBySpace[spaceId]?.remove(id);
      _imageCache.remove('$spaceId:$id');
      _imageAspectCache.remove('$spaceId:$id');
      _thumbBytesCache.remove('$spaceId:$id');
    }
    notifyInternal();
  }

  double? imageAspectRatio(String spaceId, String fileId) =>
      _imageAspectCache['$spaceId:$fileId'];

  void cacheImageAspect(String spaceId, String fileId, double ratio) {
    if (ratio <= 0 || !ratio.isFinite) return;
    _imageAspectCache['$spaceId:$fileId'] = ratio;
  }

  Set<String> usedFileIds(String spaceId) {
    final used = <String>{};
    for (final post in _postCache[spaceId] ?? const <Post>[]) {
      if (post.fileIds.isNotEmpty) used.addAll(post.fileIds);
    }
    return used;
  }

  Future<void> restoreMissingFile({
    required String spaceId,
    required String fileId,
    required Uint8List bytes,
    required String name,
  }) async {
    final restored = await _drive.restoreMissingFile(
      spaceId: spaceId,
      fileId: fileId,
      bytes: bytes,
      name: name,
    );

    final idx = _fileCache[spaceId]?.indexWhere((f) => f.id == fileId) ?? -1;
    if (idx >= 0) {
      _fileCache[spaceId]![idx] = restored;
    }
    _fileIndex[spaceId]?[fileId] = restored;

    _imageCache.remove('$spaceId:$fileId');
    _imageAspectCache.remove('$spaceId:$fileId');
    _thumbBytesCache.remove('$spaceId:$fileId');

    notifyInternal();
  }

  Future<void> fetchOffloadedFile(String spaceId, String fileId) async {
    final bytes = await _drive.readBytes(spaceId, fileId);
    await _drive.restoreFile(spaceId, fileId, bytes);

    final offloaded = await _offloadedStore.load(spaceId);
    _offloadedIdsBySpace[spaceId] = offloaded.keys.toSet();

    _imageCache['$spaceId:$fileId'] = bytes;

    final file = _fileIndex[spaceId]?[fileId];
    if (file != null) {
      final updated = DriveFile(
        id: file.id,
        name: file.name,
        sizeBytes: bytes.length,
        createdAt: file.createdAt,
      );
      _fileIndex[spaceId]![fileId] = updated;
      final idx = _fileCache[spaceId]?.indexWhere((f) => f.id == fileId) ?? -1;
      if (idx >= 0) _fileCache[spaceId]![idx] = updated;
    }

    notifyInternal();
  }

  Future<Uint8List> fetchThumbnailForOffloaded(
      String spaceId, String fileId) async {
    final info = await _offloadedStore.get(spaceId, fileId);
    if (info == null) throw StateError('File $fileId is not offloaded');

    final cached = await _thumbnailCache.get(info.remoteSha);
    if (cached != null) return cached;

    final full = await _drive.readBytes(spaceId, fileId);
    final thumb = await _makeThumbnail(full);
    await _thumbnailCache.put(info.remoteSha, thumb);
    return thumb;
  }

  Future<Uint8List> readImageThumbnail(String spaceId, String fileId) async {
    if (offloadedFileIds(spaceId).contains(fileId)) {
      return fetchThumbnailForOffloaded(spaceId, fileId);
    }

    final key = '$spaceId:$fileId';
    final cached = _thumbBytesCache[key];
    if (cached != null) return cached;

    await _acquireThumbSlot();
    try {
      final recheck = _thumbBytesCache[key];
      if (recheck != null) return recheck;

      final full = await _drive.readBytes(spaceId, fileId);
      final thumb = await _makeThumbnail(full);
      _thumbBytesCache[key] = thumb;
      _trimThumbCache();
      return thumb;
    } finally {
      _releaseThumbSlot();
    }
  }

  Future<Uint8List> _makeThumbnail(Uint8List full) async {
    try {
      final codec = await ui.instantiateImageCodec(full);
      final frame = await codec.getNextFrame();
      final srcW = frame.image.width;
      final srcH = frame.image.height;

      const maxDim = 256;

      if (srcW <= maxDim && srcH <= maxDim) {
        final byteData =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        frame.image.dispose();
        codec.dispose();
        return byteData!.buffer.asUint8List();
      }

      int targetW, targetH;
      if (srcW >= srcH) {
        targetW = maxDim;
        targetH = (maxDim * srcH / srcW).round().clamp(1, maxDim);
      } else {
        targetH = maxDim;
        targetW = (maxDim * srcW / srcH).round().clamp(1, maxDim);
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        frame.image,
        ui.Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble()),
        ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final scaled = await picture.toImage(targetW, targetH);
      final byteData = await scaled.toByteData(format: ui.ImageByteFormat.png);

      frame.image.dispose();
      scaled.dispose();
      picture.dispose();
      codec.dispose();
      return byteData!.buffer.asUint8List();
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
      return full;
    }
  }

  Future<void> _acquireThumbSlot() async {
    while (_thumbLoadsInFlight >= VaultStore._maxConcurrentThumbLoads) {
      final c = Completer<void>();
      _thumbLoadQueue.add(c);
      await c.future;
    }
    _thumbLoadsInFlight++;
  }

  void _releaseThumbSlot() {
    _thumbLoadsInFlight--;
    if (_thumbLoadQueue.isNotEmpty) {
      _thumbLoadQueue.removeAt(0).complete();
    }
  }

  void _trimThumbCache() {
    while (_thumbBytesCache.length > VaultStore._thumbCacheMaxEntries) {
      _thumbBytesCache.remove(_thumbBytesCache.keys.first);
    }
  }

  Set<String> offloadedFileIds(String spaceId) =>
      _offloadedIdsBySpace[spaceId] ?? const {};

  Future<OffloadedFileInfo?> offloadedInfoFor(String spaceId, String fileId) =>
      _offloadedStore.get(spaceId, fileId);

  ThumbnailCache get thumbnailCache => _thumbnailCache;

  Future<void> ensureFileLocal(String spaceId, String fileId) async {
    if (!offloadedFileIds(spaceId).contains(fileId)) return;
    await fetchOffloadedFile(spaceId, fileId);
  }
}