part of 'hook_edit.dart';

class _RuleRow {
  final String id;
  final TextEditingController when;
  final TextEditingController url;
  final TextEditingController body;
  String method;
  final List<_PartRow> parts;
  final List<MapEntry<TextEditingController, TextEditingController>> headers;

  _RuleRow({
    required this.id,
    required this.when,
    required this.url,
    required this.body,
    required this.method,
    required this.parts,
    required this.headers,
  });

  factory _RuleRow.empty() => _RuleRow(
        id: const Uuid().v4(),
        when: TextEditingController(),
        url: TextEditingController(),
        body: TextEditingController(),
        method: 'POST',
        parts: [],
        headers: [],
      );

  factory _RuleRow.fromRule(HookRule r) => _RuleRow(
        id: const Uuid().v4(),
        when: TextEditingController(text: r.when ?? ''),
        url: TextEditingController(text: r.urlTemplate),
        body: TextEditingController(text: r.bodyTemplate ?? ''),
        method: r.method,
        parts: r.multipartParts.map(_PartRow.fromPart).toList(),
        headers: r.headers.entries
            .map((e) => MapEntry(
                  TextEditingController(text: e.key),
                  TextEditingController(text: e.value),
                ))
            .toList(),
      );

  void dispose() {
    when.dispose();
    url.dispose();
    body.dispose();
    for (final p in parts) {
      p.dispose();
    }
    for (final h in headers) {
      h.key.dispose();
      h.value.dispose();
    }
  }
}

class _RuleCard extends StatelessWidget {
  final int index;
  final _RuleRow row;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _RuleCard({
    super.key,
    required this.index,
    required this.row,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasParts = row.parts.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(l.hookRuleTitle(index + 1),
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: row.when,
              decoration: InputDecoration(
                labelText: l.hookRuleWhenLabel,
                hintText: l.hookRuleWhenHint,
                helperText: l.hookRuleWhenHelper,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    value: row.method,
                    decoration:
                        InputDecoration(labelText: l.hookRuleMethodLabel),
                    items: const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      row.method = v ?? 'POST';
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.url,
                    decoration: InputDecoration(
                      labelText: l.hookRuleUrlLabel,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.body,
              enabled: !hasParts,
              decoration: InputDecoration(
                labelText: hasParts
                    ? l.hookRuleBodyLabelDisabled
                    : l.hookRuleBodyLabel,
                border: const OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 8,
            ),
            const SizedBox(height: 12),
            _header(context, l.hookRuleHeadersSection),
            ...row.headers.asMap().entries.map((e) {
              final i = e.key;
              final pair = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pair.key,
                        decoration: InputDecoration(
                            labelText: l.hookRuleHeaderNameLabel),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: pair.value,
                        decoration: InputDecoration(
                            labelText: l.hookRuleHeaderValueLabel),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        pair.key.dispose();
                        pair.value.dispose();
                        row.headers.removeAt(i);
                        onChanged();
                      },
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  row.headers.add(MapEntry(
                    TextEditingController(),
                    TextEditingController(),
                  ));
                  onChanged();
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.hookRuleAddHeader),
              ),
            ),
            const SizedBox(height: 12),
            _header(context, l.hookRuleMultipartSection),
            ...row.parts.asMap().entries.map((e) {
              final i = e.key;
              return _PartCard(
                key: ValueKey(e.value.id),
                row: e.value,
                onChanged: onChanged,
                onDelete: () {
                  e.value.dispose();
                  row.parts.removeAt(i);
                  onChanged();
                },
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  row.parts.add(_PartRow.empty());
                  onChanged();
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.hookRuleAddPart),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
      );
}