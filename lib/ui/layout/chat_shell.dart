import 'package:flutter/material.dart';

import '../foundation/current_colors.dart';

/// Chat-first layout.
///
/// Conversation is the app rather than one tab inside it: anything the agent
/// can do is reachable without leaving it. The record of transactions is a
/// surface pulled over the conversation, so consulting it never unloads the
/// thread someone is in the middle of.
///
/// Above [wideBreakpoint] the record becomes a permanent side panel instead,
/// because a screen that wide can show both without either being cramped.
class ChatShell extends StatelessWidget {
  const ChatShell({
    super.key,
    required this.chat,
    required this.activityBuilder,
    required this.activityLabel,
  });

  final Widget chat;

  /// Built lazily: on narrow screens the record is not mounted until it is
  /// actually pulled open.
  final WidgetBuilder activityBuilder;

  /// Summary shown on the handle, for example "42 this month".
  final String activityLabel;

  static const double wideBreakpoint = 760;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth >= wideBreakpoint) {
        return Scaffold(
          body: Row(
            children: [
              Expanded(child: SafeArea(bottom: false, child: chat)),
              Container(width: 1, color: context.current.rule),
              SizedBox(
                width: 380,
                child: SafeArea(
                  bottom: false,
                  child: Builder(builder: activityBuilder),
                ),
              ),
            ],
          ),
        );
      }
      return Scaffold(
        body: Column(
          children: [
            Expanded(child: SafeArea(bottom: false, child: chat)),
            _ActivityHandle(
              label: activityLabel,
              onOpen: () => openActivitySheet(context, activityBuilder),
            ),
          ],
        ),
      );
    },
  );

  /// Presents the record over the conversation.
  static Future<void> openActivitySheet(
    BuildContext context,
    WidgetBuilder builder,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .5,
      maxChildSize: .96,
      builder: (context, controller) => Column(
        children: [
          const _GrabHandle(),
          Expanded(
            // The record supplies its own scrollable, so the drag controller
            // is handed down through a PrimaryScrollController rather than
            // nesting a second scroll view inside this one.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: PrimaryScrollController(
                controller: controller,
                child: Builder(builder: builder),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: context.current.rule,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// Persistent affordance under the composer.
///
/// Responds to an upward drag as well as a tap, so the gesture matches what
/// the shape of a handle implies.
class _ActivityHandle extends StatelessWidget {
  const _ActivityHandle({required this.label, required this.onOpen});
  final String label;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open activity. $label',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onOpen,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -120) onOpen();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: context.current.surface,
          border: Border(top: BorderSide(color: context.current.rule)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 3,
                decoration: BoxDecoration(
                  color: context.current.rule,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.current.muted),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: context.current.muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
