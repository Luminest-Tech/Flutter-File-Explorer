import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;

import '../models.dart';
import '../platform_paths.dart';
import '../recent_locations.dart';
import '../strings.dart';
import 'file_list.dart';
import 'new_folder_dialog.dart';
import 'path_bar.dart';
import 'preview_pane.dart';
import 'sidebar.dart';
import 'status_bar.dart';

class FileExplorerDialog extends StatefulWidget {
  final PickerMode mode;
  final String title;
  final String? initialFileName;
  final String? initialDirectory;
  final List<FileTypeFilter>? fileTypes;
  final List<QuickLocation>? quickLocations;
  final FileExplorerStrings strings;
  final FileIconBuilder? iconBuilder;
  final bool showHiddenFiles;
  final FileExplorerViewMode initialViewMode;

  const FileExplorerDialog({
    super.key,
    required this.mode,
    required this.title,
    required this.strings,
    this.initialFileName,
    this.initialDirectory,
    this.fileTypes,
    this.quickLocations,
    this.iconBuilder,
    this.showHiddenFiles = false,
    this.initialViewMode = FileExplorerViewMode.details,
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
  List<QuickLocation> _recent = const [];
  FileTypeFilter? _activeFilter;
  FileListSort _sortField = FileListSort.name;
  SortDirection _sortDir = SortDirection.ascending;

  late FileExplorerViewMode _viewMode;
  late bool _showHidden;
  bool _showPreview = false;
  String? _previewPath;
  bool _previewIsDir = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _searching = false;
  List<FileListEntry> _searchResults = const [];
  int _searchGen = 0;
  Timer? _searchDebounce;

  bool _dragging = false;

  FileExplorerStrings get _s => widget.strings;
  bool get _isSaveMode => widget.mode == PickerMode.save;
  bool get _isDirMode => widget.mode == PickerMode.openDirectory;
  bool get _isMultiMode => widget.mode == PickerMode.openMulti;
  bool get _isSearchActive => _searchQuery.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _fileNameCtrl = TextEditingController(text: widget.initialFileName ?? '');
    final types = widget.fileTypes;
    _activeFilter = (types == null || types.isEmpty) ? null : types.first;
    _viewMode = widget.initialViewMode;
    _showHidden = widget.showHiddenFiles;
    _bootstrap();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _fileNameCtrl.dispose();
    _fileNameFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _quickLocations =
        widget.quickLocations ?? await PlatformPaths.defaultQuickLocations();

    if (widget.quickLocations == null) {
      // ignore: unawaited_futures
      PlatformPaths.systemQuickAccess().then((sysQa) {
        if (!mounted || sysQa == null || sysQa.isEmpty) return;
        setState(() => _quickLocations = sysQa);
      });
    }

    // ignore: unawaited_futures
    RecentLocations.load().then((paths) {
      if (!mounted) return;
      final locs = <QuickLocation>[];
      for (final path in paths) {
        if (!Directory(path).existsSync()) continue;
        locs.add(QuickLocation(
          label: p.basename(path).isEmpty ? path : p.basename(path),
          path: path,
          icon: Icons.history,
        ));
      }
      setState(() => _recent = locs);
    });

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
    // Cancel any in-flight search and reset search UI when navigating.
    _searchGen++;
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _loading = true;
      _error = null;
      _selected.clear();
      _searchQuery = '';
      _searching = false;
      _searchResults = const [];
      _previewPath = null;
    });
    try {
      final raw = await dir.list(followLinks: false).toList();
      final entries =
          await Future.wait(raw.map((e) => FileListEntry.fromEntity(e, _s)));
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

  void _onSidebarSelect(String path) => _loadDir(Directory(path));

  void _onPathBarSelect(String path) => _loadDir(Directory(path));

  List<FileListEntry> get _visible {
    final List<FileListEntry> list;
    if (_isSearchActive) {
      list = List.of(_searchResults);
    } else {
      final filter = _activeFilter;
      list = _entries.where((e) {
        if (!_showHidden && e.isHidden) return false;
        if (_isDirMode) return e.isDirectory;
        if (e.isDirectory) return true;
        if (filter == null || filter.matchesAll) return true;
        return filter.matches(e.name);
      }).toList();
    }
    list.sort(_compare);
    return list;
  }

  int _compare(FileListEntry a, FileListEntry b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    int result;
    switch (_sortField) {
      case FileListSort.name:
        result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        break;
      case FileListSort.modified:
        final am = a.modified?.millisecondsSinceEpoch ?? 0;
        final bm = b.modified?.millisecondsSinceEpoch ?? 0;
        result = am.compareTo(bm);
        break;
      case FileListSort.type:
        result = a.typeLabel.compareTo(b.typeLabel);
        if (result == 0) {
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        break;
      case FileListSort.size:
        result = (a.size ?? -1).compareTo(b.size ?? -1);
        break;
    }
    return _sortDir == SortDirection.ascending ? result : -result;
  }

  int? get _selectedBytes {
    if (_selected.isEmpty) return null;
    final src = _isSearchActive ? _searchResults : _entries;
    int total = 0;
    bool any = false;
    for (final e in src) {
      if (e.size != null && _selected.contains(e.entity.path)) {
        total += e.size!;
        any = true;
      }
    }
    return any ? total : null;
  }

  void _onEntryTap(FileListEntry e) {
    setState(() {
      _previewPath = e.entity.path;
      _previewIsDir = e.isDirectory;
      if (_isMultiMode && !e.isDirectory) {
        if (_selected.contains(e.entity.path)) {
          _selected.remove(e.entity.path);
        } else {
          _selected.add(e.entity.path);
        }
        return;
      }
      _selected
        ..clear()
        ..add(e.entity.path);
      if (!_isDirMode && !e.isDirectory) {
        _fileNameCtrl.text = e.name;
      }
    });
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

  // ---- Search ---------------------------------------------------------------

  void _onSearchChanged(String value) {
    _searchQuery = value;
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _searchGen++;
      setState(() {
        _searching = false;
        _searchResults = const [];
      });
      return;
    }
    setState(() {}); // reflect the cleared-vs-active state immediately
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(query);
    });
  }

