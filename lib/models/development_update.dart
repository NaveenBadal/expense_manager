class DevelopmentUpdate {
  const DevelopmentUpdate({
    required this.versionName,
    required this.buildNumber,
    required this.apkUrl,
    required this.sha256,
    required this.releaseNotes,
    required this.publishedAt,
    required this.mandatory,
  });

  final String versionName;
  final int buildNumber;
  final String apkUrl;
  final String sha256;
  final String releaseNotes;
  final DateTime? publishedAt;
  final bool mandatory;

  bool isNewerThan(int installedBuild) => buildNumber > installedBuild;

  factory DevelopmentUpdate.fromJson(Map<String, dynamic> json) {
    if (json['channel'] != 'development') {
      throw const FormatException('Unsupported update channel');
    }
    final versionName = json['versionName'] as String?;
    final buildNumber = json['buildNumber'] as int?;
    final apkUrl = json['apkUrl'] as String?;
    final checksum = json['sha256'] as String?;
    if (versionName == null ||
        buildNumber == null ||
        apkUrl == null ||
        checksum == null ||
        checksum.length != 64) {
      throw const FormatException('Incomplete update manifest');
    }
    return DevelopmentUpdate(
      versionName: versionName,
      buildNumber: buildNumber,
      apkUrl: apkUrl,
      sha256: checksum.toLowerCase(),
      releaseNotes: json['releaseNotes'] as String? ?? 'Development update',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}
