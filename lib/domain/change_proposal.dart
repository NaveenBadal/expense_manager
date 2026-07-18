class ChangeProposal {
  const ChangeProposal({
    required this.transactionId,
    required this.merchant,
    required this.fromCategory,
    required this.toCategory,
  });

  final int transactionId;
  final String merchant;
  final String fromCategory;
  final String toCategory;
}
