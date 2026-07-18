import 'package:flutter/material.dart';

import '../foundation/current_colors.dart';

class CurrentSheet extends StatelessWidget {
  const CurrentSheet({
    super.key,
    required this.title,
    required this.child,
    this.explanation,
    this.actions,
  });

  final String title;
  final String? explanation;
  final Widget child;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.current.rule,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (explanation != null) ...[
              const SizedBox(height: 10),
              Text(
                explanation!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.current.muted),
              ),
            ],
            const SizedBox(height: 22),
            child,
            if (actions != null) ...[const SizedBox(height: 24), actions!],
          ],
        ),
      ),
    ),
  );
}
