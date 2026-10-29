import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'env.dart';

/// Self-update for the sideloaded builds (APK and MChart-Setup.exe). Polls
/// GET /app/version; when the server has a newer release, the shell shows an
/// "Update" bar. Windows installs silently and relaunches; Android hands the
/// verified APK to the system installer (the user taps Install).
sealed class UpdateState {
  const UpdateState();
}

class UpToDate extends UpdateState {
  const UpToDate();
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release, {this.progress, this.error});
  final Release release;

  /// 0..1 while downloading, null otherwise.
  final double? progress;
  final String? error;
}

class Release {
  const Release(this.version, this.url, this.sha256);
  final String version;
  final String url;
  final String sha256;
}

class AppUpdater extends StateNotifier<UpdateState> {
  AppUpdater() : super(const UpToDate()) {
    if (!supported) return;
    unawaited(check());
    _timer = Timer.periodic(const Duration(hours: 3), (_) => check());
  }

  /// Passed by build-release.ps1 from pubspec.yaml; empty in `flutter run`,
  /// which keeps debug builds from offering to replace themselves.
  static const currentVersion = String.fromEnvironment('MCHART_VERSION');

  static const _channel = MethodChannel('mchart/updater');

  static bool get supported =>
      !kIsWeb &&
      currentVersion.isNotEmpty &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows);

  static String get _platformKey =>
      defaultTargetPlatform == TargetPlatform.android ? 'android' : 'windows';

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      headers: {'Accept': 'application/json'},
    ),
  );
  Timer? _timer;
  bool _busy = false;

  Future<void> check() async {
    if (_busy || state is UpdateAvailable) return;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${Env.apiV1}/app/version',
      );
      final data = res.data ?? const {};
      final version = data['version'] as String?;
      final file = data[_platformKey] as Map<String, dynamic>?;
      if (version == null || file == null) return;
      if (_compare(version, currentVersion) <= 0) return;
      if (!mounted) return;
      state = UpdateAvailable(
        Release(version, file['url'] as String, file['sha256'] as String),
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  Future<void> install() async {
    final current = state;
    if (current is! UpdateAvailable || _busy) return;
    final release = current.release;
    _busy = true;
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      await dir.create(recursive: true);
      final name = _platformKey == 'android'
          ? 'mchart.apk'
          : 'MChart-Setup.exe';
      final path = '${dir.path}/$name';

      state = UpdateAvailable(release, progress: 0);
      await _dio.download(
        release.url,
        path,
        onReceiveProgress: (got, total) {
          if (total > 0 && mounted) {
            state = UpdateAvailable(release, progress: got / total);
          }
        },
      );

      final digest = await sha256.bind(File(path).openRead()).first;
      if (digest.toString() != release.sha256.toLowerCase()) {
        await File(path).delete();
        throw 'Download was corrupted, try again.';
      }

      if (_platformKey == 'windows') {
        // The installer closes this app, upgrades in place and starts the
        // new version (mchart.iss runs it after a silent install).
        await Process.start(path, [
          '/SILENT',
          '/SUPPRESSMSGBOXES',
          '/NORESTART',
          '/CLOSEAPPLICATIONS',
        ], mode: ProcessStartMode.detached);
        exit(0);
      }

      final started = await _channel.invokeMethod<bool>('installApk', {
        'path': path,
      });
      state = UpdateAvailable(
        release,
        error: started == true
            ? null
            : 'Allow MChart to install apps, then tap Update again.',
      );
    } catch (e) {
      if (mounted) {
        state = UpdateAvailable(
          release,
          error: e is String ? e : 'Update failed: $e',
        );
      }
    } finally {
      _busy = false;
    }
  }

  /// Compares dotted versions numerically ("1.0.12" > "1.0.9").
  static int _compare(String a, String b) {
    List<int> parts(String v) =>
        v.split(RegExp(r'[.+]')).map((p) => int.tryParse(p) ?? 0).toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final appUpdaterProvider = StateNotifierProvider<AppUpdater, UpdateState>(
  (ref) => AppUpdater(),
);
