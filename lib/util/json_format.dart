import 'dart:convert';

const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

/// Pretty-prints [value] as 2-space-indented JSON with a trailing newline.
///
/// Git treats a missing final newline as "the last line is unterminated"
/// and shows it as `\ No newline at end of file` in diffs; ending with
/// `\n` avoids that. The 2-space indent matches `makeDocument`'s
/// frontmatter encoding so `drive_meta.json`, `hooks.json`, `sync.json`,
/// and post frontmatter all read with the same shape.
String prettyJson(Object? value) => '${_prettyEncoder.convert(value)}\n';