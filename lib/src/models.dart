import 'package:flutter/widgets.dart';

/// A named group of file extensions used to filter the file list and to
/// auto-append an extension when saving.
///
/// `extensions: ['*']` matches every file.
@immutable
class FileTypeFilter {
  final String label;
  final List<String> extensions;

  const FileTypeFilter({
    required this.label,
    required this.extensions,
  });

  bool get matchesAll => extensions.contains('*');

  bool matches(String fileName) {
    if (matchesAll) return true;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return false;
    final ext = fileName.substring(dot + 1).toLowerCase();
    return extensions.any((e) => e.toLowerCase() == ext);
  }
}

/// A sidebar entry that jumps directly to a folder.
@immutable
class QuickLocation {
  final String label;
  final String path;
  final IconData? icon;

  const QuickLocation({
    required this.label,
    required this.path,
    this.icon,
  });
}

/// Lightweight, public view of a file-list row passed to [FileIconBuilder] so
/// consumers can render custom icons without depending on internal types.
@immutable
class FileExplorerEntry {
  /// Absolute path of the entry.
  final String path;

  /// File or folder name (the last path segment).
  final String name;

  /// Whether the entry is a directory.
  final bool isDirectory;

  const FileExplorerEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
  });

  /// Lowercased extension without the leading dot, or `''` for folders and
  /// extension-less files.
  String get extension {
    if (isDirectory) return '';
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}

/// Builds a custom icon widget for [entry]. Return `null` to fall back to the
/// package's default icon for that entry.
typedef FileIconBuilder = Widget? Function(
  BuildContext context,
  FileExplorerEntry entry,
);

/// How the file list is laid out.
enum FileExplorerViewMode {
  /// Sortable rows with Name / Date modified / Type / Size columns.
  details,

  /// A grid of large icons with the file name beneath each.
  largeIcons,

  /// A grid of medium tiles showing icon, name, and type/size.
  tiles,
}

/// Internal mode used by the dialog widget.
enum PickerMode { save, openSingle, openMulti, openDirectory }
