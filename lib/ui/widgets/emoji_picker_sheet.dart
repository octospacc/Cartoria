import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

Future<void> showEmojiPickerSheet(
  BuildContext context,
  TextEditingController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EmojiPickerSheet(controller: controller),
  );
}

class _EmojiPickerSheet extends StatelessWidget {
  final TextEditingController controller;

  const _EmojiPickerSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.45,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Text(l.emojiTitle, style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l.emojiCloseTooltip,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: EmojiPicker(
              textEditingController: controller,
              onEmojiSelected: (_, __) {},
              config: Config(
                height: null,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 28 *
                      (defaultTargetPlatform == TargetPlatform.iOS
                          ? 1.2
                          : 1.0),
                ),
                viewOrderConfig: const ViewOrderConfig(
                  top: EmojiPickerItem.categoryBar,
                  middle: EmojiPickerItem.emojiView,
                  bottom: EmojiPickerItem.searchBar,
                ),
                skinToneConfig: const SkinToneConfig(),
                categoryViewConfig: const CategoryViewConfig(),
                bottomActionBarConfig: const BottomActionBarConfig(),
                searchViewConfig: const SearchViewConfig(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}