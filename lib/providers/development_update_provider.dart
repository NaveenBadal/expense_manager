import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/development_update.dart';
import '../services/development_update_service.dart';

enum DevelopmentUpdatePhase {
  disabled,
  idle,
  checking,
  upToDate,
  available,
  downloading,
  ready,
  permissionRequired,
  error,
}

class DevelopmentUpdateState {
  const DevelopmentUpdateState({
    this.phase = DevelopmentUpdatePhase.idle,
    this.installedVersion,
    this.installedBuild,
    this.update,
    this.progress = 0,
    this.apkPath,
    this.message,
  });

  final DevelopmentUpdatePhase phase;
  final String? installedVersion;
  final int? installedBuild;
  final DevelopmentUpdate? update;
  final double progress;
  final String? apkPath;
  final String? message;
}

class DevelopmentUpdateNotifier extends Notifier<DevelopmentUpdateState> {
  late final DevelopmentUpdateService _service;

  @override
  DevelopmentUpdateState build() {
    _service = DevelopmentUpdateService();
    return _service.isSupported
        ? const DevelopmentUpdateState()
        : const DevelopmentUpdateState(phase: DevelopmentUpdatePhase.disabled);
  }

  Future<void> check({bool silent = false}) async {
    if (!_service.isSupported ||
        state.phase == DevelopmentUpdatePhase.checking) {
      return;
    }
    final previous = state;
    if (!silent) {
      state = DevelopmentUpdateState(
        phase: DevelopmentUpdatePhase.checking,
        installedVersion: previous.installedVersion,
        installedBuild: previous.installedBuild,
      );
    }
    try {
      final result = await _service.check();
      state = DevelopmentUpdateState(
        phase: result.update == null
            ? DevelopmentUpdatePhase.upToDate
            : DevelopmentUpdatePhase.available,
        installedVersion: result.installedVersion,
        installedBuild: result.installedBuild,
        update: result.update,
      );
    } catch (error) {
      if (!silent) {
        state = DevelopmentUpdateState(
          phase: DevelopmentUpdatePhase.error,
          installedVersion: previous.installedVersion,
          installedBuild: previous.installedBuild,
          message: _friendlyError(error),
        );
      }
    }
  }

  Future<void> download() async {
    final update = state.update;
    if (update == null || state.phase == DevelopmentUpdatePhase.downloading) {
      return;
    }
    state = DevelopmentUpdateState(
      phase: DevelopmentUpdatePhase.downloading,
      update: update,
      installedVersion: state.installedVersion,
      installedBuild: state.installedBuild,
    );
    try {
      final path = await _service.download(
        update,
        onProgress: (progress) {
          state = DevelopmentUpdateState(
            phase: DevelopmentUpdatePhase.downloading,
            update: update,
            progress: progress,
            installedVersion: state.installedVersion,
            installedBuild: state.installedBuild,
          );
        },
      );
      state = DevelopmentUpdateState(
        phase: DevelopmentUpdatePhase.ready,
        update: update,
        progress: 1,
        apkPath: path,
        installedVersion: state.installedVersion,
        installedBuild: state.installedBuild,
      );
    } catch (error) {
      state = DevelopmentUpdateState(
        phase: DevelopmentUpdatePhase.error,
        update: update,
        installedVersion: state.installedVersion,
        installedBuild: state.installedBuild,
        message: _friendlyError(error),
      );
    }
  }

  Future<void> install() async {
    final path = state.apkPath;
    if (path == null) return;
    if (!await _service.canRequestInstalls()) {
      state = DevelopmentUpdateState(
        phase: DevelopmentUpdatePhase.permissionRequired,
        update: state.update,
        apkPath: path,
        progress: 1,
        installedVersion: state.installedVersion,
        installedBuild: state.installedBuild,
      );
      await _service.openInstallPermission();
      return;
    }
    await _service.install(path);
  }

  String _friendlyError(Object error) {
    final text = '$error';
    if (text.contains('repository must be public')) {
      return 'The development release feed is private or unavailable.';
    }
    if (text.contains('manifest')) {
      return 'The latest GitHub release is missing valid update metadata.';
    }
    if (text.contains('match')) {
      return 'The download failed its security check and was removed.';
    }
    return 'Could not reach the development update channel.';
  }
}

final developmentUpdateProvider =
    NotifierProvider<DevelopmentUpdateNotifier, DevelopmentUpdateState>(
      DevelopmentUpdateNotifier.new,
    );
