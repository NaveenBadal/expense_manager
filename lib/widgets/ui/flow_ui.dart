import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

enum FlowOrbState { ready, thinking, syncing, success, attention, offline }

/// The single visual signature for Flow intelligence: a static field of
/// signals, never a continuously animated decoration.
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
            accent: state == FlowOrbState.attention
                ? context.finance.warning
                : FlowPalette.signalCyan,
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
    required this.accent,
    this.progress,
  });

  final Color color;
  final Color accent;
  final double? progress;

  static const _signals = <(double, double, double)>[
    (.50, .07, .72),
    (.28, .15, .58),
    (.50, .19, .82),
    (.72, .15, .58),
    (.14, .31, .52),
    (.35, .34, .78),
    (.50, .38, 1.00),
    (.65, .34, .78),
    (.86, .31, .52),
    (.07, .52, .45),
    (.27, .54, .72),
    (.50, .50, 1.12),
    (.73, .54, .72),
    (.93, .52, .45),
    (.14, .73, .52),
    (.35, .68, .78),
    (.50, .62, 1.00),
    (.65, .68, .78),
    (.86, .73, .52),
    (.28, .87, .58),
    (.50, .81, .82),
    (.72, .87, .58),
    (.50, .95, .72),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final baseRadius = size.shortestSide * .065;
    final completed = progress == null
        ? _signals.length
        : (_signals.length * progress!.clamp(0, 1)).ceil();
    for (var index = 0; index < _signals.length; index++) {
      final signal = _signals[index];
      final enabled = index < completed;
      final highlight = index == 6 || index == 11 || index == 16;
      canvas.drawCircle(
        Offset(size.width * signal.$1, size.height * signal.$2),
        baseRadius * signal.$3,
        Paint()
          ..color = enabled
              ? (highlight ? accent : color).withValues(
                  alpha: .56 + signal.$3.clamp(0, 1) * .4,
                )
              : color.withValues(alpha: .16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlowOrbPainter old) =>
      old.color != color || old.accent != accent || old.progress != progress;
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
    body: FlowAtmosphere(
      alignment: const Alignment(.8, -1.1),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 84,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FlowOrb(size: 30),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
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
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.narrative),
          ),
        ],
      ),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FlowOrb(size: 58, state: FlowOrbState.attention),
                  const SizedBox(width: 12),
                  Icon(icon, color: scheme.primary, size: 30),
                ],
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
