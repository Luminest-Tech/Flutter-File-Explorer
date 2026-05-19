import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Breadcrumb-style path bar. Click a segment to jump to that ancestor.
/// Click empty space (or the folder icon) to switch to a typed TextField mode.
class PathBar extends StatefulWidget {
  final String path;
  final ValueChanged<String> onPathSelected;

  const PathBar({
    super.key,
    required this.path,
    required this.onPathSelected,
  });

  @override
  State<PathBar> createState() => _PathBarState();
}

class _PathBarState extends State<PathBar> {
  bool _editing = false;
  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.path);
  }

  @override
  void didUpdateWidget(covariant PathBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.path != widget.path) {
      _ctrl.text = widget.path;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _enterEdit() {
    setState(() {
      _editing = true;
      _ctrl.text = widget.path;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctrl.text.length,
      );
    });
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == widget.path) {
      setState(() => _editing = false);
      return;
    }
    if (Directory(trimmed).existsSync()) {
      widget.onPathSelected(trimmed);
      setState(() => _editing = false);
    } else {
      _ctrl.text = widget.path;
      setState(() => _editing = false);
    }
  }

  List<_Segment> _segments(String path) {
    final out = <_Segment>[];
    if (path.isEmpty) return out;

    if (path.startsWith(r'\\')) {
      // UNC path: \\server\share\sub
      final rest = path.substring(2);
      final parts = rest.split(RegExp(r'[\\/]+'));
      String acc = r'\\';
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part.isEmpty) continue;
        if (i == 0) {
          acc = r'\\' + part;
          out.add(_Segment(label: r'\\' + part, path: acc));
        } else {
          acc = '$acc\\$part';
          out.add(_Segment(label: part, path: acc));
        }
      }
      return out;
    }

    if (Platform.isWindows) {
      final parts = path.split(RegExp(r'[\\/]+'));
      String acc = '';
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part.isEmpty) continue;
        if (i == 0 && part.endsWith(':')) {
          acc = '$part\\';
          out.add(_Segment(label: part, path: acc));
        } else {
          acc = p.join(acc, part);
          out.add(_Segment(label: part, path: acc));
        }
      }
      return out;
    }

    // POSIX
    final parts = path.split('/');
    out.add(const _Segment(label: '/', path: '/'));
    String acc = '/';
    for (final part in parts) {
      if (part.isEmpty) continue;
      acc = p.join(acc, part);
      out.add(_Segment(label: part, path: acc));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_editing) {
      return SizedBox(
        height: 40,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            prefixIcon: Icon(Icons.folder_outlined, size: 20),
          ),
          onSubmitted: _submit,
          onTapOutside: (_) {
            if (_editing) setState(() => _editing = false);
            _ctrl.text = widget.path;
          },
        ),
      );
    }

    final segments = _segments(widget.path);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enterEdit,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < segments.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => widget.onPathSelected(segments[i].path),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            segments[i].label,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment {
  final String label;
  final String path;
  const _Segment({required this.label, required this.path});
}
