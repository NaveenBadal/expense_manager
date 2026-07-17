import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

class CommandScaffold extends StatelessWidget {
  const CommandScaffold({
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(
            expandedHeight: 168,
            actions: actions,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              expandedTitleScale: 1.5,
              title: Text(title),
              background: Align(
                alignment: Alignment.topRight,
                child: Transform.translate(
                  offset: const Offset(46, -54),
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          ...slivers,
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Material(
          color: scheme.primaryContainer,
          shape: ExpressiveShape.hero(),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.surface,
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _friendlyMessage(message),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 20), action!],
              ],
            ),
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
        ? 'Something interrupted this view. Your data is safe; please try again.'
        : raw;
  }
}
