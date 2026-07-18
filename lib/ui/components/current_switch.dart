import 'package:flutter/material.dart';

import '../foundation/current_colors.dart';

class CurrentSwitch extends StatelessWidget {
  const CurrentSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    enabled: onChanged != null,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 48,
        height: 30,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: value ? context.current.intelligence : context.current.subtle,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: value ? context.current.intelligence : context.current.rule,
          ),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: value ? Colors.white : context.current.muted,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}
