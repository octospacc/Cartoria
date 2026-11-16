import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nX on BuildContext {
  /// Shorthand for `AppLocalizations.of(context)` with `nullable-getter:
  /// false` in `l10n.yaml` — always non-null once inside a MaterialApp
  /// with the generated delegates installed.
  AppLocalizations get l10n => AppLocalizations.of(this);
}