import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_cloud_storage/models/update_info.dart';
import 'package:telegram_cloud_storage/utils/app_info.dart';
import 'package:telegram_cloud_storage/widgets/update/release_notes_view.dart';

void main() {
  group('AppInfo', () {
    test('reports nothing when the build has no repository', () {
      // A plain test run has no --dart-define values, like a local debug build.
      expect(AppInfo.hasRepository, isFalse);
      expect(AppInfo.owner, isNull);
      expect(AppInfo.repositoryUri, isNull);
      expect(AppInfo.shortCommit, isEmpty);
    });
  });

  group('AppVersion', () {
    test('reads versions out of release tags', () {
      expect(AppVersion.tryParse('v1.3.0').toString(), '1.3.0');
      expect(AppVersion.tryParse('release-2.4').toString(), '2.4.0');
      expect(AppVersion.tryParse('1.2.3+45').toString(), '1.2.3');
      expect(AppVersion.tryParse('nightly'), isNull);
    });

    test('compares number by number, not as text', () {
      expect(AppVersion.tryParse('1.10.0')! > AppVersion.tryParse('1.9.0')!, isTrue);
      expect(AppVersion.tryParse('2.0.0')! > AppVersion.tryParse('1.99.99')!, isTrue);
      expect(AppVersion.tryParse('1.3.0')! > AppVersion.tryParse('1.3.0')!, isFalse);
      expect(AppVersion.tryParse('1.3.0'), AppVersion.tryParse('v1.3.0'));
    });
  });

  group('parseReleaseNotes', () {
    test('splits headings, bullets and paragraphs', () {
      final blocks = parseReleaseNotes(
        "## What's new\n\n- **Fast** updates\n* Fixes\n1. Third\n\nThanks!\n",
      );
      expect(blocks.map((b) => b.type).toList(), [
        NoteBlockType.heading,
        NoteBlockType.bullet,
        NoteBlockType.bullet,
        NoteBlockType.bullet,
        NoteBlockType.paragraph,
      ]);
      expect(blocks.first.text, "What's new");
      expect(blocks.first.level, 2);
    });

    test('ignores comments, rules and blank lines', () {
      final blocks = parseReleaseNotes('<!-- hidden -->\n---\n\n\nOnly this\r\n');
      expect(blocks.length, 1);
      expect(blocks.single.text, 'Only this');
    });

    test('returns nothing for empty notes', () {
      expect(parseReleaseNotes('   \n'), isEmpty);
    });
  });
}
