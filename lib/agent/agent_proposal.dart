enum AgentProposalKind {
  createTransaction,
  updateTransaction,
  deleteTransaction,
  bulkCategory,
  updateSettings,
  setAppLock,
  clearConversation,
  setMemory,
  deleteMemory,
}

enum AgentProposalStatus { pending, approved, rejected, expired, stale }

class AgentProposal {
  const AgentProposal({
    this.id,
    required this.kind,
    required this.title,
    required this.explanation,
    required this.arguments,
    required this.createdAt,
    required this.expiresAt,
    required this.affectedIds,
    this.requiresAuthentication = false,
    this.reversible = true,
    this.status = AgentProposalStatus.pending,
  });

  final int? id;
  final AgentProposalKind kind;
  final String title;
  final String explanation;
  final Map<String, Object?> arguments;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<int> affectedIds;
  final bool requiresAuthentication;
  final bool reversible;
  final AgentProposalStatus status;

  AgentProposal copyWith({int? id, AgentProposalStatus? status}) =>
      AgentProposal(
        id: id ?? this.id,
        kind: kind,
        title: title,
        explanation: explanation,
        arguments: arguments,
        createdAt: createdAt,
        expiresAt: expiresAt,
        affectedIds: affectedIds,
        requiresAuthentication: requiresAuthentication,
        reversible: reversible,
        status: status ?? this.status,
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'explanation': explanation,
    'arguments': arguments,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'affectedIds': affectedIds,
    'requiresAuthentication': requiresAuthentication,
    'reversible': reversible,
    'status': status.name,
  };
}
