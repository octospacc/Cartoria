import 'package:flutter/material.dart';

import '../../data/space_icons.dart';
import '../../data/store.dart';

class OnboardingScreen extends StatefulWidget {
  final VaultStore store;
  const OnboardingScreen({super.key, required this.store});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  String _icon = kSpaceIcons.first;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.createSpace(name: name, icon: _icon);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text('Create your first space',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                  'A space holds its own notes, bookmarks, and files. Spaces are independent — you can add more later.'),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _create(),
                decoration: const InputDecoration(
                  labelText: 'Space name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kSpaceIcons
                    .map((i) => ChoiceChip(
                          label: Text(i, style: const TextStyle(fontSize: 22)),
                          selected: _icon == i,
                          onSelected: (_) => setState(() => _icon = i),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Create space'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}