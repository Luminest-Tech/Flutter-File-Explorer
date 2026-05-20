import 'package:flutter/widgets.dart';

/// All user-facing strings used by the file explorer dialog.
///
/// The package ships English defaults. To localize, construct a
/// [FileExplorerStrings] with overrides and pass it to any `FileExplorer`
/// method via the `strings` parameter:
///
/// ```dart
/// await FileExplorer.open(
///   context,
///   strings: const FileExplorerStrings(openButton: 'Ouvrir', cancelButton: 'Annuler'),
/// );
/// ```
///
/// Every field has a sensible English default, so you only override the
/// strings you care about.
@immutable
class FileExplorerStrings {
  // Buttons.
  final String saveButton;
  final String openButton;
  final String selectFolderButton;
  final String cancelButton;
  final String createButton;
  final String replaceButton;

  // Toolbar tooltips.
  final String cancelTooltip;
  final String upTooltip;
  final String refreshTooltip;
  final String newFolderTooltip;
  final String showHiddenTooltip;
  final String hideHiddenTooltip;
  final String showPreviewTooltip;
  final String hidePreviewTooltip;
  final String viewModeTooltip;
  final String detailsViewLabel;
  final String largeIconsViewLabel;
  final String tilesViewLabel;

  // Footer.
  final String fileNameLabel;
  final String saveAsTypeLabel;
  final String filesOfTypeLabel;
  final String allFilesLabel;
  final String selectedLabel;

  // Body / states.
  final String emptyFolder;
  final String couldNotOpenFolder;
  final String searchHint;
  final String searching;
  final String noSearchResults;

  // Sidebar sections.
  final String quickAccess;
  final String thisPc;
  final String recent;

  // Column headers.
  final String nameColumn;
  final String dateModifiedColumn;
  final String typeColumn;
  final String sizeColumn;

  // New-folder dialog.
  final String newFolderTitle;
  final String newFolderFieldLabel;
  final String newFolderDefaultName;

  // Replace-file dialog.
  final String replaceTitle;

  // Preview pane.
  final String previewSelectPrompt;
  final String previewUnavailable;
  final String previewBinaryFile;

  // Type labels.
  final String fileFolderType;
  final String genericFileType;

  // Drag-and-drop.
  final String dropHint;

  // Parameterized strings.
  final String Function(String name) replaceMessage;
  final String Function(String ext) extensionFileType;
  final String Function(int count) itemCount;
  final String Function(int count, String size) selectionSummary;

  const FileExplorerStrings({
    this.saveButton = 'Save',
    this.openButton = 'Open',
    this.selectFolderButton = 'Select Folder',
    this.cancelButton = 'Cancel',
    this.createButton = 'Create',
    this.replaceButton = 'Replace',
    this.cancelTooltip = 'Cancel',
    this.upTooltip = 'Up one level',
    this.refreshTooltip = 'Refresh',
    this.newFolderTooltip = 'New folder',
    this.showHiddenTooltip = 'Show hidden files',
    this.hideHiddenTooltip = 'Hide hidden files',
    this.showPreviewTooltip = 'Show preview',
    this.hidePreviewTooltip = 'Hide preview',
    this.viewModeTooltip = 'Change view',
    this.detailsViewLabel = 'Details',
    this.largeIconsViewLabel = 'Large icons',
    this.tilesViewLabel = 'Tiles',
    this.fileNameLabel = 'File name:',
    this.saveAsTypeLabel = 'Save as type:',
    this.filesOfTypeLabel = 'Files of type:',
    this.allFilesLabel = 'All files (*.*)',
    this.selectedLabel = 'Selected:',
    this.emptyFolder = 'This folder is empty',
    this.couldNotOpenFolder = 'Could not open folder',
    this.searchHint = 'Search current folder',
    this.searching = 'Searching…',
    this.noSearchResults = 'No matching items',
    this.quickAccess = 'Quick Access',
    this.thisPc = 'This PC',
    this.recent = 'Recent',
    this.nameColumn = 'Name',
    this.dateModifiedColumn = 'Date modified',
    this.typeColumn = 'Type',
    this.sizeColumn = 'Size',
    this.newFolderTitle = 'New Folder',
    this.newFolderFieldLabel = 'Folder name',
    this.newFolderDefaultName = 'New folder',
    this.replaceTitle = 'Replace File?',
    this.previewSelectPrompt = 'Select a file to preview',
    this.previewUnavailable = 'No preview available',
    this.previewBinaryFile = 'Binary file — no text preview',
    this.fileFolderType = 'File folder',
    this.genericFileType = 'File',
    this.dropHint = 'Drop files here',
    this.replaceMessage = _defaultReplaceMessage,
    this.extensionFileType = _defaultExtensionFileType,
    this.itemCount = _defaultItemCount,
    this.selectionSummary = _defaultSelectionSummary,
  });

  static String _defaultReplaceMessage(String name) =>
      '"$name" already exists in this location. Replace it?';

  static String _defaultExtensionFileType(String ext) => '$ext File';

  static String _defaultItemCount(int count) =>
      '$count ${count == 1 ? 'item' : 'items'}';

  static String _defaultSelectionSummary(int count, String size) =>
      size.isEmpty
          ? '$count selected'
          : '$count selected · $size';
}
