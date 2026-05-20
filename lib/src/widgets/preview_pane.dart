import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../strings.dart';
import 'file_list.dart' show formatBytes, DateFormatLite;

enum _PreviewKind { image, text, other }

class _PreviewData {
  final _PreviewKind kind;
  final String name;
  final String typeLabel;
  final int? size;
  final DateTime? modified;
  final String? text;

  _PreviewData({
    required this.kind,
    required this.name,
    required this.typeLabel,
    required this.size,
    required this.modified,
    this.text,
  });
}

/// Right-hand pane that previews the currently selected entry: images render
/// directly, text-like files show their first chunk, everything else shows
/// metadata (type, size, modified).
class PreviewPane extends StatefulWidget {
  final String? path;
  final bool isDirectory;
  final FileExplorerStrings strings;

  const PreviewPane({
    super.key,
    required this.path,
    required this.isDirectory,
    required this.strings,
  });

  static const _imageExts = {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'};
  static const _textExts = {
    'txt', 'md', 'markdown', 'log', 'ini', 'cfg', 'conf', 'env', 'json',
    'xml', 'yaml', 'yml', 'toml', 'csv', 'tsv', 'dart', 'js', 'mjs', 'ts',
    'tsx', 'jsx', 'py', 'java', 'c', 'h', 'cpp', 'hpp', 'cc', 'cs', 'go',
    'rs', 'rb', 'php', 'swift', 'kt', 'kts', 'html', 'htm', 'css', 'scss',
    'less', 'sh', 'bat', 'cmd', 'ps1', 'sql', 'gradle', 'properties',
  };
  static const int _maxTextBytes = 64 * 1024;

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<PreviewPane> {
  Future<_PreviewData>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.isDirectory != widget.isDirectory) {
      _load();
    }
  }

  void _load() {
    final path = widget.path;
    if (path == null || widget.isDirectory) {
      _future = null;
      return;
    }
    _future = _loadData(path, widget.strings);
  }

  static Future<_PreviewData> _loadData(
    String path,
    FileExplorerStrings strings,
  ) async {
    final name = p.basename(path);
    final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
    final file = File(path);
    int? size;
    DateTime? modified;
    try {
      final stat = await file.stat();
      size = stat.size;
      modified = stat.modified;
    } catch (_) {}

    final typeLabel = ext.isEmpty
        ? strings.genericFileType
        : strings.extensionFileType(ext.toUpperCase());

    if (PreviewPane._imageExts.contains(ext)) {
      return _PreviewData(
        kind: _PreviewKind.image,
        name: name,
        typeLabel: typeLabel,
        size: size,
        modified: modified,
      );
    }

    if (PreviewPane._textExts.contains(ext)) {
      String? text;
      try {
        final length = await file.length();
        final end =
            length < PreviewPane._maxTextBytes ? length : PreviewPane._maxTextBytes;
        final chunks = await file.openRead(0, end).toList();
        final bytes = chunks.expand((c) => c).toList();
        text = utf8.decode(bytes, allowMalformed: true);
        if (length > PreviewPane._maxTextBytes) text = '$text\n…';
      } catch (_) {
        text = null;
      }
      return _PreviewData(
        kind: _PreviewKind.text,
        name: name,
        typeLabel: typeLabel,
        size: size,
        modified: modified,
        text: text,
      );
    }

    return _PreviewData(
      kind: _PreviewKind.other,
      name: name,
      typeLabel: typeLabel,
      size: size,
      modified: modified,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(
          left: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: _future == null
          ? _centered(cs, widget.strings.previewSelectPrompt)
          : FutureBuilder<_PreviewData>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return _buildData(cs, snap.data!);
              },
            ),
    );
  }

  Widget _buildData(ColorScheme cs, _PreviewData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildPreviewBody(cs, data)),
        _buildMeta(cs, data),
      ],
    );
  }

  Widget _buildPreviewBody(ColorScheme cs, _PreviewData data) {
    switch (data.kind) {
      case _PreviewKind.image:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Image.file(
            File(widget.path!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                _centered(cs, widget.strings.previewUnavailable),
          ),
        );
      case _PreviewKind.text:
        if (data.text == null || data.text!.isEmpty) {
          return _centered(cs, widget.strings.previewUnavailable);
        }
        return Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: SelectableText(
              data.text!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        );
      case _PreviewKind.other:
        return Center(
          child: Icon(
            Icons.insert_drive_file_outlined,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        );
    }
  }

  Widget _buildMeta(ColorScheme cs, _PreviewData data) {
    final lines = <String>[
      data.typeLabel,
      if (data.size != null) formatBytes(data.size!),
      if (data.modified != null) DateFormatLite().format(data.modified!),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            lines.join('  ·  '),
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _centered(ColorScheme cs, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
