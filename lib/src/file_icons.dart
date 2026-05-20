import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'strings.dart';

/// Maps filenames to Material icons based on their extension.
class FileIcons {
  FileIcons._();

  static IconData iconFor(String fileName) {
    final ext = p.extension(fileName).toLowerCase().replaceFirst('.', '');
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
      case 'rtf':
      case 'odt':
        return Icons.article_outlined;
      case 'xls':
      case 'xlsx':
      case 'xlsm':
      case 'ods':
      case 'csv':
      case 'tsv':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
      case 'odp':
        return Icons.slideshow_outlined;
      case 'txt':
      case 'md':
      case 'log':
      case 'ini':
      case 'cfg':
      case 'conf':
      case 'env':
        return Icons.description_outlined;
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
      case 'toml':
        return Icons.data_object_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'tiff':
      case 'tif':
      case 'svg':
      case 'ico':
        return Icons.image_outlined;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'wmv':
      case 'flv':
      case 'webm':
      case 'm4v':
        return Icons.movie_outlined;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'flac':
      case 'aac':
      case 'm4a':
        return Icons.audiotrack_outlined;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
      case 'xz':
        return Icons.folder_zip_outlined;
      case 'exe':
      case 'msi':
      case 'bat':
      case 'cmd':
      case 'sh':
      case 'ps1':
        return Icons.terminal;
      case 'dart':
      case 'js':
      case 'ts':
      case 'tsx':
      case 'jsx':
      case 'py':
      case 'java':
      case 'c':
      case 'h':
      case 'cpp':
      case 'cs':
      case 'go':
      case 'rs':
      case 'rb':
      case 'php':
      case 'swift':
      case 'kt':
        return Icons.code;
      case 'html':
      case 'htm':
      case 'css':
      case 'scss':
      case 'less':
        return Icons.html;
      case 'iso':
      case 'img':
      case 'dmg':
        return Icons.album_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  static String typeLabel(
    String fileName,
    FileExplorerStrings strings, {
    bool isDirectory = false,
  }) {
    if (isDirectory) return strings.fileFolderType;
    final ext = p.extension(fileName).toUpperCase().replaceFirst('.', '');
    return ext.isEmpty ? strings.genericFileType : strings.extensionFileType(ext);
  }
}
