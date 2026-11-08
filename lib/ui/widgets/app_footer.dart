import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';

/// Small attribution row at the bottom of the main screens. Tapping
/// opens [kProjectUrl] in the system browser.
///
/// The version string updates asynchronously once `PackageInfo` resolves
/// (one frame after first build on all platforms). While pending, the
/// footer shows just the app name without a version — no layout shift,
/// because the version text is appended to a single Row whose main-axis
/// size is ContentSize.
class AppFooter extends StatefulWidget {
  const AppFooter({super.key});

  @override
  State<AppFooter> createState() => _AppFooterState();
}

class _AppFooterState extends State<AppFooter> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    }).catchError((Object e) {
      debugPrint('Could not read package info: $e');
    });
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(kProjectUrl);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $kProjectUrl')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _info;
    final versionText = info == null
        ? ''
        : 'v${info.version}'
            '${info.buildNumber.isNotEmpty ? '+${info.buildNumber}' : ''}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _open,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cartoria',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (versionText.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        versionText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Icon(
                      Icons.open_in_new,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}