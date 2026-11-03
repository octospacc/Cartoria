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
  try {
    await store.init();
  } catch (e, st) {
    debugPrint('Store init failed: $e\n$st');
  }
  runApp(VaultApp(store: store));
}

class VaultApp extends StatelessWidget {
  final VaultStore store;
  const VaultApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: AnimatedBuilder(
        animation: store,
        builder: (_, __) {
          if (store.spaces.isEmpty) {
            return OnboardingScreen(store: store);
          }
          return SpaceListScreen(store: store);
        },
      ),
    );
  }
}