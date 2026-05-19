import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../file_icons.dart';
import '../models.dart';

enum FileListSort { name, modified, type, size }
enum SortDirection { ascending, descending }

/// One row of the file list, with cached stat info.
class FileListEntry {
  final FileSystemEntity entity;
  final bool isDirectory;
  final String name;
  final DateTime? modified;
  final int? size;
  final String typeLabel;

  FileListEntry({
    required this.entity,
    required this.isDirectory,
    required this.name,
    required this.modified,
    required this.size,
    required this.typeLabel,
  });

  static Future<FileListEntry> fromEntity(FileSystemEntity e) async {
    final isDir = e is Directory;
    DateTime? modified;
    int? size;
    try {
      final stat = await e.stat();
      modified = stat.modified;
      if (!isDir) size = stat.size;
    } catch (_) {}
    final name = p.basename(e.path);
    return FileListEntry(
      entity: e,
      isDirectory: isDir,
      name: name,
      modified: modified,
      size: size,
      typeLabel: FileIcons.typeLabel(name, isDirectory: isDir),
    );
  }
}

class FileList extends StatefulWidget {
  final List<FileListEntry> entries;
  final bool foldersOnly;
  final FileTypeFilter? activeFilter;
  final Set<String> selected;
  final ValueChanged<FileListEntry> onTap;
  final ValueChanged<FileListEntry> onDoubleTap;
  final FileListSort sortField;
  final SortDirection sortDir;
  final ValueChanged<FileListSort> onSortChange;
  final bool autofocus;

  const FileList({
    super.key,
    required this.entries,
    required this.foldersOnly,
    required this.activeFilter,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.sortField,
    required this.sortDir,
    required this.onSortChange,
    this.autofocus = false,
  });

  @override
  State<FileList> createState() => _FileListState();
}

class _FileListState extends State<FileList> {
  static const double _rowHeight = 28;
  final FocusNode _focusNode = FocusNode(debugLabel: 'FileList');
  final ScrollController _scroll = ScrollController();
  String _typeahead = '';
  Timer? _typeaheadTimer;
  final _dateFormat = DateFormat('M/d/yyyy h:mm a');

  @override
  void dispose() {
    _typeaheadTimer?.cancel();
    _focusNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<FileListEntry> get _visible {
    final filter = widget.activeFilter;
    final list = widget.entries.where((e) {
      if (widget.foldersOnly) return e.isDirectory;
      if (e.isDirectory) return true;
      if (filter == null) return true;
      return filter.matches(e.name);
    }).toList();
    list.sort(_compare);
    return list;
  }

  int _compare(FileListEntry a, FileListEntry b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    int result;
    switch (widget.sortField) {
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
    return widget.sortDir == SortDirection.ascending ? result : -result;
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final char = event.character;
    if (char == null || char.isEmpty) return;
    if (!RegExp(r'^[A-Za-z0-9._-]$').hasMatch(char)) return;
    _typeahead += char.toLowerCase();
    _typeaheadTimer?.cancel();
    _typeaheadTimer = Timer(const Duration(milliseconds: 750), () {
      _typeahead = '';
    });
    final entries = _visible;
    final idx = entries.indexWhere(
      (e) => e.name.toLowerCase().startsWith(_typeahead),
    );
    if (idx >= 0) {
      widget.onTap(entries[idx]);
      _scroll.animateTo(
        (idx * _rowHeight).clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = _visible;

    return Column(
      children: [
        _buildHeader(cs),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    'This folder is empty',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : KeyboardListener(
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  onKeyEvent: _onKey,
                  child: ListView.builder(
                    controller: _scroll,
                    itemCount: visible.length,
                    itemExtent: _rowHeight,
                    itemBuilder: (context, i) => _buildRow(cs, visible[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          _headerCell(cs, 'Name', FileListSort.name, flex: 5),
          _headerCell(cs, 'Date modified', FileListSort.modified, flex: 3),
          _headerCell(cs, 'Type', FileListSort.type, flex: 2),
          _headerCell(cs, 'Size', FileListSort.size, flex: 1),
        ],
      ),
    );
  }

  Widget _headerCell(
    ColorScheme cs,
    String label,
    FileListSort field, {
    required int flex,
  }) {
    final active = widget.sortField == field;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => widget.onSortChange(field),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(
                  widget.sortDir == SortDirection.ascending
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(ColorScheme cs, FileListEntry e) {
    final isSelected = widget.selected.contains(e.entity.path);
    return Material(
      color: isSelected
          ? cs.primaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          _focusNode.requestFocus();
          widget.onTap(e);
        },
        onDoubleTap: () => widget.onDoubleTap(e),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      e.isDirectory
                          ? Icons.folder
                          : FileIcons.iconFor(e.name),
                      size: 16,
                      color: e.isDirectory ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.name,
                        style: TextStyle(fontSize: 13, color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  e.modified == null ? '' : _dateFormat.format(e.modified!),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  e.typeLabel,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  e.size == null ? '' : _formatSize(e.size!),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
