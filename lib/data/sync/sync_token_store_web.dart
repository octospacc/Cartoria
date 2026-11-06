import 'package:fs_shim/fs_shim.dart';
import 'package:web/web.dart' as web;

/// Provider tokens, stored in `localStorage`.
///
/// The web has no persistent app-private filesystem analogous to
/// `getApplicationSupportDirectory()`. `localStorage` is the correct
/// destination for a handful of opaque token strings — same-origin,
/// survives reloads, accessible only to this app's origin.
///
/// The [fs] parameter is accepted for signature compatibility with the
/// IO implementation but is unused.
class SyncTokenStore {
  final FileSystem fs;
  const SyncTokenStore({required this.fs});

  static const _prefix = 'cartoria_sync_token_';

  Future<String?> load(String key) async {
    try {
      return web.window.localStorage.getItem('$_prefix$key');
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String key, String token) async {
    try {
      web.window.localStorage.setItem('$_prefix$key', token);
    } catch (e) {
      // Thrown when storage is disabled (private mode with quota 0,
      // or the origin's quota exceeded).
      throw StateError('Could not persist token in browser storage: $e');
    }
  }

  Future<void> delete(String key) async {
    try {
      web.window.localStorage.removeItem('$_prefix$key');
    } catch (_) {}
  }
}