import 'package:Cartoria/ui/widgets/quill_bridge.dart';
import 'package:Cartoria/ui/widgets/rich_text_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RichTextEditor onEscape fires when ESC pressed and editor focused',
      (tester) async {
    var escaped = false;
    final ctrl = quillFromHtml('<p>hello</p>');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: RichTextEditor(
            controller: ctrl,
            expands: true,
            showToolbar: false,
            onEscape: () => escaped = true,
          ),
        ),
      ),
    ));

    await tester.tap(find.byType(RichTextEditor));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(escaped, isTrue);
    ctrl.dispose();
  });

  testWidgets('RichTextEditor without onEscape does not throw on ESC',
      (tester) async {
    final ctrl = quillFromHtml('<p>hello</p>');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: RichTextEditor(
            controller: ctrl,
            expands: true,
            showToolbar: false,
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(RichTextEditor));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    ctrl.dispose();
  });
}