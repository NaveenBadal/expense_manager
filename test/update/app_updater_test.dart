import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:fund_flow/update/app_updater.dart';

void main() {
  PackageInfo package({required String name, required String build}) =>
      PackageInfo(
        appName: 'Fund Flow',
        packageName: name,
        version: '0.0.1-dev.1',
        buildNumber: build,
      );

  test('production builds never query GitHub', () async {
    var requested = false;
    final updater = AppUpdater(
      client: MockClient((_) async {
        requested = true;
        return http.Response('', 500);
      }),
    );

    final result = await updater.check(
      installedPackage: package(name: 'com.naveen.fund_flow', build: '12'),
    );

    expect(result.availability, UpdateAvailability.unsupported);
    expect(requested, isFalse);
    updater.close();
  });

  test('discovers newer prerelease and carries APK size', () async {
    final updater = AppUpdater(
      client: MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode([
              {
                'draft': false,
                'prerelease': true,
                'assets': [
                  {
                    'name': 'fund-flow-development.apk',
                    'size': 10485760,
                    'browser_download_url': 'https://github.com/apk',
                  },
                  {
                    'name': 'update.json',
                    'browser_download_url': 'https://github.com/update.json',
                  },
                ],
              },
            ]),
            200,
          );
        }
        return http.Response(jsonEncode(_manifest(build: 80)), 200);
      }),
    );

    final result = await updater.check(
      installedPackage: package(name: 'com.naveen.fund_flow.dev', build: '79'),
    );

    expect(result.availability, UpdateAvailability.available);
    expect(result.buildNumber, 80);
    expect(result.downloadSize, 10485760);
    updater.close();
  });

  test('same or older remote build is current', () async {
    final updater = _updaterWithManifest(_manifest(build: 80));
    final result = await updater.check(
      installedPackage: package(name: 'com.naveen.fund_flow.dev', build: '80'),
    );
    expect(result.availability, UpdateAvailability.current);
    updater.close();
  });

  test('rejects a manifest with an invalid checksum', () async {
    final manifest = _manifest(build: 81)..['sha256'] = 'not-a-checksum';
    final updater = _updaterWithManifest(manifest);
    expect(
      () => updater.check(
        installedPackage: package(
          name: 'com.naveen.fund_flow.dev',
          build: '80',
        ),
      ),
      throwsA(isA<UpdateException>()),
    );
    updater.close();
  });
}

AppUpdater _updaterWithManifest(Map<String, Object?> manifest) => AppUpdater(
  client: MockClient((request) async {
    if (request.url.host == 'api.github.com') {
      return http.Response(
        jsonEncode([
          {
            'draft': false,
            'prerelease': true,
            'assets': [
              {
                'name': 'update.json',
                'browser_download_url': 'https://github.com/update.json',
              },
            ],
          },
        ]),
        200,
      );
    }
    return http.Response(jsonEncode(manifest), 200);
  }),
);

Map<String, Object?> _manifest({required int build}) => {
  'schemaVersion': 1,
  'channel': 'development',
  'versionName': '0.0.1-dev.$build',
  'buildNumber': build,
  'apkUrl': 'https://github.com/NaveenBadal/fund_flow/releases/apk',
  'sha256': 'a' * 64,
  'releaseNotes': 'A calmer, smarter build.',
  'publishedAt': '2026-07-18T12:00:00Z',
  'mandatory': false,
};
