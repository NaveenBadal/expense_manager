import 'package:flutter/material.dart';

import '../tokens/flow_metrics.dart';
import '../tokens/flow_palette.dart';

/// Asks before deleting [count] transactions. Returns true only on an
/// explicit confirmation; dismissing the sheet keeps everything.
Future<bool> confirmDeleteTransactions(
  BuildContext context, {
  required int count,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheet) => _DeleteSheet(count: count),
  );
  return confirmed ?? false;
}

class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(FlowSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == 1
                  ? 'Delete 1 transaction?'
                  : 'Delete $count transactions?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: FlowSpace.sm),
            Text(
              count == 1
                  ? 'It is removed from Activity and from future answers. '
                        'This cannot be undone.'
                  : 'They are removed from Activity and from future answers. '
                        'This cannot be undone.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: flow.inkSoft),
            ),
            const SizedBox(height: FlowSpace.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        FlowDensity.minimumTarget,
                      ),
                      side: BorderSide(color: flow.line),
                      foregroundColor: flow.ink,
                      shape: const RoundedRectangleBorder(
                        borderRadius: FlowRadius.sm,
                      ),
                    ),
                    child: const Text('Keep'),
                  ),
                ),
                const SizedBox(width: FlowSpace.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        FlowDensity.minimumTarget,
                      ),
                      backgroundColor: flow.expense,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: FlowRadius.sm,
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
