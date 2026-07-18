import 'dart:io';

import 'package:flutter/material.dart';

import '../../ui/components/current_button.dart';
import '../../ui/components/current_sheet.dart';
import '../../ui/foundation/current_colors.dart';
import '../../update/app_updater.dart';

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
  Widget build(BuildContext context) => CurrentSheet(
    title: 'App updates',
    explanation:
        'Development releases come directly from Fund Flow on GitHub. Every APK is verified before Android opens the installer.',
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: _content(context),
    ),
  );

  Widget _content(BuildContext context) {
    if (_checking) {
      return const _Status(
        icon: Icons.sync_rounded,
        title: 'Checking GitHub',
        detail: 'Looking for a newer development build…',
        busy: true,
      );
    }
    if (_error != null) {
      return Column(
        key: const ValueKey('error'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Status(
            icon: Icons.cloud_off_outlined,
            title: _error is InstallPermissionRequired
                ? 'One Android permission needed'
                : 'Could not continue',
            detail: _error.toString(),
          ),
          const SizedBox(height: 18),
          CurrentButton(
            label: _error is InstallPermissionRequired
                ? 'I allowed it — install'
                : 'Try again',
            icon: Icons.refresh_rounded,
            expand: true,
            onPressed: _error is InstallPermissionRequired ? _install : _check,
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
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (update.downloadSize > 0)
              Text(
                _size(update.downloadSize),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.current.muted),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          update.releaseNotes.trim().isEmpty
              ? 'A newer development build is ready.'
              : update.releaseNotes.trim(),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.current.muted),
        ),
        const SizedBox(height: 20),
        if (_progress != null) ...[
          LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 10),
          Text(
            _progress == null
                ? 'Downloading securely…'
                : 'Downloading · ${(_progress! * 100).round()}%',
            textAlign: TextAlign.center,
          ),
        ] else
          CurrentButton(
            label: _download == null
                ? 'Download and verify'
                : _installing
                ? 'Opening installer…'
                : 'Install verified update',
            icon: _download == null
                ? Icons.download_rounded
                : Icons.system_update_alt_rounded,
            expand: true,
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
  Widget build(BuildContext context) => Container(
    key: ValueKey(title),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.current.surface,
      border: Border.all(color: context.current.rule),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: context.current.intelligence),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                detail,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.current.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
