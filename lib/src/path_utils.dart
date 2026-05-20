import 'dart:io';

/// Whether two paths point at the same location. Case-insensitive and
/// separator-insensitive on Windows; case-sensitive on POSIX. Trailing
/// separators are ignored.
bool samePath(String a, String b) {
  if (Platform.isWindows) {
    String norm(String s) =>
        s.replaceAll('/', r'\').replaceAll(RegExp(r'\\+$'), '').toLowerCase();
    return norm(a) == norm(b);
  }
  String norm(String s) => s.replaceAll(RegExp(r'/+$'), '');
  return norm(a) == norm(b);
}

/// Expands environment variables and a leading `~` in a user-typed path.
///
/// Supports Windows `%VAR%` and POSIX `$VAR` / `${VAR}` syntax. Unknown
/// variables are left untouched. `Platform.environment` is case-insensitive on
/// Windows, so `%userprofile%` and `%USERPROFILE%` both resolve.
String expandPath(String input) {
  var s = input.trim();
  if (s.isEmpty) return s;

  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    if (s == '~') {
      s = home;
    } else if (s.startsWith('~/') || s.startsWith(r'~\')) {
      s = home + s.substring(1);
    }
  }

  // Windows %VAR%
  s = s.replaceAllMapped(RegExp(r'%([^%]+)%'), (m) {
    final value = Platform.environment[m[1]!];
    return value ?? m[0]!;
  });

  // POSIX ${VAR}
  s = s.replaceAllMapped(RegExp(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}'), (m) {
    final value = Platform.environment[m[1]!];
    return value ?? m[0]!;
  });

  // POSIX $VAR
  s = s.replaceAllMapped(RegExp(r'\$([A-Za-z_][A-Za-z0-9_]*)'), (m) {
    final value = Platform.environment[m[1]!];
    return value ?? m[0]!;
  });

  return s;
}
