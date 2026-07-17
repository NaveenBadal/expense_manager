import 'dart:convert';

enum AgentArtifactKind {
  none,
  transactions,
  summary,
  breakdown,
  comparison,
  recurring,
  forecast,
  anomalies,
  action,
  insight,
}

/// A persisted, renderer-neutral description of a financial answer.
///
/// The model never constructs this object. It is produced from validated local
/// tool output, which lets the UI render trustworthy financial components while
/// keeping natural-language explanation separate from authoritative values.
class AgentArtifact {
  const AgentArtifact({
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.data = const {},
    this.actions = const [],
  });

  const AgentArtifact.none()
    : kind = AgentArtifactKind.none,
      title = '',
      subtitle = '',
      data = const {},
      actions = const [];

  final AgentArtifactKind kind;
  final String title;
  final String subtitle;
  final Map<String, dynamic> data;
  final List<String> actions;

  bool get isEmpty => kind == AgentArtifactKind.none;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'title': title,
    'subtitle': subtitle,
    'data': data,
    'actions': actions,
  };

  String encode() => jsonEncode(toJson());

  factory AgentArtifact.fromJson(Map<String, dynamic> json) => AgentArtifact(
    kind: AgentArtifactKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => AgentArtifactKind.none,
    ),
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString() ?? '',
    data: json['data'] is Map
        ? (json['data'] as Map).cast<String, dynamic>()
        : const {},
    actions: (json['actions'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(),
  );

  factory AgentArtifact.decode(String raw) {
    if (raw.trim().isEmpty) return const AgentArtifact.none();
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? AgentArtifact.fromJson(decoded.cast<String, dynamic>())
          : const AgentArtifact.none();
    } catch (_) {
      return const AgentArtifact.none();
    }
  }
}

class FinancialInsight {
  const FinancialInsight({
    required this.id,
    required this.title,
    required this.detail,
    required this.severity,
    required this.prompt,
    this.amount,
    this.currency,
  });

  final String id;
  final String title;
  final String detail;
  final String severity;
  final String prompt;
  final double? amount;
  final String? currency;
}
