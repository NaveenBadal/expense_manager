import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/development_update_provider.dart';
import '../services/development_update_service.dart';
import '../theme/app_tokens.dart';

class DevelopmentUpdateBanner extends ConsumerWidget {
  const DevelopmentUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(developmentUpdateProvider);
    if (state.phase != DevelopmentUpdatePhase.available &&
        state.phase != DevelopmentUpdatePhase.downloading &&
        state.phase != DevelopmentUpdatePhase.ready &&
        state.phase != DevelopmentUpdatePhase.permissionRequired) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.all(AppRadius.lg),
        child: InkWell(
          borderRadius: AppRadius.all(AppRadius.lg),
          onTap: () => showDevelopmentUpdateSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.system_update_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.phase == DevelopmentUpdatePhase.ready ||
                                state.phase ==
                                    DevelopmentUpdatePhase.permissionRequired
                            ? 'Development update ready'
                            : state.phase == DevelopmentUpdatePhase.downloading
                            ? 'Downloading update…'
                            : '${state.update?.versionName} is available',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.update?.releaseNotes ??
                            'Tap to continue the update.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (state.phase ==
                          DevelopmentUpdatePhase.downloading) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: state.progress),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DevelopmentUpdateSettingsCard extends ConsumerWidget {
  const DevelopmentUpdateSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!githubDevelopmentUpdatesEnabled) return const SizedBox.shrink();
    final state = ref.watch(developmentUpdateProvider);
    final busy =
        state.phase == DevelopmentUpdatePhase.checking ||
        state.phase == DevelopmentUpdatePhase.downloading;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.all(AppRadius.lg),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.system_update_alt_rounded),
        title: const Text(
          'Development updates',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_status(state)),
        trailing: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: busy
            ? null
            : () async {
                if (state.phase == DevelopmentUpdatePhase.idle ||
                    state.phase == DevelopmentUpdatePhase.upToDate ||
                    state.phase == DevelopmentUpdatePhase.error) {
                  await ref.read(developmentUpdateProvider.notifier).check();
                }
                if (context.mounted) await showDevelopmentUpdateSheet(context);
              },
      ),
    );
  }

  String _status(DevelopmentUpdateState state) => switch (state.phase) {
    DevelopmentUpdatePhase.idle => 'GitHub development channel',
    DevelopmentUpdatePhase.checking => 'Checking GitHub…',
    DevelopmentUpdatePhase.upToDate =>
      '${state.installedVersion ?? 'Installed build'} is current',
    DevelopmentUpdatePhase.available =>
      '${state.update?.versionName} is available',
    DevelopmentUpdatePhase.downloading =>
      'Downloading ${(state.progress * 100).round()}%',
    DevelopmentUpdatePhase.ready => 'Downloaded and verified',
    DevelopmentUpdatePhase.permissionRequired =>
      'Android install permission required',
    DevelopmentUpdatePhase.error => state.message ?? 'Update check failed',
    DevelopmentUpdatePhase.disabled => 'Disabled in this build',
  };
}

/// Flow-native update control used inside the Evolution DNA strand.
class DevelopmentUpdateDnaControl extends ConsumerWidget {
  const DevelopmentUpdateDnaControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(developmentUpdateProvider);
    final busy =
        state.phase == DevelopmentUpdatePhase.checking ||
        state.phase == DevelopmentUpdatePhase.downloading;
    final accent = switch (state.phase) {
      DevelopmentUpdatePhase.available ||
      DevelopmentUpdatePhase.ready ||
      DevelopmentUpdatePhase.permissionRequired => const Color(0xFFC7FF4A),
      DevelopmentUpdatePhase.error => Theme.of(context).colorScheme.error,
      _ => const Color(0xFF65EAD1),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(26),
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(6),
        ),
        border: Border.all(color: accent.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: accent, blurRadius: 10)],
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'GITHUB EVOLUTION CHANNEL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (state.installedBuild != null)
                Text(
                  'BUILD ${state.installedBuild}',
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _flowStatus(state),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (state.phase == DevelopmentUpdatePhase.downloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: state.progress,
              color: accent,
              backgroundColor: Colors.white12,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => _continue(context, ref, state),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: .45)),
              ),
              icon: Icon(_flowIcon(state), size: 18),
              label: Text(_flowAction(state)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continue(
    BuildContext context,
    WidgetRef ref,
    DevelopmentUpdateState state,
  ) async {
    final updater = ref.read(developmentUpdateProvider.notifier);
    if (state.phase == DevelopmentUpdatePhase.available) {
      await updater.download();
    } else if (state.phase == DevelopmentUpdatePhase.ready ||
        state.phase == DevelopmentUpdatePhase.permissionRequired) {
      await updater.install();
    } else if (state.phase == DevelopmentUpdatePhase.disabled) {
      return;
    } else {
      await updater.check();
    }
    if (context.mounted &&
        ref.read(developmentUpdateProvider).phase ==
            DevelopmentUpdatePhase.available) {
      await showDevelopmentUpdateSheet(context);
    }
  }

  String _flowStatus(DevelopmentUpdateState state) => switch (state.phase) {
    DevelopmentUpdatePhase.disabled =>
      'This APK was not built with the GitHub evolution channel enabled.',
    DevelopmentUpdatePhase.idle =>
      'Ready to look for a newer signed development build.',
    DevelopmentUpdatePhase.checking => 'Tracing the latest GitHub release…',
    DevelopmentUpdatePhase.upToDate =>
      '${state.installedVersion ?? 'This build'} is the newest evolution.',
    DevelopmentUpdatePhase.available =>
      '${state.update?.versionName} is ready to enter your world.',
    DevelopmentUpdatePhase.downloading =>
      'Receiving and verifying ${(state.progress * 100).round()}%…',
    DevelopmentUpdatePhase.ready => 'Downloaded. Signature checksum verified.',
    DevelopmentUpdatePhase.permissionRequired =>
      'Android needs permission to install this verified build.',
    DevelopmentUpdatePhase.error =>
      state.message ?? 'The evolution channel could not be reached.',
  };

  String _flowAction(DevelopmentUpdateState state) => switch (state.phase) {
    DevelopmentUpdatePhase.available => 'Receive update',
    DevelopmentUpdatePhase.ready => 'Install evolution',
    DevelopmentUpdatePhase.permissionRequired => 'Allow installation',
    DevelopmentUpdatePhase.upToDate => 'Check again',
    DevelopmentUpdatePhase.error => 'Retry channel',
    DevelopmentUpdatePhase.disabled => 'Unavailable in this build',
    _ => 'Check evolution channel',
  };

  IconData _flowIcon(DevelopmentUpdateState state) => switch (state.phase) {
    DevelopmentUpdatePhase.available => Icons.south_rounded,
    DevelopmentUpdatePhase.ready ||
    DevelopmentUpdatePhase.permissionRequired => Icons.install_mobile_rounded,
    _ => Icons.sync_rounded,
  };
}

Future<void> showDevelopmentUpdateSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _DevelopmentUpdateSheet(),
    );

class _DevelopmentUpdateSheet extends ConsumerWidget {
  const _DevelopmentUpdateSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(developmentUpdateProvider);
    final update = state.update;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: AppRadius.all(17),
              ),
              child: Icon(Icons.system_update_rounded, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              update == null
                  ? 'Development updates'
                  : 'Fund Flow ${update.versionName}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _description(state),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (state.phase == DevelopmentUpdatePhase.downloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: state.progress),
              const SizedBox(height: 7),
              Text('${(state.progress * 100).round()}% downloaded'),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _action(ref, state),
                icon: Icon(_actionIcon(state)),
                label: Text(_actionLabel(state)),
              ),
            ),
            if (state.installedVersion != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Installed ${state.installedVersion} (${state.installedBuild})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  VoidCallback? _action(WidgetRef ref, DevelopmentUpdateState state) =>
      switch (state.phase) {
        DevelopmentUpdatePhase.available =>
          () => ref.read(developmentUpdateProvider.notifier).download(),
        DevelopmentUpdatePhase.ready ||
        DevelopmentUpdatePhase.permissionRequired =>
          () => ref.read(developmentUpdateProvider.notifier).install(),
        DevelopmentUpdatePhase.idle ||
        DevelopmentUpdatePhase.upToDate ||
        DevelopmentUpdatePhase.error =>
          () => ref.read(developmentUpdateProvider.notifier).check(),
        _ => null,
      };

  String _actionLabel(DevelopmentUpdateState state) => switch (state.phase) {
    DevelopmentUpdatePhase.available => 'Download verified update',
    DevelopmentUpdatePhase.downloading => 'Downloading…',
    DevelopmentUpdatePhase.ready => 'Install update',
    DevelopmentUpdatePhase.permissionRequired => 'Allow and install',
    DevelopmentUpdatePhase.checking => 'Checking…',
    _ => 'Check again',
  };

  IconData _actionIcon(DevelopmentUpdateState state) => switch (state.phase) {
    DevelopmentUpdatePhase.available => Icons.download_rounded,
    DevelopmentUpdatePhase.ready ||
    DevelopmentUpdatePhase.permissionRequired => Icons.install_mobile_rounded,
    _ => Icons.refresh_rounded,
  };

  String _description(DevelopmentUpdateState state) {
    if (state.phase == DevelopmentUpdatePhase.permissionRequired) {
      return 'Android opened “Install unknown apps.” Allow Fund Flow Dev, return here, and tap Allow and install again.';
    }
    if (state.phase == DevelopmentUpdatePhase.ready) {
      return 'The APK checksum is valid. Android will ask you to approve replacing the current development build.';
    }
    if (state.phase == DevelopmentUpdatePhase.error) {
      return state.message ?? 'The update channel could not be reached.';
    }
    if (state.phase == DevelopmentUpdatePhase.upToDate) {
      return 'You already have the newest published GitHub development build.';
    }
    return state.update?.releaseNotes ??
        'Check GitHub Releases for a newer signed development build.';
  }
}
