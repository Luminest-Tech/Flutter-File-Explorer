import 'package:shared_preferences/shared_preferences.dart';

import 'path_utils.dart';

/// Persists the folders the user has recently navigated to / picked from, using
/// [SharedPreferences]. The key is namespaced to avoid colliding with the host
/// app's own preferences. All methods fail silently if storage is unavailable.
class RecentLocations {
  RecentLocations._();

  static const String _key = 'flutter_file_explorer.recent_locations';
  static const int _max = 12;

  /// Most-recent-first list of folder paths.
  static Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  /// Moves [path] to the front of the recent list (de-duplicated), trimming to
  /// the most recent [_max] entries.
  static Future<List<String>> record(String path) async {
    if (path.isEmpty) return const <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key)?.toList() ?? <String>[];
      list.removeWhere((p) => samePath(p, path));
      list.insert(0, path);
      if (list.length > _max) list.removeRange(_max, list.length);
      await prefs.setStringList(_key, list);
      return list;
    } catch (_) {
      return const <String>[];
    }
  }

  /// Clears the persisted recent list.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
