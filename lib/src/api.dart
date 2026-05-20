import 'package:flutter/material.dart';

import 'models.dart';
import 'strings.dart';
import 'widgets/file_explorer_dialog.dart';

/// Static entry points for the in-app file picker.
class FileExplorer {
  FileExplorer._();

  /// Save mode. Returns the absolute path the user chose, or `null` if cancelled.
  ///
  /// Set [dismissable] to `true` to let the user cancel by clicking the
  /// scrim outside the dialog. Defaults to `false`.
  ///
  /// - [iconBuilder] overrides the icon shown per entry (return `null` to fall
  ///   back to the default).
  /// - [strings] localizes every label (English by default).
  /// - [showHiddenFiles] sets the initial state of the hidden-files toggle.
  /// - [initialViewMode] picks the starting layout (details / large icons / tiles).
  static Future<String?> save(
    BuildContext context, {
    String title = 'Save As',
    required String initialFileName,
    String? initialDirectory,
    List<FileTypeFilter>? fileTypes,
    List<QuickLocation>? quickLocations,
    bool dismissable = false,
    FileIconBuilder? iconBuilder,
    FileExplorerStrings strings = const FileExplorerStrings(),
    bool showHiddenFiles = false,
    FileExplorerViewMode initialViewMode = FileExplorerViewMode.details,
  }) async {
    final result = await _show(
      context,
      mode: PickerMode.save,
      title: title,
      initialFileName: initialFileName,
      initialDirectory: initialDirectory,
      fileTypes: fileTypes,
      quickLocations: quickLocations,
      dismissable: dismissable,
      iconBuilder: iconBuilder,
      strings: strings,
      showHiddenFiles: showHiddenFiles,
      initialViewMode: initialViewMode,
    );
    return (result == null || result.isEmpty) ? null : result.first;
  }

  /// Open a single file. Returns the selected path or `null` if cancelled.
  static Future<String?> open(
    BuildContext context, {
    String title = 'Open',
    String? initialDirectory,
    List<FileTypeFilter>? fileTypes,
    List<QuickLocation>? quickLocations,
    bool dismissable = false,
    FileIconBuilder? iconBuilder,
    FileExplorerStrings strings = const FileExplorerStrings(),
    bool showHiddenFiles = false,
    FileExplorerViewMode initialViewMode = FileExplorerViewMode.details,
  }) async {
    final result = await _show(
      context,
      mode: PickerMode.openSingle,
      title: title,
      initialDirectory: initialDirectory,
      fileTypes: fileTypes,
      quickLocations: quickLocations,
      dismissable: dismissable,
      iconBuilder: iconBuilder,
      strings: strings,
      showHiddenFiles: showHiddenFiles,
      initialViewMode: initialViewMode,
    );
    return (result == null || result.isEmpty) ? null : result.first;
  }

  /// Open multiple files. Returns the selected paths or `null` if cancelled.
  static Future<List<String>?> openMulti(
    BuildContext context, {
    String title = 'Open',
    String? initialDirectory,
    List<FileTypeFilter>? fileTypes,
    List<QuickLocation>? quickLocations,
    bool dismissable = false,
    FileIconBuilder? iconBuilder,
    FileExplorerStrings strings = const FileExplorerStrings(),
    bool showHiddenFiles = false,
    FileExplorerViewMode initialViewMode = FileExplorerViewMode.details,
  }) async {
    final result = await _show(
      context,
      mode: PickerMode.openMulti,
      title: title,
      initialDirectory: initialDirectory,
      fileTypes: fileTypes,
      quickLocations: quickLocations,
      dismissable: dismissable,
      iconBuilder: iconBuilder,
      strings: strings,
      showHiddenFiles: showHiddenFiles,
      initialViewMode: initialViewMode,
    );
    return (result == null || result.isEmpty) ? null : result;
  }

  /// Pick a folder. Returns the directory path or `null` if cancelled.
  static Future<String?> openDirectory(
    BuildContext context, {
    String title = 'Select Folder',
    String? initialDirectory,
    List<QuickLocation>? quickLocations,
    bool dismissable = false,
    FileIconBuilder? iconBuilder,
    FileExplorerStrings strings = const FileExplorerStrings(),
    bool showHiddenFiles = false,
    FileExplorerViewMode initialViewMode = FileExplorerViewMode.details,
  }) async {
    final result = await _show(
      context,
      mode: PickerMode.openDirectory,
      title: title,
      initialDirectory: initialDirectory,
      quickLocations: quickLocations,
      dismissable: dismissable,
      iconBuilder: iconBuilder,
      strings: strings,
      showHiddenFiles: showHiddenFiles,
      initialViewMode: initialViewMode,
    );
    return (result == null || result.isEmpty) ? null : result.first;
  }

  static Future<List<String>?> _show(
    BuildContext context, {
    required PickerMode mode,
    required String title,
    String? initialFileName,
    String? initialDirectory,
    List<FileTypeFilter>? fileTypes,
    List<QuickLocation>? quickLocations,
    required bool dismissable,
    FileIconBuilder? iconBuilder,
    required FileExplorerStrings strings,
    required bool showHiddenFiles,
    required FileExplorerViewMode initialViewMode,
  }) {
    return showDialog<List<String>>(
      context: context,
      barrierDismissible: dismissable,
      builder: (_) => FileExplorerDialog(
        mode: mode,
        title: title,
        initialFileName: initialFileName,
        initialDirectory: initialDirectory,
        fileTypes: fileTypes,
        quickLocations: quickLocations,
        iconBuilder: iconBuilder,
        strings: strings,
        showHiddenFiles: showHiddenFiles,
        initialViewMode: initialViewMode,
      ),
    );
  }
}
