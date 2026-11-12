import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Opens the emoji picker in a bottom sheet. Emojis insert directly
/// into [controller] at the current cursor position (or replace the
/// current selection) — no need to read the return value.
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
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.45,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Text('Emoji', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
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
                // `null` lets the Expanded fill the sheet; the picker's
                // internal view handles its own scrolling.
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