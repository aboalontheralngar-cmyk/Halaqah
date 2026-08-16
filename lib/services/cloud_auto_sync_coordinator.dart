import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_logger.dart';
import 'backup_service.dart';
import 'database_service.dart';
import 'supabase_service.dart';
import 'sync/adaptive_retry_policy.dart';
import 'sync/cloud_sync_progress.dart';

/// Foreground offline-first synchronization coordinator.
///
/// Local SQLite remains the immediate source of truth. The coordinator performs
/// a bounded periodic sync only while the application is in the foreground.
/// A failed network attempt schedules a single adaptive retry rather than an
/// always-running connectivity probe, which reduces wakeups, radio use, and
/// duplicate cloud work on mobile devices.
class CloudAutoSyncCoordinator with WidgetsBindingObserver {
  CloudAutoSyncCoordinator._();

  static final CloudAutoSyncCoordinator instance = CloudAutoSyncCoordinator._();

  final DatabaseService _database = DatabaseService();
  final AdaptiveRetryPolicy _retryPolicy = AdaptiveRetryPolicy();

  Timer? _periodicTimer;
  Timer? _networkRetryTimer;
  StreamSubscription<dynamic>? _authSubscription;
  bool _running = false;
  bool _waitingForNetwork = false;
  bool _started = false;
  bool _foreground = true;
  bool _pausedForRecovery = false;
  DateTime? _lastAttempt;

  static const Duration retryInterval = Duration(minutes: 5);
  static const Duration minimumAttemptGap = Duration(seconds: 30);
  static const Duration recoveryGracePeriod = Duration(minutes: 15);

  void start() {
    if (!_started) {
      WidgetsBinding.instance.addObserver(this);
      _started = true;
    }

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycleState == null || lifecycleState == AppLifecycleState.resumed;

    _periodicTimer?.cancel();
    _networkRetryTimer?.cancel();
    _authSubscription?.cancel();
    _retryPolicy.reset();
    _waitingForNetwork = false;

    _startPeriodicTimer();
    _authSubscription = SupabaseService.instance.authStateChanges.listen((_) {
      if (_foreground && !_pausedForRecovery) {
        unawaited(syncNow(force: true));
      }
    });
    if (_foreground && !_pausedForRecovery) unawaited(syncNow());
  }

