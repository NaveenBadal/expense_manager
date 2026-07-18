import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

enum FlowOrbState { ready, thinking, syncing, success, attention, offline }

/// The single visual signature for Flow intelligence. It stays recognizable at
/// every size and only animates while the agent is actively doing work.
class FlowOrb extends StatelessWidget {
  const FlowOrb({
    super.key,
    this.size = 48,
    this.state = FlowOrbState.ready,
    this.progress,
  });

  final double size;
  final FlowOrbState state;
  final double? progress;

  bool get _active =>
      state == FlowOrbState.thinking || state == FlowOrbState.syncing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (state) {
      FlowOrbState.success => context.finance.income,
      FlowOrbState.attention => context.finance.warning,
      FlowOrbState.offline => Color.lerp(scheme.primary, scheme.surface, .32)!,
      _ => scheme.primary,
    };
    return Semantics(
      image: true,
      label: 'Flow ${state.name}',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _FlowOrbPainter(
            color: color,
            surface: scheme.surface,
            phase: 0,
            active: _active,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _FlowOrbPainter extends CustomPainter {
  const _FlowOrbPainter({
    required this.color,
    required this.surface,
    required this.phase,
    required this.active,
    this.progress,
  });

  final Color color;
  final Color surface;
  final double phase;
  final bool active;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final pulse = active ? .94 + .06 * ((phase * 2 - 1).abs()) : 1.0;
    canvas.drawCircle(
      center,
      radius * pulse,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.28, -.34),
          colors: [
            Color.lerp(color, Colors.white, .62)!,
            color,
            Color.lerp(color, Colors.black, .22)!,
          ],
          stops: const [0, .48, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      center.translate(-radius * .23, -radius * .28),
      radius * .17,
      Paint()..color = Colors.white.withValues(alpha: .72),
    );
    canvas.drawCircle(
      center,
      radius * .43,
      Paint()
        ..color = surface.withValues(alpha: .94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .13,
    );
    final value = progress;
    if (value != null) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * .82),
        -1.5708,
        6.2832 * value.clamp(0, 1),
        false,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = radius * .09,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlowOrbPainter old) =>
      old.color != color ||
      old.phase != phase ||
      old.active != active ||
      old.progress != progress;
}

/// A restrained ambient canvas. Color lives near the agent and fades before
/// reaching evidence content, keeping long-form information perfectly calm.
class FlowAtmosphere extends StatelessWidget {
  const FlowAtmosphere({super.key, required this.child, this.alignment});

  final Widget child;
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? FlowPalette.night : FlowPalette.paper,
                gradient: RadialGradient(
                  center: alignment ?? const Alignment(.72, -1.05),
                  radius: 1.08,
                  colors: [
                    (dark
                            ? FlowPalette.darkAtmosphere
                            : FlowPalette.lightAtmosphere)
                        .withValues(alpha: dark ? .34 : .48),
                    (dark ? FlowPalette.night : FlowPalette.paper).withValues(
                      alpha: 0,
                    ),
                  ],
                  stops: const [0, .68],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// The only translucent surface role: primary navigation and transient
/// controls. Content and evidence must use opaque tonal surfaces instead.
class FlowGlass extends StatelessWidget {
  const FlowGlass({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadius.xl,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final borderRadius = BorderRadius.circular(radius);
    final surface = scheme.surfaceContainer.withValues(alpha: reduce ? 1 : .82);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: PremiumShadows.ambient(
          context,
          color: Colors.black,
          offset: 8,
          blur: 28,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: borderRadius,
            border: Border.all(color: scheme.onSurface.withValues(alpha: .09)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Consistent opening anatomy for modal tasks. Sheets are focused continuations
/// of the control that opened them, so the header states purpose before fields.
class FlowSheetHeader extends StatelessWidget {
  const FlowSheetHeader({
    super.key,
    required this.title,
    required this.description,
    this.leading,
  });

  final String title;
  final String description;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          SizedBox.square(dimension: 48, child: Center(child: leading)),
          const SizedBox(width: AppSpacing.lg),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared adaptive page frame for secondary Flow tasks.
class FlowScaffold extends StatelessWidget {
  const FlowScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.eyebrow,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: floatingActionButton,
    body: CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverAppBar.large(
          pinned: true,
          title: Text(title, style: Theme.of(context).textTheme.headlineMedium),
          actions: actions,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        if (eyebrow != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.section,
              ),
              child: Text(
                eyebrow!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.narrative)),
      ],
    ),
  );
}

/// Complete, non-technical loading/empty/restricted/error state.
class StatePanel extends StatelessWidget {
  const StatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoint.contentMax),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.region),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: ShapeDecoration(
                  color: scheme.primaryContainer,
                  shape: ExpressiveShape.card(
                    radius: AppRadius.xl,
                    color: scheme.primary.withValues(alpha: .12),
                  ),
                ),
                child: Icon(icon, color: scheme.primary, size: 30),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _friendlyMessage(message),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.section),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyMessage(String raw) {
    final technical =
        raw.contains('Exception') ||
        raw.contains('DatabaseException') ||
        raw.contains('SocketException') ||
        raw.contains('StackTrace');
    return technical
        ? 'Something interrupted this view. Your data is safe; try again.'
        : raw;
  }
}
