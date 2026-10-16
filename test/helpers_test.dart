import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_cloud_storage/models/file_item.dart';
import 'package:telegram_cloud_storage/utils/helpers.dart';

void main() {
  group('normalizeChannelId', () {
    test('leaves ids and usernames alone', () {
      expect(normalizeChannelId('@my_channel'), '@my_channel');
      expect(normalizeChannelId('-1001234567890'), '-1001234567890');
      expect(normalizeChannelId('  @my_channel  '), '@my_channel');
    });

    test('adds the missing prefix', () {
      expect(normalizeChannelId('mychannel'), '@mychannel');
      expect(normalizeChannelId('1234567890'), '-1001234567890');
    });

    test('understands t.me links', () {
      expect(normalizeChannelId('https://t.me/mychannel'), '@mychannel');
      expect(normalizeChannelId('t.me/mychannel'), '@mychannel');
      expect(normalizeChannelId('https://t.me/c/1234567890/5'), '-1001234567890');
    });

    test('does not guess at invite links', () {
      expect(normalizeChannelId('https://t.me/+AbCdEf'), 'https://t.me/+AbCdEf');
    });
  });

  group('telegramMessageUri', () {
    test('builds links for private and public channels', () {
      expect(
        telegramMessageUri('-1001234567890', 7).toString(),
        'https://t.me/c/1234567890/7',
      );
      expect(telegramMessageUri('@chan', 3).toString(), 'https://t.me/chan/3');
    });

    test('returns null when there is nothing to link to', () {
      expect(telegramMessageUri('-12345', 1), isNull);
      expect(telegramMessageUri(null, 1), isNull);
    });
  });

  group('sanitizeFileName', () {
    test('replaces characters that are unsafe on disk', () {
      expect(sanitizeFileName('a/b:c.txt'), 'a_b_c.txt');
    });

    test('never returns an empty or hidden name', () {
      expect(sanitizeFileName(''), 'file');
      expect(sanitizeFileName('..hidden'), 'hidden');
    });

    test('shortens long names but keeps the extension', () {
      final result = sanitizeFileName('${'x' * 200}.flac');
      expect(result.length, 150);
      expect(result.endsWith('.flac'), isTrue);
    });
  });

  group('FileItem', () {
    test('keeps the source path through a map round trip', () {
      final item = FileItem(
        fileName: 'a.flac',
        telegramFileId: 'file-id',
        telegramMessageId: 1,
        category: FileCategory.audio,
        fileSizeBytes: 10,
        sourcePath: '/music/a.flac',
        uploadedAt: DateTime(2026, 1, 1),
      );
      final back = FileItem.fromMap(item.toMap());
      expect(back.sourcePath, '/music/a.flac');
      expect(back.category, FileCategory.audio);
    });
  });
}
