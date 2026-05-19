import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;

import '../models.dart';
import '../platform_paths.dart';
import 'file_list.dart';
import 'new_folder_dialog.dart';
import 'path_bar.dart';
import 'sidebar.dart';

class FileExplorerDialog extends StatefulWidget {
  final PickerMode mode;
  final String title;
  final String? initialFileName;
  final String? initialDirectory;
  final List<FileTypeFilter>? fileTypes;
  final List<QuickLocation>? quickLocations;

  const FileExplorerDialog({
    super.key,
    required this.mode,
    required this.title,
    this.initialFileName,
    this.initialDirectory,
    this.fileTypes,
    this.quickLocations,
  });

  @override
  State<FileExplorerDialog> createState() => _FileExplorerDialogState();
}

class _FileExplorerDialogState extends State<FileExplorerDialog> {
  Directory? _currentDir;
  List<FileListEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _selected = {};

  late final TextEditingController _fileNameCtrl;
  final FocusNode _fileNameFocus = FocusNode();

  List<QuickLocation> _quickLocations = const [];
  FileTypeFilter? _activeFilter;
  FileListSort _sortField = FileListSort.name;
  SortDirection _sortDir = SortDirection.ascending;

  bool get _isSaveMode => widget.mode == PickerMode.save;
  bool get _isDirMode => widget.mode == PickerMode.openDirectory;
  bool get _isMultiMode => widget.mode == PickerMode.openMulti;

  @override
  void initState() {
    super.initState();
    _fileNameCtrl = TextEditingController(text: widget.initialFileName ?? '');
    final types = widget.fileTypes;
    _activeFilter = (types == null || types.isEmpty) ? null : types.first;
    _bootstrap();
  }

