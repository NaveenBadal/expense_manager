import 'dart:io';

import 'package:flutter/material.dart';

import '../../update/app_updater.dart';
import '../tokens/flow_metrics.dart';
import '../tokens/flow_palette.dart';

/// Checking for and installing development builds from GitHub.
///
/// The sheet is a single state machine — checking, error, current, or an
/// update ready — and always shows exactly one of them with one primary
/// action, because "is there an update and what do I press" is the entire
/// job here.
class UpdateSheet extends StatefulWidget {
  const UpdateSheet({super.key});

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  final AppUpdater _updater = AppUpdater();
  AppUpdate? _update;
  File? _download;
  Object? _error;
  double? _progress;
  bool _checking = true;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _updater.close();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final value = await _updater.check();
      if (mounted) setState(() => _update = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadUpdate() async {
    final update = _update;
    if (update == null) return;
    setState(() {
      _error = null;
      _progress = 0;
    });
    try {
      final file = await _updater.download(
        update,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() => _progress = total > 0 ? received / total : null);
        },
      );
      if (mounted) setState(() => _download = file);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _install() async {
    final file = _download;
    if (file == null) return;
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await _updater.install(file);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FlowSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App updates', style: text.titleLarge),
            const SizedBox(height: FlowSpace.sm),
            Text(
              'Development releases come directly from Fund Flow on GitHub. '
              'Every APK is verified before Android opens the installer.',
              style: text.bodyMedium?.copyWith(color: flow.inkSoft),
            ),
            const SizedBox(height: FlowSpace.lg),
            AnimatedSwitcher(
              duration: FlowMotion.respecting(context, FlowMotion.quick),
              child: _content(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final flow = context.flow;
    final text = Theme.of(context).textTheme;
    if (_checking) {
      return const _Status(
        icon: Icons.sync_rounded,
        title: 'Checking GitHub',
        detail: 'Looking for a newer development build…',
        busy: true,
      );
    }
    if (_error != null) {
      final permission = _error is InstallPermissionRequired;
      return Column(
        key: const ValueKey('error'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Status(
            icon: Icons.cloud_off_outlined,
            title: permission
                ? 'One Android permission needed'
                : 'Could not continue',
            detail: _error.toString(),
          ),
          const SizedBox(height: FlowSpace.lg),
          _PrimaryButton(
            label: permission ? 'I allowed it — install' : 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: permission ? _install : _check,
          ),
        ],
      );
    }
    final update = _update!;
    if (update.availability == UpdateAvailability.unsupported) {
      return const _Status(
        icon: Icons.info_outline_rounded,
        title: 'Managed by your release channel',
        detail: 'GitHub updates are available in Fund Flow development builds.',
      );
    }
    if (update.availability == UpdateAvailability.current) {
      return _Status(
        icon: Icons.check_circle_outline_rounded,
        title: 'Fund Flow is current',
        detail: 'Build ${update.installedBuildNumber} is the newest release.',
      );
    }
    return Column(
      key: const ValueKey('available'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${update.versionName} · build ${update.buildNumber}',
                style: text.titleMedium,
              ),
            ),
            if (update.downloadSize > 0)
              Text(
                _size(update.downloadSize),
                style: text.bodySmall?.copyWith(color: flow.inkSoft),
              ),
          ],
        ),
        const SizedBox(height: FlowSpace.sm),
        Text(
          update.releaseNotes.trim().isEmpty
              ? 'A newer development build is ready.'
              : update.releaseNotes.trim(),
          style: text.bodyMedium?.copyWith(color: flow.inkSoft),
        ),
        const SizedBox(height: FlowSpace.lg),
        if (_progress != null) ...[
          LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            color: flow.accent,
            backgroundColor: flow.sunken,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: FlowSpace.sm),
          Text(
            'Downloading · ${((_progress ?? 0) * 100).round()}%',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: flow.inkSoft),
          ),
        ] else
          _PrimaryButton(
            label: _download == null
                ? 'Download and verify'
                : _installing
                ? 'Opening installer…'
                : 'Install verified update',
            icon: _download == null
                ? Icons.download_rounded
                : Icons.system_update_alt_rounded,
            onPressed: _installing
                ? null
                : _download == null
                ? _downloadUpdate
                : _install,
          ),
      ],
    );
  }

  String _size(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(FlowDensity.minimumTarget),
        backgroundColor: flow.accent,
        foregroundColor: flow.onAccent,
        shape: const RoundedRectangleBorder(borderRadius: FlowRadius.sm),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.icon,
    required this.title,
    required this.detail,
    this.busy = false,
  });
  final IconData icon;
  final String title;
  final String detail;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    final text = Theme.of(context).textTheme;
    return Container(
      key: ValueKey(title),
      padding: const EdgeInsets.all(FlowSpace.lg),
      decoration: BoxDecoration(
        color: flow.raised,
        border: Border.all(color: flow.line),
        borderRadius: FlowRadius.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          busy
              ? SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: flow.accent,
                  ),
                )
              : Icon(icon, size: 20, color: flow.accent),
          const SizedBox(width: FlowSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: FlowSpace.xs),
                Text(
                  detail,
                  style: text.bodyMedium?.copyWith(color: flow.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
