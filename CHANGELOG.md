## 0.2.2

- Link the GitHub repository and issue tracker in the pubspec.

## 0.2.1

Documentation only. No code changes from 0.2.0.

- Rewrote the README as a general-purpose desktop file picker, with full usage
  and a complete parameter reference.
- Added dark and light screenshots, shown in the README and the pub.dev gallery.

## 0.2.0

Feature release.

**New**
- Type-to-filter **recursive search** of the current folder (bounded and
  cancellable), with results showing each match's relative location.
- **View modes**: Details, Large icons, and Tiles, switchable from the toolbar
  or via the `initialViewMode` parameter.
- **Preview pane** for the selected entry — renders images, the first 64 KB of
  text files, or metadata otherwise. Toggle from the toolbar.
- **Hidden-files toggle**. On Windows, files flagged Hidden/System are detected
  via the Win32 `GetFileAttributesW` API (not just dotfiles).
- **Drag-and-drop** from the OS into the dialog: drop files to select them
  (open modes) or pre-fill the name + folder (save mode); drop a folder to
  navigate into it.
- **Recent locations** persisted via `shared_preferences` and surfaced in a
  collapsible sidebar section.
- **Status bar** showing item count and selected count/size.
- **Keyboard shortcuts**: `Esc` cancels (or clears an active search) and
  `Backspace` goes up a level.
- Address-bar **environment-variable expansion** (`%USERPROFILE%`, `$HOME`,
  `~`) and **directory autocomplete** while typing a path.
- `iconBuilder` callback to supply custom per-entry icons.
- **Localization**: every user-facing string is overridable via
  `FileExplorerStrings`.
- **macOS/Linux drive enumeration** (`/Volumes`, `/media/$USER`,
  `/run/media/$USER`, `/mnt`).

**Changed**
- Dropped the `intl` dependency in favor of a built-in date formatter.
- Added `desktop_drop`, `shared_preferences`, and `ffi` dependencies.

## 0.1.0

Initial release.

- `FileExplorer.save`, `.open`, `.openMulti`, `.openDirectory`
- Clickable breadcrumb path bar with typed-path fallback
- Quick Access sidebar (Desktop, Documents, Downloads, Pictures)
- This PC with lazy-loaded drive list
- Sortable details view (Name, Date modified, Type, Size)
- Type-to-search
- New folder
- File-type filter dropdown
- Replace-file confirmation in save mode
- Auto-appends extension based on active filter
