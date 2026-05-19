import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;

import 'models.dart';

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

  /// Enumerate mounted drives. Windows probes A:\ ... Z:\ with a short timeout.
  /// Non-Windows returns `[ '/' ]`.
  static Future<List<QuickLocation>> drives() async {
    if (!Platform.isWindows) {
      return const [
        QuickLocation(
          label: '/',
          path: '/',
          icon: Icons.storage_outlined,
        ),
      ];
    }
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
