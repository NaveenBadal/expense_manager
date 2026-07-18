import 'dart:convert';

enum AgentPartKind {
  conclusion,
  narrative,
  metricRow,
  comparison,
  breakdown,
  transactionList,
  insight,
  sourceNote,
  followUps,
  proposal,
  warning,
}

class AgentPart {
  const AgentPart({required this.kind, required this.data});
  final AgentPartKind kind;
  final Map<String, Object?> data;

  factory AgentPart.fromJson(Map<Object?, Object?> value) {
    final type = value['type']?.toString();
    final kind = AgentPartKind.values.where((item) => item.name == type);
    if (kind.length != 1) {
      throw AgentPresentationException('Unknown answer part: $type');
    }
    final data = Map<String, Object?>.from(value)..remove('type');
    return AgentPart(kind: kind.single, data: data);
  }

  Map<String, Object?> toJson() => {'type': kind.name, ...data};
}

class AgentPresentation {
  const AgentPresentation({required this.parts, this.unstructured = false});
  final List<AgentPart> parts;
  final bool unstructured;

  String get plainText => parts
      .map((part) => part.data['text']?.toString())
      .whereType<String>()
      .join('\n\n');

  factory AgentPresentation.fromComposeArguments(
    Map<String, Object?> arguments,
  ) {
    final raw = arguments['parts'];
    if (raw is! List || raw.isEmpty || raw.length > 16) {
      throw const AgentPresentationException(
        'An answer needs between 1 and 16 parts.',
      );
    }
    final parts = raw
        .map((item) => AgentPart.fromJson(item as Map<Object?, Object?>))
        .toList();
    if (!parts.any((part) => part.kind == AgentPartKind.conclusion)) {
      throw const AgentPresentationException(
        'An answer requires a conclusion.',
      );
    }
    return AgentPresentation(parts: parts);
  }

  factory AgentPresentation.unstructured(String text) => AgentPresentation(
    unstructured: true,
    parts: [
      AgentPart(kind: AgentPartKind.narrative, data: {'text': text}),
      const AgentPart(
        kind: AgentPartKind.warning,
        data: {'text': 'The provider returned an unstructured answer.'},
      ),
    ],
  );

  static AgentPresentation? tryFromProviderContent(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      final newline = text.indexOf('\n');
      if (newline == -1) return null;
      text = text.substring(newline + 1);
      final fence = text.lastIndexOf('```');
      if (fence != -1) text = text.substring(0, fence);
      text = text.trim();
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map ||
          decoded.length != 1 ||
          !decoded.containsKey('parts')) {
        return null;
      }
      return AgentPresentation.fromComposeArguments(
        Map<String, Object?>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }
}

class AgentPresentationException implements Exception {
  const AgentPresentationException(this.message);
  final String message;
  @override
  String toString() => message;
}
