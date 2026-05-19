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

/// Internal mode used by the dialog widget.
enum PickerMode { save, openSingle, openMulti, openDirectory }
