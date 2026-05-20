import 'dart:async';
import 'dart:io';

import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../file_icons.dart';
import '../models.dart';
import '../strings.dart';
import '../win_attributes.dart';

enum FileListSort { name, modified, type, size }

enum SortDirection { ascending, descending }

/// Formats a byte count into a short human-readable string (B/KB/MB/GB).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// One row of the file list, with cached stat info.
class FileListEntry {
  final FileSystemEntity entity;
  final bool isDirectory;
  final String name;
  final DateTime? modified;
  final int? size;
  final String typeLabel;
  final bool isHidden;

  /// For search results: folder containing the match, relative to the search
  /// root. `null` for ordinary directory listings.
  final String? location;

  FileListEntry({
    required this.entity,
    required this.isDirectory,
    required this.name,
    required this.modified,
    required this.size,
    required this.typeLabel,
    required this.isHidden,
    this.location,
  });

  static Future<FileListEntry> fromEntity(
    FileSystemEntity e,
    FileExplorerStrings strings, {
    String? location,
  }) async {
    final isDir = e is Directory;
    DateTime? modified;
    int? size;
    try {
      final stat = await e.stat();
      modified = stat.modified;
      if (!isDir) size = stat.size;
    } catch (_) {}
    final name = p.basename(e.path);
    var hidden = name.startsWith('.');
    if (!hidden && Platform.isWindows) {
      hidden = WinAttributes.isHidden(e.path);
    }
    return FileListEntry(
      entity: e,
      isDirectory: isDir,
      name: name,
      modified: modified,
      size: size,
      typeLabel: FileIcons.typeLabel(name, strings, isDirectory: isDir),
      isHidden: hidden,
      location: location,
    );
  }
}

/// Presentation widget for the directory contents. The host dialog supplies an
/// already-filtered-and-sorted [entries] list and picks the [viewMode]; this
/// widget renders it and handles selection, double-tap, and type-to-search.
class FileList extends StatefulWidget {
  final List<FileListEntry> entries;
  final FileExplorerViewMode viewMode;
  final Set<String> selected;
  final ValueChanged<FileListEntry> onTap;
  final ValueChanged<FileListEntry> onDoubleTap;
  final FileListSort sortField;
  final SortDirection sortDir;
  final ValueChanged<FileListSort> onSortChange;
  final FileIconBuilder? iconBuilder;
  final FileExplorerStrings strings;
  final bool autofocus;
  final bool searchMode;
  final String emptyMessage;

  const FileList({
    super.key,
    required this.entries,
    required this.viewMode,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.sortField,
    required this.sortDir,
    required this.onSortChange,
    required this.strings,
    this.iconBuilder,
    this.autofocus = false,
    this.searchMode = false,
    this.emptyMessage = '',
  });

  @override
  State<FileList> createState() => _FileListState();
}

class _FileListState extends State<FileList> {
  static const double _rowHeight = 28;
  static const double _searchRowHeight = 46;
  final FocusNode _focusNode = FocusNode(debugLabel: 'FileList');
  final ScrollController _scroll = ScrollController();
  String _typeahead = '';
  Timer? _typeaheadTimer;
  final _dateFormat = DateFormatLite();

