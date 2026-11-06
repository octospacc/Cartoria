import 'sync_config.dart';

/// Determines which vault paths a sync config is responsible for.
///
/// Paths outside the scope are neither pushed, pulled, nor considered for
/// deletion by this config — they belong to some other config, or exist
/// on the remote as leftovers from a previous configuration.
class SyncScope {
  /// null = all spaces (current and future)
  /// empty = no spaces
  /// non-empty = exactly those space IDs
  final Set<String>? spaceIds;
  final bool includeVaultLevel;

  const SyncScope({this.spaceIds, required this.includeVaultLevel});

  factory SyncScope.forConfig(SyncConfig config) => SyncScope(
        spaceIds: config.spaceIds,
        includeVaultLevel: config.isPrimary,
      );

  /// True if [relPath] (relative to the vault root, forward-slash) is
  /// covered by this scope.
  bool includes(String relPath) {
    // Vault-level: hooks (.json legacy) or the hooks/ folder.
    if (relPath == 'hooks.json' || relPath.startsWith('hooks/')) {
      return includeVaultLevel;
    }
    // Any other top-level file (sync.json, etc.) is never synced.
    final sep = relPath.indexOf('/');
    if (sep < 0) return false;
    // Files inside a space directory.
    final spaceId = relPath.substring(0, sep);
    return spaceIds == null || spaceIds!.contains(spaceId);
  }
}