import 'package:flutter/material.dart';
import 'package:flutter_file_explorer/flutter_file_explorer.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_file_explorer example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _lastResult = 'No result yet.';

  static const _csvTypes = [
    FileTypeFilter(label: 'CSV File (*.csv)', extensions: ['csv']),
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
      title: 'Save Report',
      initialFileName: 'report.csv',
      fileTypes: _csvTypes,
    );
    setState(() => _lastResult = path == null ? 'Cancelled' : 'Save → $path');
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
        return null; // fall back to the default icon
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
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_file_explorer demo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _trySave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save…'),
                ),
                FilledButton.icon(
                  onPressed: _tryOpen,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Open…'),
                ),
                FilledButton.icon(
                  onPressed: _tryOpenMulti,
                  icon: const Icon(Icons.library_add_check_outlined),
                  label: const Text('Open Multiple…'),
                ),
                FilledButton.icon(
                  onPressed: _tryOpenDir,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Pick Folder…'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _tryCustomized,
                  icon: const Icon(Icons.tune),
                  label: const Text('Customized (tiles + i18n + icons)…'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Inside any dialog, try: the search box, the view-mode menu, the '
              'hidden-files and preview toggles, drag-and-drop from Explorer, '
              'and typing a path like %USERPROFILE% in the address bar. '
              'Folders you pick from are remembered under "Recent".',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(_lastResult),
            ),
          ],
        ),
      ),
    );
  }
}
