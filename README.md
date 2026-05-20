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
- **Three view modes**: Details, Large icons, and Tiles
- **Recursive search** of the current folder, with match locations
- **Preview pane** for images, text files, and metadata
- **Drag-and-drop** files/folders from the OS into the dialog
- **Recent locations** persisted between sessions
- **Hidden-files toggle** (Windows Hidden/System attributes detected, not just dotfiles)
- Clickable breadcrumb path bar; click to type a path with
  **`%VAR%` / `$VAR` / `~` expansion** and **directory autocomplete**
- Quick Access sidebar (system-pulled on Windows) + "This PC" with mounted
  drives (Windows `A:\ … Z:\`; macOS `/Volumes`; Linux `/media`, `/mnt`)
- Sortable Details columns: Name, Date modified, Type, Size
- Status bar with item and selection counts/sizes
- `Esc` to cancel, `Backspace` to go up a level, type-to-jump in the list
- Multi-select for `openMulti`, New Folder, replace-file confirmation
- Filter dropdown driven by `FileTypeFilter`; auto-appends extension on save
- **Custom per-entry icons** via `iconBuilder`
- **Fully localizable** via `FileExplorerStrings`
- No native picker — renders entirely inside your Flutter widget tree

## Install

```yaml
dependencies:
  flutter_file_explorer: ^0.2.0
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
- `dismissable` — allow click-outside to cancel (default `false`)
- `showHiddenFiles` — initial state of the hidden-files toggle (default `false`)
- `initialViewMode` — `FileExplorerViewMode.details` (default), `largeIcons`, or `tiles`
- `iconBuilder` — custom per-entry icons (see below)
- `strings` — localized labels (see below)

## Custom icons

Supply an `iconBuilder` to override icons per entry. Return `null` to keep the
default icon for that entry.

```dart
await FileExplorer.open(
  context,
  iconBuilder: (context, entry) {
    if (entry.isDirectory) {
      return const Icon(Icons.folder_special, color: Colors.amber);
    }
    if (entry.extension == 'dart') return const Icon(Icons.flutter_dash);
    return null; // default icon
  },
);
```

## Localization

Every user-facing label has an English default and can be overridden by passing
a `FileExplorerStrings`:

```dart
await FileExplorer.open(
  context,
  strings: const FileExplorerStrings(
    openButton: 'Öffnen',
    cancelButton: 'Abbrechen',
    searchHint: 'Ordner durchsuchen',
    quickAccess: 'Schnellzugriff',
    thisPc: 'Dieser PC',
  ),
);
```

## Roadmap

- Thumbnail previews for images in grid views
- Column resizing in Details view
- Per-folder remembered view mode and sort
- Cut/copy/paste and rename context actions

## Example

A runnable demo lives in `example/`. From the repo root:

```bash
cd example
flutter run -d windows   # or macos / linux
```
