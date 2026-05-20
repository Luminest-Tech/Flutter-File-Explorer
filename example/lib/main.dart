import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_file_explorer/flutter_file_explorer.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  /// Selectable accent colors for the demo's theme.
  static const List<(String, Color)> swatches = [
    ('Violet', Color(0xFF7C4DFF)),
    ('Indigo', Color(0xFF3F51B5)),
    ('Blue', Color(0xFF2196F3)),
    ('Teal', Color(0xFF009688)),
    ('Green', Color(0xFF43A047)),
    ('Amber', Color(0xFFFFB300)),
    ('Orange', Color(0xFFFB8C00)),
    ('Rose', Color(0xFFEC407A)),
  ];

  Color _seed = swatches.first.$2;
  ThemeMode _mode = ThemeMode.light;

  ThemeData _theme(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'flutter_file_explorer demo',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _mode,
      home: HomePage(
        swatches: swatches,
        seed: _seed,
        isDark: _mode == ThemeMode.dark,
        onSeedChanged: (c) => setState(() => _seed = c),
        onDarkChanged: (d) =>
            setState(() => _mode = d ? ThemeMode.dark : ThemeMode.light),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<(String, Color)> swatches;
  final Color seed;
  final bool isDark;
  final ValueChanged<Color> onSeedChanged;
  final ValueChanged<bool> onDarkChanged;

  const HomePage({
    super.key,
    required this.swatches,
    required this.seed,
    required this.isDark,
    required this.onSeedChanged,
    required this.onDarkChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _lastResult = 'No result yet — pick something above.';

  static const _txtTypes = [
    FileTypeFilter(label: 'Text File (*.txt)', extensions: ['txt']),
    FileTypeFilter(label: 'All Files (*.*)', extensions: ['*']),
  ];

  static const _imageTypes = [
    FileTypeFilter(
      label: 'Image (*.png; *.jpg; *.jpeg)',
      extensions: ['png', 'jpg', 'jpeg'],
    ),
    FileTypeFilter(label: 'All Files (*.*)', extensions: ['*']),
  ];

  Future<void> _trySave() async {
    final path = await FileExplorer.save(
      context,
      title: 'Save Text File',
      initialFileName: 'example.txt',
      fileTypes: _txtTypes,
    );
    if (path == null) {
      setState(() => _lastResult = 'Cancelled');
      return;
    }
    try {
      await File(path).writeAsString('never gonna give you up');
      setState(() =>
          _lastResult = 'Saved → $path\nWrote: "never gonna give you up"');
    } catch (e) {
      setState(() => _lastResult = 'Save failed → $e');
    }
  }

  Future<void> _tryOpen() async {
    final path = await FileExplorer.open(
      context,
      title: 'Open Image',
      fileTypes: _imageTypes,
    );
    setState(() => _lastResult = path == null ? 'Cancelled' : 'Open → $path');
  }

  Future<void> _tryOpenMulti() async {
    final paths = await FileExplorer.openMulti(
      context,
      title: 'Open Multiple',
      fileTypes: _imageTypes,
    );
    setState(() => _lastResult = paths == null
        ? 'Cancelled'
        : 'Open Multi (${paths.length}) → ${paths.join("\n")}');
  }

  Future<void> _tryOpenDir() async {
    final dir = await FileExplorer.openDirectory(
      context,
      title: 'Select Output Folder',
    );
    setState(() => _lastResult = dir == null ? 'Cancelled' : 'Dir → $dir');
  }

  /// Shows the v0.2.0 extras: tiles view by default, hidden files visible,
  /// a custom icon builder, and a localized (German) string set.
  Future<void> _tryCustomized() async {
    final path = await FileExplorer.open(
      context,
      title: 'Datei öffnen',
      initialViewMode: FileExplorerViewMode.tiles,
      showHiddenFiles: true,
      iconBuilder: (context, entry) {
        if (entry.isDirectory) {
          return const Icon(Icons.folder_special, color: Colors.amber);
        }
        if (entry.extension == 'dart') {
          return const Icon(Icons.flutter_dash, color: Colors.blue);
        }
        return null;
      },
      strings: const FileExplorerStrings(
        openButton: 'Öffnen',
        cancelButton: 'Abbrechen',
        searchHint: 'Ordner durchsuchen',
        quickAccess: 'Schnellzugriff',
        thisPc: 'Dieser PC',
        recent: 'Zuletzt verwendet',
        nameColumn: 'Name',
        dateModifiedColumn: 'Änderungsdatum',
        typeColumn: 'Typ',
        sizeColumn: 'Größe',
      ),
    );
    setState(() => _lastResult = path == null ? 'Cancelled' : 'Custom → $path');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gradient = dark
        ? [
            Color.alphaBlend(cs.primary.withValues(alpha: 0.30), cs.surface),
            Color.alphaBlend(cs.tertiary.withValues(alpha: 0.26), cs.surface),
          ]
        : [cs.primary, cs.tertiary];

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox.expand(child: _panel(cs)),
          ),
        ),
      ),
    );
  }

  Widget _panel(ColorScheme cs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(cs),
                      const SizedBox(height: 28),
                      _themeControls(cs),
                      const SizedBox(height: 28),
                      _buttons(cs),
                      const SizedBox(height: 22),
                      _helpCard(cs),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _resultCard(cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.folder_open_rounded,
              color: cs.onPrimaryContainer, size: 30),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'flutter_file_explorer',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'An embedded Explorer-style file picker for Flutter desktop.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _themeControls(ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Accent color',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      )),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (name, color) in widget.swatches)
                    _SwatchDot(
                      name: name,
                      color: color,
                      selected: widget.seed.toARGB32() == color.toARGB32(),
                      onTap: () => widget.onSeedChanged(color),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Appearance',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    )),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.light_mode_outlined, size: 18),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.dark_mode_outlined, size: 18),
                  label: Text('Dark'),
                ),
              ],
              selected: {widget.isDark},
              onSelectionChanged: (s) => widget.onDarkChanged(s.first),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buttons(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Open a picker',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = (constraints.maxWidth / 300).floor().clamp(1, 4);
            final cellWidth =
                (constraints.maxWidth - (cols - 1) * 14) / cols;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _ActionButton(
                  width: cellWidth,
                  icon: Icons.save_outlined,
                  label: 'Save',
                  description: 'Writes example.txt to disk',
                  onTap: _trySave,
                ),
                _ActionButton(
                  width: cellWidth,
                  icon: Icons.file_open_outlined,
                  label: 'Open',
                  description: 'Pick a single file',
                  onTap: _tryOpen,
                ),
                _ActionButton(
                  width: cellWidth,
                  icon: Icons.library_add_check_outlined,
                  label: 'Open multiple',
                  description: 'Select several files',
                  onTap: _tryOpenMulti,
                ),
                _ActionButton(
                  width: cellWidth,
                  icon: Icons.folder_open_outlined,
                  label: 'Pick folder',
                  description: 'Choose a directory',
                  onTap: _tryOpenDir,
                ),
                _ActionButton(
                  width: constraints.maxWidth,
                  icon: Icons.tune,
                  label: 'Customized',
                  description: 'Tiles view · custom icons · German · hidden files',
                  primary: true,
                  onTap: _tryCustomized,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _helpCard(ColorScheme cs) {
    const tips = [
      'Search the current folder — results show where each match lives',
      'Switch layouts: Details, Large icons, Tiles',
      'Toggle hidden files and the live preview pane',
      'Drag files in from File Explorer',
      'Type a path like %USERPROFILE% in the address bar',
      'Folders you pick are remembered under “Recent”',
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text('Things to try',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.check_circle_outline,
                        size: 17, color: cs.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tip,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultCard(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.terminal_rounded, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              _lastResult,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular accent-color swatch with a selection ring + check.
class _SwatchDot extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SwatchDot({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? cs.onSurface : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: selected ? Icon(Icons.check, size: 18, color: checkColor) : null,
        ),
      ),
    );
  }
}

/// A large, card-style picker button with icon, title, and description.
class _ActionButton extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = primary ? cs.onPrimary : cs.onSurface;
    final sub =
        primary ? cs.onPrimary.withValues(alpha: 0.85) : cs.onSurfaceVariant;
    final iconBg =
        primary ? cs.onPrimary.withValues(alpha: 0.18) : cs.primaryContainer;
    final iconFg = primary ? cs.onPrimary : cs.onPrimaryContainer;

    return SizedBox(
      width: width,
      child: Material(
        color: primary ? cs.primary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconFg, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(fontSize: 12.5, color: sub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: sub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