  void _clearSearch() {
    _searchGen++;
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _searching = false;
      _searchResults = const [];
    });
  }

  Future<void> _runSearch(String query) async {
    final root = _currentDir;
    if (root == null) return;
    final gen = ++_searchGen;
    final q = query.toLowerCase();
    final filter = _activeFilter;
    setState(() {
      _searching = true;
      _searchResults = const [];
    });

    final results = <FileListEntry>[];
    final queue = Queue<Directory>()..add(root);
    try {
      while (queue.isNotEmpty) {
        if (gen != _searchGen) return;
        final dir = queue.removeFirst();
        List<FileSystemEntity> children;
        try {
          children = await dir.list(followLinks: false).toList();
        } catch (_) {
          continue;
        }
        for (final child in children) {
          if (gen != _searchGen) return;
          final isDir = child is Directory;
          if (isDir) queue.add(child);
          final name = p.basename(child.path);
          if (!name.toLowerCase().contains(q)) continue;
          if (_isDirMode && !isDir) continue;

          final entry = await FileListEntry.fromEntity(
            child,
            _s,
            location: _relativeLocation(root.path, child.path),
          );
          if (!_showHidden && entry.isHidden) continue;
          if (!isDir &&
              filter != null &&
              !filter.matchesAll &&
              !filter.matches(entry.name)) {
            continue;
          }
          results.add(entry);
          if (results.length >= 1000) {
            queue.clear();
            break;
          }
          if (results.length % 25 == 0) {
            if (gen != _searchGen) return;
            setState(() => _searchResults = List.of(results));
          }
        }
      }
    } catch (_) {}

    if (gen != _searchGen) return;
    setState(() {
      _searching = false;
      _searchResults = results;
    });
  }

  String _relativeLocation(String root, String fullPath) {
    final dir = p.dirname(fullPath);
    final rel = p.relative(dir, from: root);
    return rel == '.' ? '' : rel;
  }

  // ---- Actions --------------------------------------------------------------

  Future<void> _createNewFolder() async {
    final dir = _currentDir;
    if (dir == null) return;
    final name = await NewFolderDialog.show(context, _s);
    if (name == null) return;
    try {
      final newDir = Directory(p.join(dir.path, name));
      if (!await newDir.exists()) {
        await newDir.create();
      }
      await _loadDir(dir);
    } catch (_) {}
  }

  Future<void> _onDrop(List<String> paths) async {
    if (paths.isEmpty) return;
    final files = <String>[];
    final dirs = <String>[];
    for (final path in paths) {
      if (Directory(path).existsSync()) {
        dirs.add(path);
      } else if (File(path).existsSync()) {
        files.add(path);
      }
    }

    if (_isDirMode) {
      if (dirs.isNotEmpty) await _loadDir(Directory(dirs.first));
      return;
    }

    if (files.isEmpty) {
      if (dirs.isNotEmpty) await _loadDir(Directory(dirs.first));
      return;
    }

    if (_isSaveMode) {
      final first = files.first;
      _fileNameCtrl.text = p.basename(first);
      final parent = File(first).parent;
      if (await parent.exists()) await _loadDir(parent);
      return;
    }

    // open / openMulti: navigate to the first file's folder and select.
    final parent = File(files.first).parent;
    if (await parent.exists()) await _loadDir(parent);
    if (!mounted) return;
    setState(() {
      _selected.clear();
      if (_isMultiMode) {
        _selected.addAll(files);
      } else {
        _selected.add(files.first);
      }
      _previewPath = files.first;
      _previewIsDir = false;
    });
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
            title: Text(_s.replaceTitle),
            content: Text(_s.replaceMessage(name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(_s.cancelButton),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(_s.replaceButton),
              ),
            ],
          ),
        );
        if (overwrite != true) return;
      }
      if (!mounted) return;
      _recordRecent(dir.path);
      Navigator.of(context).pop(<String>[fullPath]);
      return;
    }

    if (_isDirMode) {
      _recordRecent(dir.path);
      Navigator.of(context).pop(<String>[dir.path]);
      return;
    }

    if (_isMultiMode) {
      if (_selected.isEmpty) return;
      _recordRecent(File(_selected.first).parent.path);
      Navigator.of(context).pop(_selected.toList());
      return;
    }

    final chosen = path ?? (_selected.isNotEmpty ? _selected.first : null);
    if (chosen == null) return;
    _recordRecent(File(chosen).parent.path);
    Navigator.of(context).pop(<String>[chosen]);
  }

  void _recordRecent(String dirPath) {
    // ignore: unawaited_futures
    RecentLocations.record(dirPath);
  }

  String get _confirmLabel {
    if (_isSaveMode) return _s.saveButton;
    if (_isDirMode) return _s.selectFolderButton;
    return _s.openButton;
  }

  IconData get _headerIcon {
    if (_isSaveMode) return Icons.save_outlined;
    if (_isDirMode) return Icons.folder_open_outlined;
    return Icons.file_open_outlined;
  }

  // ---- Keyboard -------------------------------------------------------------

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_isSearchActive) {
        _clearSearch();
        return KeyEventResult.handled;
      }
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      if (_isSearchActive) return KeyEventResult.ignored;
      if (!_loading) _navigateUp();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = _visible;
    return Focus(
      onKeyEvent: _handleKey,
      child: Dialog(
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
                      recentLocations: _recent,
                      drivesLoader: PlatformPaths.drives,
                      currentPath: _currentDir?.path,
                      onLocationSelected: _onSidebarSelect,
                      strings: _s,
                    ),
                    Expanded(child: _buildBody(cs, visible)),
                    if (_showPreview)
                      PreviewPane(
                        path: _previewPath,
                        isDirectory: _previewIsDir,
                        strings: _s,
                      ),
                  ],
                ),
              ),
              StatusBar(
                itemCount: visible.length,
                selectedCount: _selected.length,
                selectedBytes: _selectedBytes,
                strings: _s,
              ),
              _buildFooter(cs),
            ],
          ),
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
                tooltip: _s.cancelTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.arrow_upward, size: 18),
                tooltip: _s.upTooltip,
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
              _buildSearchField(cs),
            ],
          ),
          const SizedBox(height: 8),
          // Thin action row: view controls on the left, folder actions right.
          SizedBox(
            height: 36,
            child: Row(
              children: [
                _buildHiddenToggle(cs),
                _buildViewMenu(cs),
                _buildPreviewToggle(cs),
                const Spacer(),
                IconButton.outlined(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: _s.refreshTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: _loading || _currentDir == null
                      ? null
                      : () => _loadDir(_currentDir!),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  tooltip: _s.newFolderTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      _loading || _currentDir == null ? null : _createNewFolder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ColorScheme cs) {
    return SizedBox(
      width: 190,
      height: 40,
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          isDense: true,
          hintText: _s.searchHint,
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _isSearchActive
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  tooltip: _s.cancelTooltip,
                  onPressed: _clearSearch,
                )
              : null,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildHiddenToggle(ColorScheme cs) {
    return IconButton(
      icon: Icon(_showHidden ? Icons.visibility : Icons.visibility_off,
          size: 18),
      tooltip: _showHidden ? _s.hideHiddenTooltip : _s.showHiddenTooltip,
      isSelected: _showHidden,
      visualDensity: VisualDensity.compact,
      color: _showHidden ? cs.primary : null,
      onPressed: () => setState(() => _showHidden = !_showHidden),
    );
  }

  Widget _buildViewMenu(ColorScheme cs) {
    return PopupMenuButton<FileExplorerViewMode>(
      tooltip: _s.viewModeTooltip,
      icon: const Icon(Icons.grid_view_outlined, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      initialValue: _viewMode,
      onSelected: (m) => setState(() => _viewMode = m),
      itemBuilder: (context) => [
        _viewItem(FileExplorerViewMode.details, Icons.view_list_outlined,
            _s.detailsViewLabel),
        _viewItem(FileExplorerViewMode.largeIcons, Icons.grid_view_outlined,
            _s.largeIconsViewLabel),
        _viewItem(FileExplorerViewMode.tiles, Icons.view_comfy_outlined,
            _s.tilesViewLabel),
      ],
    );
  }

  PopupMenuItem<FileExplorerViewMode> _viewItem(
    FileExplorerViewMode mode,
    IconData icon,
    String label,
  ) {
    final active = _viewMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Text(label),
          if (active) ...[
            const Spacer(),
            const Icon(Icons.check, size: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewToggle(ColorScheme cs) {
    return IconButton(
      icon: const Icon(Icons.vertical_split_outlined, size: 18),
      tooltip: _showPreview ? _s.hidePreviewTooltip : _s.showPreviewTooltip,
      isSelected: _showPreview,
      visualDensity: VisualDensity.compact,
      color: _showPreview ? cs.primary : null,
      onPressed: () => setState(() => _showPreview = !_showPreview),
    );
  }

  Widget _buildBody(ColorScheme cs, List<FileListEntry> visible) {
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
                _s.couldNotOpenFolder,
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

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        _onDrop(detail.files.map((f) => f.path).toList());
      },
      child: Stack(
        children: [
          Column(
            children: [
              if (_searching) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: FileList(
                  entries: visible,
                  viewMode: _viewMode,
                  selected: _selected,
                  onTap: _onEntryTap,
                  onDoubleTap: _onEntryDoubleTap,
                  sortField: _sortField,
                  sortDir: _sortDir,
                  onSortChange: _onSortChange,
                  iconBuilder: widget.iconBuilder,
                  strings: _s,
                  autofocus: !_isSaveMode,
                  searchMode: _isSearchActive,
                  emptyMessage:
                      _isSearchActive ? _s.noSearchResults : _s.emptyFolder,
                ),
              ),
            ],
          ),
          if (_dragging) _buildDropOverlay(cs),
        ],
      ),
    );
  }

  Widget _buildDropOverlay(ColorScheme cs) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: cs.primary.withValues(alpha: 0.08),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_download_outlined, color: cs.primary),
                const SizedBox(width: 12),
                Text(
                  _s.dropHint,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
              label: _s.fileNameLabel,
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
              label: _s.selectedLabel,
              child: Text(
                _s.selectionSummary(
                  _selected.length,
                  _selectedBytes != null && _selectedBytes! > 0
                      ? formatBytes(_selectedBytes!)
                      : '',
                ),
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
                    _isSaveMode ? _s.saveAsTypeLabel : _s.filesOfTypeLabel,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: (types == null || types.isEmpty)
                      ? Text(
                          _s.allFilesLabel,
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
                child: Text(_s.cancelButton),
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
