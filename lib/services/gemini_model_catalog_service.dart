import 'dart:convert';
import 'dart:io';

class GeminiModelCatalogItem {
  const GeminiModelCatalogItem({
    required this.name,
    required this.displayName,
    required this.description,
    required this.inputTokenLimit,
    required this.outputTokenLimit,
    required this.supportsGenerateContent,
  });

  final String name;
  final String displayName;
  final String description;
  final int? inputTokenLimit;
  final int? outputTokenLimit;
  final bool supportsGenerateContent;

  factory GeminiModelCatalogItem.fromMap(Map<String, dynamic> map) {
    final resourceName = (map['name'] as String? ?? '').trim();
    final modelName = resourceName.startsWith('models/')
        ? resourceName.substring('models/'.length)
        : resourceName;
    final methods = (map['supportedGenerationMethods'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();

    return GeminiModelCatalogItem(
      name: modelName,
      displayName: (map['displayName'] as String?)?.trim().isNotEmpty == true
          ? (map['displayName'] as String).trim()
          : modelName,
      description: (map['description'] as String? ?? '').trim(),
      inputTokenLimit: (map['inputTokenLimit'] as num?)?.toInt(),
      outputTokenLimit: (map['outputTokenLimit'] as num?)?.toInt(),
      supportsGenerateContent: methods.contains('generateContent'),
    );
  }
}

class GeminiModelCatalogService {
  const GeminiModelCatalogService();

  static const _host = 'generativelanguage.googleapis.com';
  static const _path = '/v1beta/models';

  Future<List<GeminiModelCatalogItem>> fetchModels(String apiKey) async {
    final client = HttpClient();
    final allModels = <GeminiModelCatalogItem>[];
    String? nextPageToken;

    try {
      do {
        final uri = Uri.https(_host, _path, {
          'key': apiKey,
          'pageSize': '1000',
          if (nextPageToken != null && nextPageToken.isNotEmpty) 'pageToken': nextPageToken,
        });
        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');

        final response = await request.close();
        final responseText = await response.transform(utf8.decoder).join();

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Gemini ListModels failed (${response.statusCode}): $responseText',
            uri: uri,
          );
        }

        final data = json.decode(responseText) as Map<String, dynamic>;
        final models = (data['models'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(GeminiModelCatalogItem.fromMap)
            .where((model) => model.supportsGenerateContent && model.name.isNotEmpty)
            .toList();
        allModels.addAll(models);

        nextPageToken = data['nextPageToken'] as String?;
      } while (nextPageToken != null && nextPageToken.isNotEmpty);
    } finally {
      client.close(force: true);
    }

    final deduped = <String, GeminiModelCatalogItem>{};
    for (final model in allModels) {
      deduped[model.name] = model;
    }

    final result = deduped.values.toList()
      ..sort((a, b) {
        final flashCompare = a.name.compareTo(b.name);
        return flashCompare != 0
            ? flashCompare
            : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
    return result;
  }
}
