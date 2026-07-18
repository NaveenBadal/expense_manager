import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

class CommandColumn extends StatelessWidget {
  const CommandColumn({
    super.key,
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.chat_bubble_outline_rounded, 'Ask', 'Talk about your money'),
    (Icons.receipt_long_outlined, 'Activity', 'Your money record'),
    (Icons.person_outline_rounded, 'You', 'Preferences and privacy'),
  ];

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: FlowColor.raised(context),
    child: SafeArea(
      child: SizedBox(
        width: extended ? 228 : 78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (extended)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Fund Flow',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.water_rounded,
                  color: FlowColor.intelligence(context),
                  size: 28,
                ),
              const SizedBox(height: 36),
              for (var index = 0; index < _items.length; index++) ...[
                _Destination(
                  icon: _items[index].$1,
                  label: _items[index].$2,
                  detail: _items[index].$3,
                  selected: selectedIndex == index,
                  extended: extended,
                  onTap: () => onSelected(index),
                ),
                const SizedBox(height: 8),
              ],
              const Spacer(),
              if (extended)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Private by default',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FlowColor.quiet(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.label,
    required this.detail,
    required this.selected,
    required this.extended,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String detail;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: EdgeInsets.symmetric(
          horizontal: extended ? 12 : 0,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? FlowColor.plane(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              width: 2,
              color: selected
                  ? FlowColor.intelligence(context)
                  : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: extended
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? FlowColor.intelligence(context)
                  : FlowColor.quiet(context),
            ),
            if (extended) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: FlowColor.quiet(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
