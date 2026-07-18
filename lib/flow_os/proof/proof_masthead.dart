import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

class ProofMasthead extends StatelessWidget {
  const ProofMasthead({
    super.key,
    required this.hidden,
    required this.onPrivacy,
    required this.onManualEntry,
  });
  final bool hidden;
  final VoidCallback onPrivacy;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your money record',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FlowColor.quiet(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Activity',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: hidden ? 'Show amounts' : 'Hide amounts',
            onPressed: onPrivacy,
            icon: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Add transaction',
            onPressed: onManualEntry,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    ),
  );
}