  void dispose() {
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
    _periodicTimer?.cancel();
    _networkRetryTimer?.cancel();
    _authSubscription?.cancel();
    _periodicTimer = null;
    _networkRetryTimer = null;
    _authSubscription = null;
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    if (!_foreground || _pausedForRecovery) return;
    _periodicTimer = Timer.periodic(
      retryInterval,
      (_) => unawaited(syncNow()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _startPeriodicTimer();
      if (!_pausedForRecovery) unawaited(syncNow(force: true));
      return;
    }

    // Avoid periodic work and connectivity wakeups while the application is
    // backgrounded. The next resume performs an immediate reconciliation.
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _networkRetryTimer?.cancel();
    _networkRetryTimer = null;
  }

  /// Stops automatic synchronization while a backup is being restored.
  ///
  /// We wait for an already-running synchronization to finish before the
  /// destructive local restore starts. There is intentionally no cancellation
  /// here because a Dart cancellation/timeout would not cancel the underlying
  /// PostgREST mutation safely.
  Future<void> pauseForRecovery() async {
    _pausedForRecovery = true;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _networkRetryTimer?.cancel();
    _networkRetryTimer = null;
    await SupabaseService.instance.waitForActiveSync();
  }

  /// Re-enables periodic scheduling after a restore. The normal recovery grace
  /// period prevents an immediate automatic cloud merge.
  void resumeAfterRecovery() {
    _pausedForRecovery = false;
    _waitingForNetwork = false;
    _networkRetryTimer?.cancel();
    _networkRetryTimer = null;
    _retryPolicy.reset();
    _startPeriodicTimer();
  }

  bool _isTransientConnectivityFailure(Object error) {
    final cause = error is CloudSyncStageException ? error.cause : error;
    if (cause is TimeoutException || cause is CloudSyncUnavailableException) {
      return true;
    }
    final text = cause.toString().toLowerCase();
    return text.contains('clientexception') ||
        text.contains('socketexception') ||
        text.contains('connection abort') ||
        text.contains('connection reset') ||
        text.contains('connection closed') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('timed out') ||
        text.contains('timeout');
  }

  void _scheduleNetworkRetry() {
    if (!_foreground || !_waitingForNetwork || _networkRetryTimer != null) {
      return;
    }
    final delay = _retryPolicy.takeNextDelay();
    _networkRetryTimer = Timer(delay, () {
      _networkRetryTimer = null;
      unawaited(_retryWhenNetworkReturns());
    });
  }

  Future<void> _retryWhenNetworkReturns() async {
    if (!_foreground ||
        !_waitingForNetwork ||
        _running ||
        !SupabaseService.instance.isAuthenticated) {
      return;
    }
    try {
      final diagnostic = await SupabaseService.instance.diagnoseConnection();
      if (!diagnostic.isHealthy) {
        _scheduleNetworkRetry();
        return;
      }
      await syncNow(force: true);
    } catch (_) {
      // The full sync path records privacy-safe diagnostics. This lightweight
      // probe only decides when another retry should be scheduled.
      _scheduleNetworkRetry();
    }
  }

  Future<void> syncNow({bool force = false}) async {
    if (_running || !_foreground || _pausedForRecovery) return;
    final now = DateTime.now();

    final lastRestore = DateTime.tryParse(
      await _database.getSetting('last_restore_at') ?? '',
    );
    if (lastRestore != null) {
      final age = now.difference(lastRestore);
      if (!age.isNegative && age < recoveryGracePeriod) {
        AppLogger.info(
          'automatic_sync_deferred:recent_restore',
          source: 'cloud.auto_sync',
        );
        return;
      }
    }
    if (!force &&
        _lastAttempt != null &&
        now.difference(_lastAttempt!) < minimumAttemptGap) {
      return;
    }
    _lastAttempt = now;

    final setup = await _database.getSetting('setup_completed');
    if (setup != 'true' || !SupabaseService.instance.isAuthenticated) return;
    final centerId = await _database.getSetting('sync_center_id');
    final halaqahId = await _database.getSetting('sync_halaqah_id');
    if ((centerId ?? '').isEmpty || (halaqahId ?? '').isEmpty) return;

    _running = true;
    try {
      // Download synchronization is intentionally protected by a pre-sync
      // backup. If the teacher has not configured a backup passphrase yet,
      // automatic sync must still upload local changes instead of repeatedly
      // failing at the backup stage. Manual bidirectional/download sync keeps
      // the stricter UI guard and asks for the passphrase first.
      final canProtectDownload = await BackupService().passphrases.isConfigured;
      final direction = canProtectDownload
          ? CloudSyncDirection.bidirectional
          : CloudSyncDirection.uploadOnly;
      if (!canProtectDownload) {
        AppLogger.info(
          'automatic_sync_upload_only:no_backup_passphrase',
          source: 'cloud.auto_sync',
        );
      }
      await SupabaseService.instance.synchronizeData(direction: direction);
      await _database.saveSetting(
        'last_automatic_cloud_sync_at',
        DateTime.now().toIso8601String(),
      );
      await _database.saveSetting(
        'last_automatic_cloud_sync_direction',
        direction.settingSuffix,
      );
      _waitingForNetwork = false;
      _networkRetryTimer?.cancel();
      _networkRetryTimer = null;
      _retryPolicy.reset();
    } catch (error) {
      // Local SQLite changes remain intact. Only transient connectivity errors
      // receive fast retries; schema/data errors wait for the normal foreground
      // cadence so a bad migration cannot drain battery in a retry loop.
      _waitingForNetwork = _isTransientConnectivityFailure(error);
      AppLogger.info(
        'automatic_sync_deferred:${error.runtimeType}',
        source: 'cloud.auto_sync',
      );
      if (_waitingForNetwork) _scheduleNetworkRetry();
    } finally {
      _running = false;
    }
  }
}
