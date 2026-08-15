import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_logger.dart';
import 'database_service.dart';
import 'supabase_service.dart';

/// Foreground offline-first synchronization coordinator.
///
/// Local SQLite remains the immediate source of truth. When the application is
/// resumed, after authentication, and periodically while it is open, this
/// coordinator retries a bidirectional cloud sync. A network failure is kept
/// silent and retried later, so work entered offline is never blocked.
class CloudAutoSyncCoordinator with WidgetsBindingObserver {
  CloudAutoSyncCoordinator._();

  static final CloudAutoSyncCoordinator instance = CloudAutoSyncCoordinator._();

  final DatabaseService _database = DatabaseService();
  Timer? _timer;
  Timer? _networkProbeTimer;
  StreamSubscription<dynamic>? _authSubscription;
  bool _running = false;
  bool _waitingForNetwork = false;
  DateTime? _lastAttempt;

  static const Duration retryInterval = Duration(minutes: 2);
  static const Duration minimumAttemptGap = Duration(seconds: 30);
  static const Duration networkProbeInterval = Duration(seconds: 12);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer?.cancel();
    _networkProbeTimer?.cancel();
    _authSubscription?.cancel();
    _timer = Timer.periodic(retryInterval, (_) => unawaited(syncNow()));
    _networkProbeTimer = Timer.periodic(
      networkProbeInterval,
      (_) => unawaited(_retryWhenNetworkReturns()),
    );
    _authSubscription = SupabaseService.instance.authStateChanges.listen((_) {
      unawaited(syncNow(force: true));
    });
    unawaited(syncNow());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _networkProbeTimer?.cancel();
    _authSubscription?.cancel();
    _timer = null;
    _networkProbeTimer = null;
    _authSubscription = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncNow(force: true));
    }
  }

  Future<void> _retryWhenNetworkReturns() async {
    if (!_waitingForNetwork || _running || !SupabaseService.instance.isAuthenticated) {
      return;
    }
    try {
      final diagnostic = await SupabaseService.instance.diagnoseConnection();
      if (!diagnostic.isHealthy) return;
      await syncNow(force: true);
    } catch (_) {
      // This is only a lightweight recovery probe. The regular sync path logs
      // the actionable failure and retains all local data.
    }
  }

  Future<void> syncNow({bool force = false}) async {
    if (_running) return;
    final now = DateTime.now();
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
      await SupabaseService.instance.synchronizeData(
        direction: CloudSyncDirection.bidirectional,
      );
      await _database.saveSetting(
        'last_automatic_cloud_sync_at',
        DateTime.now().toIso8601String(),
      );
      _waitingForNetwork = false;
    } catch (error) {
      // Offline/temporary cloud failures are expected. SQLite changes remain
      // intact and the next foreground/resume tick retries automatically.
      _waitingForNetwork = true;
      AppLogger.info(
        'automatic_sync_deferred:${error.runtimeType}',
        source: 'cloud.auto_sync',
      );
    } finally {
      _running = false;
    }
  }
}
