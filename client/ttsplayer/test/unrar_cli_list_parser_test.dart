import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/spike/unrar_cli_list_parser.dart';

void main() {
  test('parses indented UnRAR lt technical blocks', () {
    const sample = '''
UNRAR 7.23 x64 freeware

Archive: sample.cbr
Details: RAR 5

        Name: page_001.png
        Type: File
        Size: 70
 Packed size: 70

        Name: nested/page_extra.png
        Type: File
        Size: 78
 Packed size: 78

        Name: notes.txt
        Type: File
        Size: 23
 Packed size: 23
''';
    final rows = parseUnrarTechnicalList(sample);
    expect(rows.length, 3);
    expect(rows[0].name, 'page_001.png');
    expect(rows[0].sizeBytes, 70);
    expect(rows[1].name, 'nested/page_extra.png');
    expect(rows[2].name, 'notes.txt');
  });
}
