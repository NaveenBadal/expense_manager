import 'package:flutter/material.dart';

import '../tokens/flow_metrics.dart';

/// Motion primitives built on the [FlowMotion] tokens.
///
/// Each one exists for a named moment — a destination switch, a card
/// advancing, a route opening, a count changing — rather than as a general
/// animation kit. Anything that wants motion should be one of these moments.

/// Fades content in when [index] changes while leaving the child tree —
/// typically an [IndexedStack] — intact, so switching destinations reads as
/// arrival without rebuilding the destination or losing its scroll position.
class FlowIndexFade extends StatefulWidget {
  const FlowIndexFade({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<FlowIndexFade> createState() => _FlowIndexFadeState();
}

class _FlowIndexFadeState extends State<FlowIndexFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
    duration: FlowMotion.quick,
  );

  @override
  void didUpdateWidget(FlowIndexFade old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _controller.duration = FlowMotion.respecting(context, FlowMotion.quick);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: FlowMotion.enter),
      child: widget.child,
    );
  }
}

/// The route entrance for detail screens: a fade with a slight rise, so a
/// record reads as surfacing in place rather than the whole app sliding
/// sideways. Collapses to an instant cut under reduced motion.
class FlowPageRoute<T> extends PageRouteBuilder<T> {
  FlowPageRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: FlowMotion.standard,
        reverseTransitionDuration: FlowMotion.quick,
        pageBuilder: (context, animation, secondary) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) {
          if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
            return child;
          }
          final t = CurvedAnimation(
            parent: animation,
            curve: FlowMotion.enter,
            reverseCurve: FlowMotion.exit,
          );
          return FadeTransition(
            opacity: t,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .03),
                end: Offset.zero,
              ).animate(t),
              child: child,
            ),
          );
        },
      );
}

/// A piece of text — usually a count — that ticks over instead of snapping:
/// the outgoing value slips upward as the incoming one rises into place.
/// Numbers here are the model's running score, and a visible tick is what
/// makes a change noticeable at the edge of vision.
class FlowAnimatedCount extends StatelessWidget {
  const FlowAnimatedCount({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: FlowMotion.respecting(context, FlowMotion.quick),
      switchInCurve: FlowMotion.enter,
      switchOutCurve: FlowMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .4),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}

/// Advances the review card: the confirmed card exits and the next one
/// enters with a slight rise, so a tap visibly consumes an item instead of
/// the card appearing to rewrite itself in place.
class FlowCardAdvance extends StatelessWidget {
  const FlowCardAdvance({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: FlowMotion.respecting(context, FlowMotion.standard),
      switchInCurve: FlowMotion.enter,
      switchOutCurve: FlowMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .015),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}
