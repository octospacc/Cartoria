import 'package:Cartoria/ui/screens/full_screen_text_editor.dart';
import 'package:Cartoria/l10n/l10n.dart';
import 'package:Cartoria/ui/widgets/quill_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _localizedApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  testWidgets('FullScreenTextEditor closes on ESC', (tester) async {
    final ctrl = quillFromHtml('<p>hello</p>');

    await tester.pumpWidget(_localizedApp(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenTextEditor(controller: ctrl),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(FullScreenTextEditor), findsOneWidget);

    await tester.tap(find.byType(FullScreenTextEditor));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(FullScreenTextEditor), findsNothing);
    ctrl.dispose();
  });
}