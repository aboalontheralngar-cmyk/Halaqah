/// Pure diff used by cloud sync to avoid replaying every historical study
/// suspension through the RPC on every synchronization.
class StudySuspensionSyncPlan {
  final List<String> datesToRemove;
  final Map<String, String> suspensionsToSet;
  final Map<String, String> mergedRemoteState;

  const StudySuspensionSyncPlan._({
    required this.datesToRemove,
    required this.suspensionsToSet,
    required this.mergedRemoteState,
  });

  factory StudySuspensionSyncPlan.create({
    required Map<String, String> local,
    required Map<String, String> remote,
    required Set<String> pendingDeletedDates,
  }) {
    final merged = Map<String, String>.from(remote);
    final removals = <String>[];
    final updates = <String, String>{};

    final orderedDeletedDates = pendingDeletedDates.toList()..sort();
    for (final date in orderedDeletedDates) {
      // If a date was removed then re-added before sync, the current local
      // state wins and the stale deletion marker can simply be acknowledged.
      if (local.containsKey(date)) continue;
      if (merged.containsKey(date)) {
        removals.add(date);
        merged.remove(date);
      }
    }

    final orderedLocalEntries = local.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    for (final entry in orderedLocalEntries) {
      final localReason = entry.value.trim();
      final remoteReason = merged[entry.key]?.trim();
      if (remoteReason != localReason) {
        updates[entry.key] = localReason;
        merged[entry.key] = localReason;
      }
    }

    return StudySuspensionSyncPlan._(
      datesToRemove: List<String>.unmodifiable(removals),
      suspensionsToSet: Map<String, String>.unmodifiable(updates),
      mergedRemoteState: Map<String, String>.unmodifiable(merged),
    );
  }
}
