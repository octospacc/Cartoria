import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'data/store.dart';
import 'ui/screens/onboarding.dart';
import 'ui/screens/space_list.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final store = VaultStore();
  Object? initError;
  StackTrace? initStack;
  try {
    await store.init();
  } catch (e, st) {
    initError = e;
    initStack = st;
    debugPrint('Store init failed: $e\n$st');
  }
  runApp(VaultApp(store: store, initError: initError, initStack: initStack));
}

class VaultApp extends StatelessWidget {
  final VaultStore store;
  final Object? initError;
  final StackTrace? initStack;

  const VaultApp({
    super.key,
    required this.store,
    this.initError,
    this.initStack,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cartoria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: initError != null
          ? _InitErrorScreen(error: initError!, stack: initStack)
          : AnimatedBuilder(
              animation: store,
              builder: (_, __) {
                // Show onboarding only for genuinely new installs. A user who
                // has created spaces (or explicitly skipped) never sees it
                // again, even after deleting every space.
                if (!store.isOnboarded && store.spaces.isEmpty) {
                  return OnboardingScreen(store: store);
                }
                return SpaceListScreen(store: store);
              },
            ),
    );
  }
}

class _InitErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace? stack;

  const _InitErrorScreen({required this.error, this.stack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Startup error')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cartoria could not finish starting up. This is usually a '
            'permissions or disk issue, not a bug in the app.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              error.toString(),
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          if (stack != null) ...[
            const SizedBox(height: 12),
            Text(
              'Stack:',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            SelectableText(
              stack.toString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
