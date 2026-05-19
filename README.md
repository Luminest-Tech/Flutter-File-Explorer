# flutter_file_explorer

An **embedded** Windows-Explorer-style file picker for Flutter desktop apps.
Renders entirely as a Flutter widget — no native OS dialogs, no HWND parenting,
no surprise foreground windows when called from sub-windows.

Built for Flutter desktop on **Windows**, **macOS**, and **Linux**.

## Why

Native file pickers (`file_picker`, `flutter_file_dialog`, etc.) attach the
dialog to the platform's main window via `hwndOwner` / NSWindow. In apps that
use `desktop_multi_window`, calling them from a sub-window drags the *main*
window to the foreground. This package side-steps the issue by living entirely
inside your Flutter app's widget tree.

## Features

- Four modes: `save`, `open`, `openMulti`, `openDirectory`
- Clickable breadcrumb path bar (click any ancestor to jump there)
- Click the bar to switch to a typed path mode
- Quick Access sidebar (Desktop, Documents, Downloads, Pictures)
- "This PC" with mounted drives (Windows enumerates A:\ … Z:\)
- Sortable Details view: Name, Date modified, Type, Size
- Type-to-search (typing characters jumps to the next matching entry)
- Multi-select for `openMulti`
- New Folder
- Filter dropdown driven by `FileTypeFilter` groups
- Auto-appends extension in save mode
- Replace-file confirmation
- Pure Dart — no platform channels, no plugin code

## Install

```yaml
dependencies:
  flutter_file_explorer: ^0.1.0
```

## Usage

```dart
import 'package:flutter_file_explorer/flutter_file_explorer.dart';

// Save
final savedPath = await FileExplorer.save(
  context,
  title: 'Save Report',
  initialFileName: 'report.csv',
  fileTypes: const [
    FileTypeFilter(label: 'CSV File (*.csv)', extensions: ['csv']),
    FileTypeFilter(label: 'All Files (*.*)', extensions: ['*']),
  ],
);

// Open single file
final openPath = await FileExplorer.open(
  context,
  fileTypes: const [
    FileTypeFilter(label: 'Image', extensions: ['png', 'jpg', 'jpeg']),
  ],
);

// Open multiple files
final paths = await FileExplorer.openMulti(context);

// Pick a folder
final dir = await FileExplorer.openDirectory(context);
```

All methods return `null` if the user cancelled.

## API

| Method            | Returns               | Notes                                   |
|-------------------|-----------------------|-----------------------------------------|
| `save`            | `Future<String?>`     | Full path including filename            |
| `open`            | `Future<String?>`     | Single file                             |
| `openMulti`       | `Future<List<String>?>` | Multiple files                        |
| `openDirectory`   | `Future<String?>`     | Folder path                             |

Common parameters:

- `title` — dialog header text
- `initialDirectory` — starts here; falls back to user's Downloads, then home
- `fileTypes: List<FileTypeFilter>` — filter dropdown groups
- `quickLocations: List<QuickLocation>` — overrides the default sidebar entries

## Roadmap

- View modes (Large icons, Tiles) in addition to Details
- Hidden-files toggle
- Drag-drop into the picker
- Recent / pinned locations with persistence
- Pluggable icon callback for file-type icons
- Localization

## Example

A runnable demo lives in `example/`. From the repo root:

```bash
cd example
flutter run -d windows   # or macos / linux
```
