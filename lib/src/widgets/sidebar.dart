import 'package:flutter/material.dart';

import '../models.dart';

/// Left navigation pane: Quick Access + This PC (lazy-loaded drives).
class Sidebar extends StatefulWidget {
  final List<QuickLocation> quickLocations;
  final Future<List<QuickLocation>> Function() drivesLoader;
  final String? currentPath;
  final ValueChanged<String> onLocationSelected;

  const Sidebar({
    super.key,
    required this.quickLocations,
    required this.drivesLoader,
    required this.currentPath,
    required this.onLocationSelected,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _expanded = true;
  List<QuickLocation>? _drives;
  bool _loadingDrives = false;

  @override
  void initState() {
    super.initState();
    _loadDrives();
  }

  Future<void> _loadDrives() async {
    if (_drives != null || _loadingDrives) return;
    setState(() => _loadingDrives = true);
    final loaded = await widget.drivesLoader();
    if (!mounted) return;
    setState(() {
      _drives = loaded;
      _loadingDrives = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionLabel(cs, 'Quick Access'),
          for (final loc in widget.quickLocations) _buildEntry(cs, loc, indent: false),
          const Divider(height: 16, indent: 12, endIndent: 12),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.computer_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'This PC',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            if (_loadingDrives)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              for (final d in (_drives ?? const <QuickLocation>[]))
                _buildEntry(cs, d, indent: true),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(ColorScheme cs, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildEntry(
    ColorScheme cs,
    QuickLocation loc, {
    required bool indent,
  }) {
    final selected = widget.currentPath != null &&
        _samePath(widget.currentPath!, loc.path);
    return Material(
      color: selected
          ? cs.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: () => widget.onLocationSelected(loc.path),
        child: Padding(
          padding: EdgeInsets.fromLTRB(indent ? 30 : 12, 8, 12, 8),
          child: Row(
            children: [
              Icon(
                loc.icon ?? Icons.folder_outlined,
                size: 18,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.label,
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _samePath(String a, String b) {
    String normalize(String s) =>
        s.toLowerCase().replaceAll('/', r'\').replaceAll(RegExp(r'\\+$'), '');
    return normalize(a) == normalize(b);
  }
}
