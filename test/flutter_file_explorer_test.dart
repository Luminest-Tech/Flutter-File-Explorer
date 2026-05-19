import 'package:flutter_file_explorer/flutter_file_explorer.dart';
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
}
