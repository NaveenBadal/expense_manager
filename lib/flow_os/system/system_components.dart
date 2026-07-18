import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';
import '../primitives/cut_surface.dart';

class SystemMasthead extends StatelessWidget {
  const SystemMasthead({super.key, required this.aiOnline});

  final bool aiOnline;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences and privacy',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: FlowColor.quiet(context)),
          ),
          const SizedBox(height: 3),
          Text(
            'You',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            aiOnline
                ? 'Intelligence is connected'
                : 'Intelligence is not connected',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: aiOnline
                  ? FlowColor.income(context)
                  : FlowColor.review(context),
            ),
          ),
        ],
      ),
    ),
  );
}

class SystemSectionLabel extends StatelessWidget {
  const SystemSectionLabel(this.coordinate, {super.key});
  final String coordinate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 28, 0, 10),
    child: Text(
      coordinate,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class SystemNode extends StatelessWidget {
  const SystemNode({
    super.key,
    required this.code,
    required this.title,
    required this.detail,
    this.signal = NodeSignal.neutral,
    this.onTap,
    this.control,
  });

  final String code;
  final String title;
  final String detail;
  final NodeSignal signal;
  final VoidCallback? onTap;
  final Widget? control;

  @override
  Widget build(BuildContext context) {
    final color = switch (signal) {
      NodeSignal.live => FlowColor.mint,
      NodeSignal.attention => FlowColor.amber,
      NodeSignal.private => FlowColor.proof,
      NodeSignal.neutral => FlowColor.quiet(context),
    };
    final content = CutSurface(
      cut: 12,
      color: FlowColor.raised(context),
      accent: FlowColor.rule(context),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: FlowColor.content(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FlowColor.quiet(context),
                  ),
                ),
              ],
            ),
          ),
          if (control != null) ...[const SizedBox(width: 10), control!],
          if (control == null && onTap != null)
            Text(
              'Open',
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

enum NodeSignal { neutral, live, attention, private }

class BinaryRail extends StatelessWidget {
  const BinaryRail({
    super.key,
    required this.value,
    required this.onChanged,
    this.onLabel = 'ON',
    this.offLabel = 'OFF',
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String onLabel;
  final String offLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: value ? onLabel : offLabel,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value ? onLabel : offLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: FlowColor.quiet(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class StepRail extends StatelessWidget {
  const StepRail({
    super.key,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });
  final String value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _StepPort(
        icon: Icons.remove_rounded,
        label: 'Decrease',
        onTap: onDecrease,
      ),
      Container(
        constraints: const BoxConstraints(minWidth: 58, minHeight: 42),
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Text(
          value,
          style: TextStyle(
            color: FlowColor.proof,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      _StepPort(icon: Icons.add_rounded, label: 'Increase', onTap: onIncrease),
    ],
  );
}

class _StepPort extends StatelessWidget {
  const _StepPort({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: label, onPressed: onTap, icon: Icon(icon, size: 20));
}
