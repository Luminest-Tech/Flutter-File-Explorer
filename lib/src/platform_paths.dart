import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;

import 'models.dart';
import 'path_utils.dart';

class PlatformPaths {
  PlatformPaths._();

  /// Returns Desktop, Documents, Downloads, Pictures for the current user.
  /// Missing folders are silently skipped.
  static Future<List<QuickLocation>> defaultQuickLocations() async {
    final out = <QuickLocation>[];

    final desktop = _userSubdir('Desktop');
    if (desktop != null) {
      out.add(QuickLocation(
        label: 'Desktop',
        path: desktop,
        icon: Icons.desktop_windows_outlined,
      ));
    }

    final docs = await _safePath(pp.getApplicationDocumentsDirectory) ??
        _userSubdir('Documents');
    if (docs != null) {
      out.add(QuickLocation(
        label: 'Documents',
        path: docs,
        icon: Icons.description_outlined,
      ));
    }

    final downloads =
        await _safePath(pp.getDownloadsDirectory) ?? _userSubdir('Downloads');
    if (downloads != null) {
      out.add(QuickLocation(
        label: 'Downloads',
        path: downloads,
        icon: Icons.download_outlined,
      ));
    }

    final pictures = _userSubdir('Pictures');
    if (pictures != null) {
      out.add(QuickLocation(
        label: 'Pictures',
        path: pictures,
        icon: Icons.image_outlined,
      ));
    }

    return out;
  }

  /// On Windows, returns the user's pinned and frequent folders from the
  /// shell's Quick Access view (`shell:Quick Access`). Falls back to `null`
  /// on non-Windows or when the PowerShell query fails / times out.
  ///
  /// Requires Windows 10+. The COM lookup is best-effort and bounded by a
  /// 3-second timeout so it never blocks the dialog.
  static Future<List<QuickLocation>?> systemQuickAccess() async {
    if (!Platform.isWindows) return null;
    try {
      const script = r"""
$ErrorActionPreference = 'Stop'
$shell = New-Object -ComObject Shell.Application
$qa = $shell.NameSpace('shell:Quick Access')
if ($null -eq $qa) { '[]'; exit }
$items = @($qa.Items() | ForEach-Object {
  [PSCustomObject]@{ Name = $_.Name; Path = $_.Path }
})
ConvertTo-Json -Compress -InputObject $items
""";
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));

      if (result.exitCode != 0) return null;
      final raw = result.stdout.toString().trim();
      if (raw.isEmpty || raw == '[]') return null;

      final decoded = jsonDecode(raw);
      final list = decoded is List ? decoded : [decoded];

      final out = <QuickLocation>[];
      for (final entry in list) {
        if (entry is! Map) continue;
        final path = entry['Path']?.toString() ?? '';
        final name = entry['Name']?.toString() ?? '';
        if (path.isEmpty || name.isEmpty) continue;
        // Skip Recent Files entries (shell namespace items that aren't real folders).
        if (!Directory(path).existsSync()) continue;
        out.add(QuickLocation(
          label: name,
          path: path,
          icon: _iconForKnownPath(name) ?? Icons.push_pin_outlined,
        ));
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  static IconData? _iconForKnownPath(String label) {
    switch (label.toLowerCase()) {
      case 'desktop':
        return Icons.desktop_windows_outlined;
      case 'documents':
        return Icons.description_outlined;
      case 'downloads':
        return Icons.download_outlined;
      case 'pictures':
        return Icons.image_outlined;
      case 'music':
        return Icons.music_note_outlined;
      case 'videos':
        return Icons.movie_outlined;
      default:
        return null;
    }
  }

  /// Enumerate mounted drives / volumes for the current platform.
  ///
  /// - Windows probes `A:\ … Z:\` with a 600 ms timeout per letter (parallel).
  /// - macOS lists the boot disk plus each mount under `/Volumes`.
  /// - Linux lists the root filesystem plus mounts under `/media/$USER`,
  ///   `/run/media/$USER`, and `/mnt`.
  static Future<List<QuickLocation>> drives() async {
    if (Platform.isWindows) return _windowsDrives();
    if (Platform.isMacOS) return _macDrives();
    if (Platform.isLinux) return _linuxDrives();
    return const [
      QuickLocation(label: '/', path: '/', icon: Icons.storage_outlined),
    ];
  }

  static Future<List<QuickLocation>> _windowsDrives() async {
    final found = <QuickLocation>[];
    final futures = <Future<void>>[];
    for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++) {
      final letter = String.fromCharCode(c);
      final path = '$letter:\\';
      futures.add(() async {
        try {
          final exists = await Directory(path).exists().timeout(
                const Duration(milliseconds: 600),
                onTimeout: () => false,
              );
          if (exists) {
            found.add(QuickLocation(
              label: '$letter:',
              path: path,
              icon: Icons.storage_outlined,
            ));
          }
        } catch (_) {}
      }());
    }
    await Future.wait(futures);
    found.sort((a, b) => a.label.compareTo(b.label));
    return found;
  }

  static Future<List<QuickLocation>> _macDrives() async {
    final out = <QuickLocation>[
      const QuickLocation(
        label: 'Macintosh HD',
        path: '/',
        icon: Icons.storage_outlined,
      ),
    ];
    await _addMountChildren('/Volumes', out);
    return out;
  }

  static Future<List<QuickLocation>> _linuxDrives() async {
    final out = <QuickLocation>[
      const QuickLocation(
        label: 'File System',
        path: '/',
        icon: Icons.storage_outlined,
      ),
    ];
    final user =
        Platform.environment['USER'] ?? Platform.environment['USERNAME'];
    if (user != null && user.isNotEmpty) {
      await _addMountChildren('/media/$user', out);
      await _addMountChildren('/run/media/$user', out);
    }
    await _addMountChildren('/mnt', out);
    return out;
  }

  /// Adds each immediate subdirectory of [parent] as a drive entry, skipping
  /// duplicates and anything that resolves back to a path already listed.
  static Future<void> _addMountChildren(
    String parent,
    List<QuickLocation> out,
  ) async {
    try {
      final dir = Directory(parent);
      if (!await dir.exists()) return;
      final entries = await dir.list(followLinks: false).toList();
      entries.sort(
        (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
      );
      for (final e in entries) {
        if (e is! Directory) continue;
        if (out.any((q) => samePath(q.path, e.path))) continue;
        out.add(QuickLocation(
          label: p.basename(e.path),
          path: e.path,
          icon: Icons.storage_outlined,
        ));
      }
    } catch (_) {}
  }

  static String? _userSubdir(String name) {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;
    final candidate = p.join(home, name);
    return Directory(candidate).existsSync() ? candidate : null;
  }

  static Future<String?> _safePath(Future<Directory?> Function() fn) async {
    try {
      final d = await fn();
      return d?.path;
    } catch (_) {
      return null;
    }
  }
}
