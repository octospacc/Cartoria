import 'package:flutter/material.dart';

import '../data/space_icons.dart';

/// Single dialog used for both creating a new space and editing an
/// existing one. The caller supplies [initialName], [initialIcon], the
/// title, and the confirm button label — everything else is shared.
///
/// The dialog is wide enough to show ~11 icon chips per row at normal
/// desktop widths and clamps to 90% of screen width on smaller devices.
Future<({String name, String icon})?> showSpaceDialog(
  BuildContext context, {
  required String initialName,
  required String initialIcon,
  String title = 'New space',
  String confirmLabel = 'Create',
}) async {
  final c = TextEditingController(text: initialName);
  var icon = initialIcon;

  final screenWidth = MediaQuery.sizeOf(context).width;
  final maxAllowed = screenWidth * 0.9;
  final dialogWidth = 560.0 < maxAllowed ? 560.0 : maxAllowed;

  final result = await showDialog<({String name, String icon})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          scrollable: true,
          title: Text(title),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: c,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kSpaceIcons.map((i) {
                    final selected = icon == i;
                    return ChoiceChip(
                      label: Text(i, style: const TextStyle(fontSize: 20)),
                      selected: selected,
                      showCheckmark: false,
                      avatar: selected
                          ? Icon(
                              Icons.check,
                              size: 18,
                              color: theme.colorScheme.onSecondaryContainer,
                            )
                          : const SizedBox(width: 18, height: 18),
                      onSelected: (_) => setS(() => icon = i),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = c.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, (name: name, icon: icon));
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
  c.dispose();
  return result;
}