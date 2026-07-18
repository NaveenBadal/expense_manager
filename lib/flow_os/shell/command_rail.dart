import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

class CommandRail extends StatelessWidget {
  const CommandRail({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.proofCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int? proofCount;

  static const _destinations = [
    (Icons.chat_bubble_outline_rounded, 'Ask'),
    (Icons.receipt_long_outlined, 'Activity'),
    (Icons.person_outline_rounded, 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FlowColor.raised(context),
        border: Border(top: BorderSide(color: FlowColor.rule(context))),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 5, 12, 7),
        child: SizedBox(
          height: 62 + ((textScale - 1).clamp(0, 1) * 30),
          child: Row(
            children: List.generate(_destinations.length, (index) {
              final destination = _destinations[index];
              final selected = index == selectedIndex;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: destination.$2,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelected(index),
                    child: AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            width: 2,
                            color: selected
                                ? FlowColor.intelligence(context)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            destination.$1,
                            size: 21,
                            color: selected
                                ? FlowColor.intelligence(context)
                                : FlowColor.quiet(context),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            destination.$2,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: selected
                                      ? FlowColor.content(context)
                                      : FlowColor.quiet(context),
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
