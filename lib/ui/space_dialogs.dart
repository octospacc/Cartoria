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
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final maxAllowed = screenWidth * 0.9;
  final dialogWidth = 560.0 < maxAllowed ? 560.0 : maxAllowed;

  return showDialog<({String name, String icon})>(
    context: context,
    builder: (_) => _SpaceDialog(
      initialName: initialName,
      initialIcon: initialIcon,
      title: title,
      confirmLabel: confirmLabel,
      width: dialogWidth,
    ),
  );
}

class _SpaceDialog extends StatefulWidget {
  final String initialName;
  final String initialIcon;
  final String title;
  final String confirmLabel;
  final double width;

  const _SpaceDialog({
    required this.initialName,
    required this.initialIcon,
    required this.title,
    required this.confirmLabel,
    required this.width,
  });

  @override
  State<_SpaceDialog> createState() => _SpaceDialogState();
}

class _SpaceDialogState extends State<_SpaceDialog> {
  late final TextEditingController _nameCtrl;
  late String _icon;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _icon = widget.initialIcon;
  }

  @override
  void dispose() {
    // Called by the framework when the dialog route is fully torn down
    // — after the exit animation, not after `Navigator.pop`. Fixes the
    // "TextEditingController used after being disposed" crash that
    // occurred when ESC dismissed the dialog (Cancel happened to
    // complete the animation early enough that the crash didn't fire).
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, icon: _icon));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kSpaceIcons.map((i) {
                final selected = _icon == i;
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
                  onSelected: (_) => setState(() => _icon = i),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}