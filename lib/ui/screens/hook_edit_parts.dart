part of 'hook_edit.dart';

class _PartRow {
  final String id;
  final TextEditingController name;
  final TextEditingController value;
  final TextEditingController filename;
  final TextEditingController join;
  final TextEditingController prefix;
  final TextEditingController suffix;
  bool isFile;
  bool repeat;

  _PartRow({
    required this.id,
    required this.name,
    required this.value,
    required this.filename,
    required this.join,
    required this.prefix,
    required this.suffix,
    required this.isFile,
    required this.repeat,
  });

  factory _PartRow.empty() => _PartRow(
        id: const Uuid().v4(),
        name: TextEditingController(),
        value: TextEditingController(),
        filename: TextEditingController(),
        join: TextEditingController(),
        prefix: TextEditingController(),
        suffix: TextEditingController(),
        isFile: false,
        repeat: false,
      );

  factory _PartRow.fromPart(HookMultipartPart p) => _PartRow(
        id: const Uuid().v4(),
        name: TextEditingController(text: p.name),
        value: TextEditingController(text: p.template ?? p.filePath ?? ''),
        filename: TextEditingController(text: p.filename ?? ''),
        join: TextEditingController(text: p.join ?? ''),
        prefix: TextEditingController(text: p.prefix ?? ''),
        suffix: TextEditingController(text: p.suffix ?? ''),
        isFile: p.filePath != null,
        repeat: p.repeat != null,
      );

  void dispose() {
    name.dispose();
    value.dispose();
    filename.dispose();
    join.dispose();
    prefix.dispose();
    suffix.dispose();
  }
}

class _PartCard extends StatelessWidget {
  final _PartRow row;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _PartCard({
    super.key,
    required this.row,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.name,
                    decoration: InputDecoration(
                      labelText: l.hookPartNameLabel,
                      hintText: l.hookPartNameHint,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: false, label: Text(l.hookPartKindText)),
                    ButtonSegment(
                        value: true, label: Text(l.hookPartKindFile)),
                  ],
                  selected: {row.isFile},
                  onSelectionChanged: (s) {
                    row.isFile = s.first;
                    onChanged();
                  },
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: row.value,
              decoration: InputDecoration(
                labelText: row.isFile
                    ? l.hookPartFilePathLabel
                    : l.hookPartValueTemplateLabel,
              ),
              minLines: 1,
              maxLines: 4,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l.hookPartRepeatLabel),
              value: row.repeat,
              onChanged: (v) {
                row.repeat = v;
                onChanged();
              },
            ),
            if (row.repeat)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.join,
                      decoration: InputDecoration(
                        labelText: l.hookPartJoinLabel,
                        hintText: l.hookPartJoinHint,
                        helperText: l.hookPartJoinHelper,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: row.prefix,
                      decoration: InputDecoration(
                          labelText: l.hookPartPrefixLabel),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: row.suffix,
                      decoration: InputDecoration(
                          labelText: l.hookPartSuffixLabel),
                    ),
                  ),
                ],
              ),
            if (row.isFile && !row.repeat)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextField(
                  controller: row.filename,
                  decoration: InputDecoration(
                    labelText: l.hookPartFilenameLabel,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: Text(l.hookPartRemove),
              ),
            ),
          ],
        ),
      ),
    );
  }
}