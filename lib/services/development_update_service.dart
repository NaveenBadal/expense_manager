import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/development_update.dart';

const githubDevelopmentUpdatesEnabled = bool.fromEnvironment(
  'ENABLE_GITHUB_UPDATES',
  defaultValue: false,
);

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.installedVersion,
    required this.installedBuild,
    this.update,
  });

  final String installedVersion;
  final int installedBuild;
  final DevelopmentUpdate? update;
}

class DevelopmentUpdateService {
  DevelopmentUpdateService({http.Client? client})
    : _client = client ?? http.Client();

  static const _releasesUrl =
      'https://api.github.com/repos/NaveenBadal/expense_manager/releases?per_page=10';
  static const _channel = MethodChannel('com.naveen.expense_manager/updater');

  final http.Client _client;

  bool get isSupported =>
      githubDevelopmentUpdatesEnabled && !kIsWeb && Platform.isAndroid;

  Future<UpdateCheckResult> check() async {
    if (!isSupported) {
      throw UnsupportedError('Development updates are not enabled');
    }
    final package = await PackageInfo.fromPlatform();
    final installedBuild = int.tryParse(package.buildNumber) ?? 0;
    final response = await _client
        .get(
          Uri.parse(_releasesUrl),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'Fund-Flow-Development-Updater',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException(
        response.statusCode == 404
            ? 'The development release feed is unavailable. The repository must be public.'
            : 'GitHub returned ${response.statusCode}',
      );
    }
    final releases = jsonDecode(response.body) as List<dynamic>;
    Map<String, dynamic>? release;
    for (final candidate in releases.cast<Map<String, dynamic>>()) {
      final tag = candidate['tag_name'] as String? ?? '';
      if (candidate['prerelease'] == true &&
          candidate['draft'] != true &&
          tag.startsWith('dev-v')) {
        release = candidate;
        break;
      }
    }
    if (release == null) {
      return UpdateCheckResult(
        installedVersion: package.version,
        installedBuild: installedBuild,
      );
    }
    final assets = (release['assets'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final manifestAsset = assets.where(
      (asset) => asset['name'] == 'update.json',
    );
    if (manifestAsset.isEmpty) {
      throw const FormatException('Release has no update manifest');
    }
    final manifestUrl =
        manifestAsset.first['browser_download_url'] as String? ?? '';
    final manifestResponse = await _client
        .get(Uri.parse(manifestUrl))
        .timeout(const Duration(seconds: 15));
    if (manifestResponse.statusCode != 200) {
      throw HttpException(
        'Could not download the update manifest (${manifestResponse.statusCode})',
      );
    }
    final update = DevelopmentUpdate.fromJson(
      jsonDecode(manifestResponse.body) as Map<String, dynamic>,
    );
    return UpdateCheckResult(
      installedVersion: package.version,
      installedBuild: installedBuild,
      update: update.isNewerThan(installedBuild) ? update : null,
    );
  }

  Future<String> download(
    DevelopmentUpdate update, {
    required ValueChanged<double> onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(update.apkUrl));
    request.headers['User-Agent'] = 'Fund-Flow-Development-Updater';
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('APK download failed (${response.statusCode})');
    }
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/updates');
    await directory.create(recursive: true);
    final file = File('${directory.path}/fund-flow-${update.buildNumber}.apk');
    final output = file.openWrite();
    final total = response.contentLength ?? 0;
    var received = 0;
    await for (final chunk in response.stream) {
      output.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress((received / total).clamp(0, 1));
    }
    await output.flush();
    await output.close();

    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString().toLowerCase() != update.sha256) {
      await file.delete();
      throw const FormatException(
        'The downloaded APK did not match its published checksum',
      );
    }
    onProgress(1);
    return file.path;
  }

  Future<bool> canRequestInstalls() async =>
      await _channel.invokeMethod<bool>('canRequestInstalls') ?? false;

  Future<void> openInstallPermission() =>
      _channel.invokeMethod<void>('openInstallPermission');

  Future<void> install(String path) =>
      _channel.invokeMethod<void>('installApk', {'path': path});
}
