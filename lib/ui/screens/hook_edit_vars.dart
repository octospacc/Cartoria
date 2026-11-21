part of 'hook_edit.dart';

class _VarRow {
  final String id;
  final TextEditingController name;
  final TextEditingController value;

  _VarRow({
    required this.id,
    required this.name,
    required this.value,
  });

  factory _VarRow.empty() => _VarRow(
        id: const Uuid().v4(),
        name: TextEditingController(),
        value: TextEditingController(),
      );

  factory _VarRow.fromEntry(String name, String value) => _VarRow(
        id: const Uuid().v4(),
        name: TextEditingController(text: name),
        value: TextEditingController(text: value),
      );

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _VariableRow extends StatelessWidget {
  final _VarRow row;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _VariableRow({
    super.key,
    required this.row,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: TextField(
              controller: row.name,
              decoration: InputDecoration(
                labelText: l.hookVarNameLabel,
                hintText: l.hookVarNameHint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row.value,
              decoration: InputDecoration(
                labelText: l.hookVarValueLabel,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: l.hookVarRemove,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}