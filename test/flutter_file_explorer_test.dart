import 'dart:io';

import 'package:flutter_file_explorer/flutter_file_explorer.dart';
import 'package:flutter_file_explorer/src/path_utils.dart';
import 'package:flutter_file_explorer/src/widgets/file_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileTypeFilter', () {
    test('matches files by extension', () {
      const f = FileTypeFilter(label: 'CSV', extensions: ['csv', 'tsv']);
      expect(f.matches('foo.csv'), isTrue);
      expect(f.matches('foo.TSV'), isTrue);
      expect(f.matches('foo.txt'), isFalse);
      expect(f.matches('foo'), isFalse);
    });

    test('wildcard matches everything', () {
      const f = FileTypeFilter(label: 'All', extensions: ['*']);
      expect(f.matches('whatever'), isTrue);
      expect(f.matches('foo.bar'), isTrue);
      expect(f.matchesAll, isTrue);
    });
  });

  group('FileExplorerEntry.extension', () {
    FileExplorerEntry file(String name) =>
        FileExplorerEntry(path: '/x/$name', name: name, isDirectory: false);

    test('returns the lowercased extension', () {
      expect(file('photo.PNG').extension, 'png');
      expect(file('archive.tar.gz').extension, 'gz');
    });

    test('is empty for folders, dotfiles, and extension-less files', () {
      expect(
        const FileExplorerEntry(path: '/x', name: 'x', isDirectory: true)
            .extension,
        '',
      );
      expect(file('README').extension, '');
      expect(file('.gitignore').extension, '');
    });
  });

  group('formatBytes', () {
    test('scales units', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(1024 * 1024), '1.0 MB');
      expect(formatBytes(5 * 1024 * 1024 * 1024), '5.00 GB');
    });
  });

  group('DateFormatLite', () {
    test('formats 12-hour time with AM/PM', () {
      final f = DateFormatLite();
      expect(f.format(DateTime(2026, 5, 19, 14, 5)), '5/19/2026 2:05 PM');
      expect(f.format(DateTime(2026, 1, 1, 0, 0)), '1/1/2026 12:00 AM');
      expect(f.format(DateTime(2026, 12, 9, 12, 30)), '12/9/2026 12:30 PM');
    });
  });

  group('samePath', () {
    test('ignores trailing separators', () {
      if (Platform.isWindows) {
        expect(samePath(r'C:\Users', r'C:\Users\'), isTrue);
      } else {
        expect(samePath('/a/b', '/a/b/'), isTrue);
      }
    });

    test('is case-insensitive only on Windows', () {
      if (Platform.isWindows) {
        expect(samePath(r'C:\Users', r'c:\users'), isTrue);
      } else {
        expect(samePath('/A/B', '/a/b'), isFalse);
      }
    });
  });

  group('expandPath', () {
    test('leaves unknown variables untouched', () {
      expect(expandPath(r'%NOPE_XYZ_123%'), r'%NOPE_XYZ_123%');
      expect(expandPath(r'$NOPE_XYZ_123'), r'$NOPE_XYZ_123');
    });

    test('expands a leading ~ to the home directory', () {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        expect(expandPath('~'), home);
      }
    });
  });

  group('FileExplorerStrings', () {
    test('ships English defaults', () {
      const s = FileExplorerStrings();
      expect(s.openButton, 'Open');
      expect(s.itemCount(1), '1 item');
      expect(s.itemCount(3), '3 items');
      expect(s.selectionSummary(2, ''), '2 selected');
      expect(s.selectionSummary(2, '4 KB'), '2 selected · 4 KB');
      expect(s.replaceMessage('a.txt'), contains('a.txt'));
    });

    test('allows overrides for localization', () {
      const s = FileExplorerStrings(openButton: 'Ouvrir');
      expect(s.openButton, 'Ouvrir');
      expect(s.cancelButton, 'Cancel'); // untouched default
    });
  });
}
