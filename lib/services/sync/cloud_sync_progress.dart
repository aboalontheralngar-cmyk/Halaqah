/// Privacy-safe progress metadata for a cloud synchronization run.
///
/// The stage id/label are intentionally generic and never contain record ids,
/// names, phone numbers, URLs, tokens, or raw server messages.
enum CloudSyncProgressState { preparing, running, completed, failed }

class CloudSyncProgress {
  final CloudSyncProgressState state;
  final String stageId;
  final String stageLabel;
  final int currentStage;
  final int totalStages;
  final String? safeCode;

  const CloudSyncProgress({
    required this.state,
    required this.stageId,
    required this.stageLabel,
    required this.currentStage,
    required this.totalStages,
    this.safeCode,
  });

  double get fraction {
    if (totalStages <= 0) return 0;
    return (currentStage / totalStages).clamp(0, 1).toDouble();
  }
}

/// Wraps a failed synchronization stage without leaking raw cloud details into
/// user-facing error messages.
class CloudSyncStageException implements Exception {
  final String stageId;
  final String stageLabel;
  final String safeCode;
  final Object cause;

  const CloudSyncStageException({
    required this.stageId,
    required this.stageLabel,
    required this.safeCode,
    required this.cause,
  });

  @override
  String toString() => 'Cloud sync stage failed: $safeCode';
}
