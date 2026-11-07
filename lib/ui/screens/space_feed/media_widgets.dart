import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../platform/file_save.dart';
import '../../../util/file_category.dart';

/// Compact row for a non-visual attachment (PDF, generic binary, etc.).
class FileRow extends StatelessWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;

  const FileRow({
    super.key,
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconFor(file.name)),
      title: Text(file.name, overflow: TextOverflow.ellipsis),
      subtitle: Text('${(file.sizeBytes / 1024).toStringAsFixed(1)} KB'),
      trailing: const Icon(Icons.ios_share, size: 16),
      onTap: () async {
        final bytes = await store.readFileBytes(spaceId, file.id);
        await saveOrShareFile(bytes, file.name);
      },
    );
  }

  IconData _iconFor(String name) {
    switch (categoryFor(name)) {
      case FileCategory.image:   return Icons.image;
      case FileCategory.video:   return Icons.videocam;
      case FileCategory.audio:   return Icons.audio_file;
      case FileCategory.text:    return Icons.description;
      case FileCategory.pdf:     return Icons.picture_as_pdf;
      case FileCategory.other:   return Icons.insert_drive_file;
    }
  }
}

class PlayCard extends StatelessWidget {
  final DriveFile file;
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const PlayCard({
    super.key,
    required this.file,
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '$label · ${(file.sizeBytes / 1024).toStringAsFixed(1)} KB',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MediaErrorCard extends StatelessWidget {
  final DriveFile file;
  final String message;
  final VoidCallback onRetry;

  const MediaErrorCard({
    super.key,
    required this.file,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: theme.textTheme.bodyMedium),
                Text(file.name,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class AudioControls extends StatelessWidget {
  final Player player;
  final DriveFile file;

  const AudioControls({
    super.key,
    required this.player,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.audiotrack, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  file.name,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StreamBuilder<Duration>(
                stream: player.stream.duration,
                initialData: player.state.duration,
                builder: (context, snap) {
                  final d = snap.data ?? Duration.zero;
                  return Text(_fmt(d), style: theme.textTheme.bodySmall);
                },
              ),
            ],
          ),
          Row(
            children: [
              StreamBuilder<bool>(
                stream: player.stream.playing,
                initialData: player.state.playing,
                builder: (context, snap) {
                  final playing = snap.data ?? false;
                  return IconButton(
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () =>
                        playing ? player.pause() : player.play(),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: player.stream.position,
                  initialData: player.state.position,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = player.state.duration;
                    final maxMs = dur.inMilliseconds
                        .clamp(1, double.infinity)
                        .toDouble();
                    final valMs = pos.inMilliseconds
                        .clamp(0, maxMs.toInt())
                        .toDouble();
                    return Slider(
                      value: valMs,
                      max: maxMs,
                      onChanged: (v) => player.seek(
                        Duration(milliseconds: v.toInt()),
                      ),
                    );
                  },
                ),
              ),
              StreamBuilder<Duration>(
                stream: player.stream.position,
                initialData: player.state.position,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(_fmt(pos),
                        style: theme.textTheme.bodySmall),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}