  @override
  void dispose() {
    _typeaheadTimer?.cancel();
    _focusNode.dispose();
    _scroll.dispose();
    super.dispose();
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
    final idx = widget.entries.indexWhere(
      (e) => e.name.toLowerCase().startsWith(_typeahead),
    );
    if (idx >= 0) {
      widget.onTap(widget.entries[idx]);
      if (widget.viewMode == FileExplorerViewMode.details &&
          _scroll.hasClients) {
        _scroll.animateTo(
          (idx * _rowHeight).clamp(0.0, _scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showDetailsHeader =
        widget.viewMode == FileExplorerViewMode.details && !widget.searchMode;

    return Column(
      children: [
        if (showDetailsHeader) _buildHeader(cs),
        Expanded(
          child: widget.entries.isEmpty
              ? Center(
                  child: Text(
                    widget.emptyMessage,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : KeyboardListener(
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  onKeyEvent: _onKey,
                  child: _buildContent(cs),
                ),
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (widget.searchMode) return _buildSearchList(cs);
    switch (widget.viewMode) {
      case FileExplorerViewMode.details:
        return _buildDetailsList(cs);
      case FileExplorerViewMode.largeIcons:
        return _buildGrid(cs, tileExtent: 116, iconSize: 48, tile: false);
      case FileExplorerViewMode.tiles:
        return _buildGrid(cs, tileExtent: 240, iconSize: 32, tile: true);
    }
  }

  // ---- Details view ----------------------------------------------------------

  Widget _buildDetailsList(ColorScheme cs) {
    return ListView.builder(
      controller: _scroll,
      itemCount: widget.entries.length,
      itemExtent: _rowHeight,
      itemBuilder: (context, i) => _buildDetailsRow(cs, widget.entries[i]),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    final s = widget.strings;
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
          _headerCell(cs, s.nameColumn, FileListSort.name, flex: 5),
          _headerCell(cs, s.dateModifiedColumn, FileListSort.modified, flex: 3),
          _headerCell(cs, s.typeColumn, FileListSort.type, flex: 2),
          _headerCell(cs, s.sizeColumn, FileListSort.size, flex: 1),
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

  Widget _buildDetailsRow(ColorScheme cs, FileListEntry e) {
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
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: _icon(context, e, 16, cs),
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
                  e.size == null ? '' : formatBytes(e.size!),
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

  // ---- Grid views (large icons / tiles) -------------------------------------

  Widget _buildGrid(
    ColorScheme cs, {
    required double tileExtent,
    required double iconSize,
    required bool tile,
  }) {
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: tileExtent,
        mainAxisExtent: tile ? 64 : 116,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.entries.length,
      itemBuilder: (context, i) => tile
          ? _buildTile(cs, widget.entries[i], iconSize)
          : _buildIconCell(cs, widget.entries[i], iconSize),
    );
  }

  Widget _buildIconCell(ColorScheme cs, FileListEntry e, double iconSize) {
    final isSelected = widget.selected.contains(e.entity.path);
    return _selectable(
      cs,
      isSelected,
      e,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: _icon(context, e, iconSize, cs),
            ),
            const SizedBox(height: 6),
            Text(
              e.name,
              style: TextStyle(fontSize: 12, color: cs.onSurface),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(ColorScheme cs, FileListEntry e, double iconSize) {
    final isSelected = widget.selected.contains(e.entity.path);
    final subtitle = e.isDirectory
        ? e.typeLabel
        : (e.size == null ? e.typeLabel : '${e.typeLabel} · ${formatBytes(e.size!)}');
    return _selectable(
      cs,
      isSelected,
      e,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: _icon(context, e, iconSize, cs),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Search results view ---------------------------------------------------

  Widget _buildSearchList(ColorScheme cs) {
    return ListView.builder(
      controller: _scroll,
      itemCount: widget.entries.length,
      itemExtent: _searchRowHeight,
      itemBuilder: (context, i) => _buildSearchRow(cs, widget.entries[i]),
    );
  }

  Widget _buildSearchRow(ColorScheme cs, FileListEntry e) {
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              SizedBox(width: 20, height: 20, child: _icon(context, e, 20, cs)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (e.location != null && e.location!.isNotEmpty)
                      Text(
                        e.location!,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Shared helpers --------------------------------------------------------

  Widget _selectable(
    ColorScheme cs,
    bool isSelected,
    FileListEntry e, {
    required Widget child,
  }) {
    return Material(
      color: isSelected
          ? cs.primaryContainer.withValues(alpha: 0.45)
          : cs.surfaceContainerLow.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _focusNode.requestFocus();
          widget.onTap(e);
        },
        onDoubleTap: () => widget.onDoubleTap(e),
        child: child,
      ),
    );
  }

  Widget _icon(BuildContext context, FileListEntry e, double size, ColorScheme cs) {
    final builder = widget.iconBuilder;
    if (builder != null) {
      final custom = builder(
        context,
        FileExplorerEntry(
          path: e.entity.path,
          name: e.name,
          isDirectory: e.isDirectory,
        ),
      );
      if (custom != null) {
        return Center(child: custom);
      }
    }
    if (e.isDirectory) {
      return Icon(Icons.folder, size: size, color: cs.primary);
    }
    return FileIcon(e.name, size: size);
  }
}

/// Minimal date formatter (`M/d/yyyy h:mm AM/PM`) so the file list does not pull
/// `intl` locale data just to render a timestamp.
class DateFormatLite {
  String format(DateTime dt) {
    final h24 = dt.hour;
    final ampm = h24 < 12 ? 'AM' : 'PM';
    var h = h24 % 12;
    if (h == 0) h = 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day}/${dt.year} $h:$m $ampm';
  }
}
