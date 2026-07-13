import 'package:expense_manager/models/development_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a valid development update manifest', () {
    final update = DevelopmentUpdate.fromJson({
      'channel': 'development',
      'versionName': '0.0.1-dev.27',
      'buildNumber': 27,
      'apkUrl':
          'https://github.com/NaveenBadal/expense_manager/releases/download/dev-v0.0.1-dev.27/fund-flow-development.apk',
      'sha256': List.filled(64, 'a').join(),
      'releaseNotes': 'Navigation improvements',
      'publishedAt': '2026-07-13T12:00:00Z',
      'mandatory': false,
    });

    expect(update.versionName, '0.0.1-dev.27');
    expect(update.isNewerThan(26), isTrue);
    expect(update.isNewerThan(27), isFalse);
  });

  test('rejects incomplete or non-development manifests', () {
    expect(
      () => DevelopmentUpdate.fromJson({
        'channel': 'production',
        'versionName': '1.0.0',
        'buildNumber': 1,
        'apkUrl': 'https://example.com/app.apk',
        'sha256': List.filled(64, 'a').join(),
      }),
      throwsFormatException,
    );
    expect(
      () => DevelopmentUpdate.fromJson({
        'channel': 'development',
        'versionName': '0.0.1-dev.2',
        'buildNumber': 2,
        'apkUrl': 'https://example.com/app.apk',
        'sha256': 'too-short',
      }),
      throwsFormatException,
    );
  });
}
