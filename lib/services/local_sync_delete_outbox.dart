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

  /// Removes false delete markers produced by SQLite INSERT OR REPLACE in bulk.
  ///
  /// Build 80 checked every outbox row with a separate SQLite query. On an
  /// installation with thousands of historical updates this made the delete
  /// stage look stuck even though most rows represented records that still
  /// existed locally. One statement per local table is enough to discard those
  /// markers safely before any network request is made.
  static Future<int> pruneRowsThatStillExist(
    Database database,
    Iterable<LocalSyncDeleteOperation> operations,
  ) async {
    final tables = operations.map((operation) => operation.localTable).toSet();
    var removed = 0;
    await database.transaction((txn) async {
      for (final table in tables) {
        if (!_safeSqlIdentifier.hasMatch(table)) continue;
        final tableExists = await txn.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
          [table],
        );
        if (tableExists.isEmpty) continue;
        removed += await txn.rawDelete(
          'DELETE FROM sync_delete_outbox '
          'WHERE local_table = ? '
          'AND local_id IN (SELECT CAST(id AS TEXT) FROM "$table")',
          [table],
        );
      }
    });
    return removed;
  }

  static Future<void> acknowledge(Database database, int id) async {
    await database.delete(
      'sync_delete_outbox',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> acknowledgeMany(
    Database database,
    Iterable<int> operationIds,
  ) async {
    final ids = operationIds.toSet().toList(growable: false);
    if (ids.isEmpty) return;
    const chunkSize = 500;
    await database.transaction((txn) async {
      for (var start = 0; start < ids.length; start += chunkSize) {
        final end = start + chunkSize < ids.length
            ? start + chunkSize
            : ids.length;
        final chunk = ids.sublist(start, end);
        final placeholders = List.filled(chunk.length, '?').join(',');
        await txn.delete(
          'sync_delete_outbox',
          where: 'id IN ($placeholders)',
          whereArgs: chunk,
        );
      }
    });
  }

  static Future<int> count(Database database) async {
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_delete_outbox',
    );
    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }

  static final RegExp _safeSqlIdentifier = RegExp(r'^[A-Za-z0-9_]+$');
}