  @override
  void dispose() {
    _fileNameCtrl.dispose();
    _fileNameFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _quickLocations = widget.quickLocations ??
        await PlatformPaths.defaultQuickLocations();

    Directory? start;
    if (widget.initialDirectory != null &&
        widget.initialDirectory!.isNotEmpty) {
      final d = Directory(widget.initialDirectory!);
      if (await d.exists()) start = d;
    }
    if (start == null) {
      try {
        start = await pp.getDownloadsDirectory();
      } catch (_) {}
    }
    if (start == null) {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.current.path;
      start = Directory(home);
    }

    await _loadDir(start);

    if (_isSaveMode && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fileNameFocus.requestFocus();
        _fileNameCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _fileNameCtrl.text.length,
        );
      });
    }
  }

  Future<void> _loadDir(Directory dir) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _selected.clear();
    });
    try {
      final raw = await dir.list(followLinks: false).toList();
      final entries = await Future.wait(raw.map(FileListEntry.fromEntity));
      if (!mounted) return;
      setState(() {
        _currentDir = dir;
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _navigateUp() async {
    final dir = _currentDir;
    if (dir == null) return;
    final parent = dir.parent;
    if (parent.path == dir.path) return;
    await _loadDir(parent);
  }

  void _onSidebarSelect(String path) {
    _loadDir(Directory(path));
  }

  void _onPathBarSelect(String path) {
    _loadDir(Directory(path));
  }

  void _onEntryTap(FileListEntry e) {
    if (_isMultiMode && !e.isDirectory) {
      setState(() {
        if (_selected.contains(e.entity.path)) {
          _selected.remove(e.entity.path);
        } else {
          _selected.add(e.entity.path);
        }
      });
      return;
    }
    setState(() {
      _selected
        ..clear()
        ..add(e.entity.path);
    });
    if (!_isDirMode && !e.isDirectory) {
      _fileNameCtrl.text = e.name;
    }
  }

  void _onEntryDoubleTap(FileListEntry e) {
    if (e.isDirectory) {
      _loadDir(Directory(e.entity.path));
      return;
    }
    if (_isSaveMode) {
      _fileNameCtrl.text = e.name;
      _confirm();
    } else if (!_isDirMode) {
      _confirm(path: e.entity.path);
    }
  }

  void _onSortChange(FileListSort field) {
    setState(() {
      if (_sortField == field) {
        _sortDir = _sortDir == SortDirection.ascending
            ? SortDirection.descending
            : SortDirection.ascending;
      } else {
        _sortField = field;
        _sortDir = SortDirection.ascending;
      }
    });
  }

  Future<void> _createNewFolder() async {
    final dir = _currentDir;
    if (dir == null) return;
    final name = await NewFolderDialog.show(context);
    if (name == null) return;
    try {
      final newDir = Directory(p.join(dir.path, name));
      if (!await newDir.exists()) {
        await newDir.create();
      }
      await _loadDir(dir);
    } catch (_) {}
  }

  Future<void> _confirm({String? path}) async {
    final dir = _currentDir;
    if (dir == null) return;

    if (_isSaveMode) {
      String name = _fileNameCtrl.text.trim();
      if (name.isEmpty) return;
      final filter = _activeFilter;
      if (filter != null && !filter.matchesAll && p.extension(name).isEmpty) {
        name = '$name.${filter.extensions.first}';
      }
      final fullPath = p.join(dir.path, name);
      if (await File(fullPath).exists()) {
        if (!mounted) return;
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Replace File?'),
            content: Text('"$name" already exists in this location. Replace it?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Replace'),
              ),
            ],
          ),
        );
        if (overwrite != true) return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(<String>[fullPath]);
      return;
    }

    if (_isDirMode) {
      Navigator.of(context).pop(<String>[dir.path]);
      return;
    }

    if (_isMultiMode) {
      if (_selected.isEmpty) return;
      Navigator.of(context).pop(_selected.toList());
      return;
    }

    final chosen = path ?? (_selected.isNotEmpty ? _selected.first : null);
    if (chosen == null) return;
    Navigator.of(context).pop(<String>[chosen]);
  }

  String get _confirmLabel {
    if (_isSaveMode) return 'Save';
    if (_isDirMode) return 'Select Folder';
    return 'Open';
  }

  IconData get _headerIcon {
    if (_isSaveMode) return Icons.save_outlined;
    if (_isDirMode) return Icons.folder_open_outlined;
    return Icons.file_open_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 900,
        height: 600,
        child: Column(
          children: [
            _buildHeader(cs),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Sidebar(
                    quickLocations: _quickLocations,
                    drivesLoader: PlatformPaths.drives,
                    currentPath: _currentDir?.path,
                    onLocationSelected: _onSidebarSelect,
                  ),
                  Expanded(child: _buildBody(cs)),
                ],
              ),
            ),
            _buildFooter(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_headerIcon, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.arrow_upward, size: 18),
                tooltip: 'Up one level',
                onPressed: _loading ? null : _navigateUp,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PathBar(
                  path: _currentDir?.path ?? '',
                  onPathSelected: _onPathBarSelect,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
                onPressed: _loading || _currentDir == null
                    ? null
                    : () => _loadDir(_currentDir!),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                tooltip: 'New folder',
                onPressed: _loading || _currentDir == null
                    ? null
                    : _createNewFolder,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 36),
              const SizedBox(height: 12),
              Text(
                'Could not open folder',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return FileList(
      entries: _entries,
      foldersOnly: _isDirMode,
      activeFilter: _activeFilter,
      selected: _selected,
      onTap: _onEntryTap,
      onDoubleTap: _onEntryDoubleTap,
      sortField: _sortField,
      sortDir: _sortDir,
      onSortChange: _onSortChange,
      autofocus: !_isSaveMode,
    );
  }

  Widget _buildFooter(ColorScheme cs) {
    final types = widget.fileTypes;
    final showTypeRow = !_isDirMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSaveMode) ...[
            _row(
              cs: cs,
              label: 'File name:',
              child: TextField(
                controller: _fileNameCtrl,
                focusNode: _fileNameFocus,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _confirm(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_isMultiMode && _selected.isNotEmpty) ...[
            _row(
              cs: cs,
              label: 'Selected:',
              child: Text(
                '${_selected.length} file${_selected.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 13, color: cs.onSurface),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (showTypeRow) ...[
                SizedBox(
                  width: 100,
                  child: Text(
                    _isSaveMode ? 'Save as type:' : 'Files of type:',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: (types == null || types.isEmpty)
                      ? Text(
                          'All files (*.*)',
                          style: TextStyle(fontSize: 13, color: cs.onSurface),
                        )
                      : DropdownButtonFormField<FileTypeFilter>(
                          initialValue: _activeFilter,
                          isDense: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            for (final ft in types)
                              DropdownMenuItem(
                                value: ft,
                                child: Text(
                                  ft.label,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _activeFilter = v),
                        ),
                ),
                const SizedBox(width: 12),
              ] else
                const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _confirm,
                icon: Icon(_headerIcon, size: 18),
                label: Text(_confirmLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row({
    required ColorScheme cs,
    required String label,
    required Widget child,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
