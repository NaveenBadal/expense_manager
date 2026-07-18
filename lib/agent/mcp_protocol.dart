import 'dart:convert';

enum McpRisk { read, propose, platform, compose }

class McpToolDefinition {
  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.risk,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final McpRisk risk;

  Map<String, Object?> toProviderJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': inputSchema,
    },
  };
}

class McpToolCall {
  const McpToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, Object?> arguments;

  factory McpToolCall.fromProviderJson(Map<Object?, Object?> value, int index) {
    final function = Map<Object?, Object?>.from(
      value['function'] as Map? ?? const {},
    );
    final raw = function['arguments'];
    Map<String, Object?> arguments;
    if (raw is String) {
      arguments = Map<String, Object?>.from(
        jsonDecode(raw) as Map<Object?, Object?>,
      );
    } else {
      arguments = Map<String, Object?>.from(
        raw as Map<Object?, Object?>? ?? const {},
      );
    }
    final name = function['name']?.toString().trim() ?? '';
    if (name.isEmpty) throw const McpProtocolException('Missing tool name');
    return McpToolCall(
      id: value['id']?.toString() ?? 'call_$index',
      name: name,
      arguments: arguments,
    );
  }
}

class McpToolResult {
  const McpToolResult({
    required this.callId,
    required this.tool,
    required this.content,
    this.isError = false,
    this.summary,
  });

  final String callId;
  final String tool;
  final Map<String, Object?> content;
  final bool isError;
  final String? summary;

  Map<String, Object?> toProviderMessage() => {
    'role': 'tool',
    'tool_name': tool,
    'content': jsonEncode({'ok': !isError, ...content}),
  };
}

class McpProtocolException implements Exception {
  const McpProtocolException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class McpSchema {
  static Map<String, Object?> object({
    Map<String, Object?> properties = const {},
    List<String> required = const [],
  }) => {
    'type': 'object',
    'properties': properties,
    'required': required,
    'additionalProperties': false,
  };

  static Map<String, Object?> string({List<String>? values}) => {
    'type': 'string',
    'enum': ?values,
  };

  static Map<String, Object?> integer({int? minimum, int? maximum}) => {
    'type': 'integer',
    'minimum': ?minimum,
    'maximum': ?maximum,
  };

  static Map<String, Object?> boolean() => {'type': 'boolean'};

  static Map<String, Object?> array(Map<String, Object?> items) => {
    'type': 'array',
    'items': items,
  };
}
