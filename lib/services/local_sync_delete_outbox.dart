import 'package:sqflite/sqflite.dart';

/// A durable local delete waiting to be mirrored to Supabase.
///
/// The local row id is kept separately from the remote selector because a few
/// cloud tables use deterministic UUIDs/composite keys (attendance and mushaf
/// progress) instead of the SQLite row id.
class LocalSyncDeleteOperation {
  final int id;
  final String localTable;
  final String localId;
  final String remoteTable;
  final String? remoteId;
  final Map<String, String> remoteFilters;
  final int priority;

  const LocalSyncDeleteOperation({
    required this.id,
    required this.localTable,
    required this.localId,
    required this.remoteTable,
    required this.remoteId,
    required this.remoteFilters,
    required this.priority,
  });

  factory LocalSyncDeleteOperation.fromMap(Map<String, dynamic> row) {
    final filters = <String, String>{};
    for (var index = 1; index <= 3; index++) {
      final key = row['remote_key$index']?.toString();
      final value = row['remote_value$index']?.toString();
      if (key != null && key.isNotEmpty && value != null) {
        filters[key] = value;
      }
    }
    return LocalSyncDeleteOperation(
      id: (row['id'] as num).toInt(),
      localTable: row['local_table'].toString(),
      localId: row['local_id'].toString(),
      remoteTable: row['remote_table'].toString(),
      remoteId: row['remote_id']?.toString(),
      remoteFilters: filters,
      priority: (row['priority'] as num?)?.toInt() ?? 100,
    );
  }
}

class LocalSyncDeleteOutbox {
  const LocalSyncDeleteOutbox._();

  static Future<List<LocalSyncDeleteOperation>> pending(
    Database database, {
    int limit = 500,
  }) async {
    final rows = await database.query(
      'sync_delete_outbox',
      orderBy: 'priority ASC, id ASC',
      limit: limit,
    );
    return rows.map(LocalSyncDeleteOperation.fromMap).toList(growable: false);
  }

  /// A replace/update may internally emit a SQLite DELETE. If the same local
  /// row exists again by the time sync runs, it was not a real user deletion
  /// and the outbox row must be discarded without touching the cloud.
  static Future<bool> isStillDeleted(
    Database database,
    LocalSyncDeleteOperation operation,
  ) async {
    final rows = await database.query(
      operation.localTable,
      columns: const ['id'],
      where: 'id = ?',
      whereArgs: [operation.localId],
      limit: 1,
    );
    return rows.isEmpty;
  }

  static Future<void> acknowledge(Database database, int id) async {
    await database.delete(
      'sync_delete_outbox',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> count(Database database) async {
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_delete_outbox',
    );
    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }
}
