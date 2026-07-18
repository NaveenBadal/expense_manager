enum AgentProposalKind {
  createTransaction,
  updateTransaction,
  deleteTransaction,
  bulkCategory,
  updateSettings,
  setAppLock,
  clearConversation,
}

class AgentProposal {
  const AgentProposal({
    required this.kind,
    required this.title,
    required this.explanation,
    required this.arguments,
    required this.createdAt,
    required this.expiresAt,
    required this.affectedIds,
    this.requiresAuthentication = false,
    this.reversible = true,
  });

  final AgentProposalKind kind;
  final String title;
  final String explanation;
  final Map<String, Object?> arguments;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<int> affectedIds;
  final bool requiresAuthentication;
  final bool reversible;
}
