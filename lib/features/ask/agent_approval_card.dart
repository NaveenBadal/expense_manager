import 'package:flutter/material.dart';

import '../../agent/agent_proposal.dart';
import '../../ui/components/current_button.dart';
import '../../ui/foundation/current_colors.dart';

/// Approval presented in the thread rather than over it.
///
/// A change the agent proposes is part of the conversation that produced it,
/// so deciding on it should not cover the reasoning that led there. A modal
/// also made dismissal ambiguous: closing the sheet had to be read as a
/// rejection, which is a destructive default for a gesture that usually means
/// "wait". Inline, the proposal stays until it is actually answered.
class AgentApprovalCard extends StatelessWidget {
  const AgentApprovalCard({
    super.key,
    required this.proposal,
    required this.onApprove,
    required this.onReject,
  });

  final AgentProposal proposal;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 22),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.current.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.current.intelligence, width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              proposal.requiresAuthentication
                  ? Icons.lock_outline_rounded
                  : Icons.pending_actions_rounded,
              size: 17,
              color: context.current.intelligence,
            ),
            const SizedBox(width: 8),
            Text(
              'Needs your approval',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.current.intelligence,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(proposal.title, style: Theme.of(context).textTheme.titleMedium),
        if (proposal.explanation.trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            proposal.explanation,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.current.muted),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          [
            'Nothing has changed yet.',
            if (proposal.affectedIds.isNotEmpty)
              proposal.affectedIds.length == 1
                  ? 'One record is affected.'
                  : '${proposal.affectedIds.length} records are affected.',
            // Stated only when true: an irreversible change must never be
            // approved under the impression that it can be walked back.
            if (proposal.reversible) 'This can be undone.',
          ].join(' '),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.current.muted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CurrentButton(
                label: 'Reject',
                style: CurrentButtonStyle.outline,
                onPressed: onReject,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CurrentButton(
                label: proposal.requiresAuthentication
                    ? 'Approve securely'
                    : 'Approve',
                onPressed: onApprove,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
