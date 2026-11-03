import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// Wraps [child] in an [AspectRatio] that tracks the video's actual
/// dimensions. Falls back to 16:9 until the player reports width/height.
class VideoAspect extends StatelessWidget {
  final Player player;
  final Widget child;
  const VideoAspect({super.key, required this.player, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: player.stream.width,
      initialData: player.state.width,
      builder: (context, wSnap) {
        return StreamBuilder<int?>(
          stream: player.stream.height,
          initialData: player.state.height,
          builder: (context, hSnap) {
            final w = wSnap.data;
            final h = hSnap.data;
            final ratio =
                (w != null && h != null && w > 0 && h > 0) ? w / h : 16.0 / 9.0;
            return AspectRatio(aspectRatio: ratio, child: child);
          },
        );
      },
    );
  }
}