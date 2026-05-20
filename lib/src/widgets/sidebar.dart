import 'package:flutter/material.dart';

import '../models.dart';
import '../path_utils.dart';
import '../strings.dart';

/// Left navigation pane. Quick Access, Recent (when available), and This PC are
/// each collapsible. Drives are lazy-loaded when This PC is expanded.
class Sidebar extends StatefulWidget {
  final List<QuickLocation> quickLocations;
  final List<QuickLocation> recentLocations;
  final Future<List<QuickLocation>> Function() drivesLoader;
  final String? currentPath;
  final ValueChanged<String> onLocationSelected;
  final FileExplorerStrings strings;

  const Sidebar({
    super.key,
    required this.quickLocations,
    required this.recentLocations,
    required this.drivesLoader,
    required this.currentPath,
    required this.onLocationSelected,
    required this.strings,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _quickExpanded = true;
  bool _recentExpanded = true;
  bool _thisPcExpanded = true;
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
    final s = widget.strings;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionHeader(
            cs,
            label: s.quickAccess,
            icon: Icons.star_outline,
            expanded: _quickExpanded,
            onTap: () => setState(() => _quickExpanded = !_quickExpanded),
          ),
          if (_quickExpanded)
            for (final loc in widget.quickLocations)
              _buildEntry(cs, loc, indent: true),
          if (widget.recentLocations.isNotEmpty) ...[
            const Divider(height: 16, indent: 12, endIndent: 12),
            _sectionHeader(
              cs,
              label: s.recent,
              icon: Icons.history,
              expanded: _recentExpanded,
              onTap: () => setState(() => _recentExpanded = !_recentExpanded),
            ),
            if (_recentExpanded)
              for (final loc in widget.recentLocations)
                _buildEntry(cs, loc, indent: true),
          ],
          const Divider(height: 16, indent: 12, endIndent: 12),
          _sectionHeader(
            cs,
            label: s.thisPc,
            icon: Icons.computer_outlined,
            expanded: _thisPcExpanded,
            onTap: () => setState(() => _thisPcExpanded = !_thisPcExpanded),
          ),
          if (_thisPcExpanded) ...[
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

  Widget _sectionHeader(
    ColorScheme cs, {
    required String label,
    required IconData icon,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_more : Icons.chevron_right,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
        samePath(widget.currentPath!, loc.path);
    return Material(
      color: selected
          ? cs.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: () => widget.onLocationSelected(loc.path),
        child: Padding(
          padding: EdgeInsets.fromLTRB(indent ? 30 : 12, 6, 12, 6),
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
}
