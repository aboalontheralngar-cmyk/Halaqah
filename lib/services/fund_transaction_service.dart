import '../models/fund_transaction.dart';
import 'database_service.dart';

/// Owns mutable fund-transaction operations that do not belong in the large
/// cross-domain DatabaseService. Read/create APIs remain backward compatible,
/// while edits are isolated here to keep the database facade modular.
class FundTransactionService {
  FundTransactionService({DatabaseService? database})
      : _database = database ?? DatabaseService();

  final DatabaseService _database;

  Future<void> update(FundTransaction transaction) async {
    if (transaction.amount <= 0) {
      throw ArgumentError('يجب أن يكون مبلغ المعاملة أكبر من صفر');
    }
    final db = await _database.database;
    final updated = await db.update(
      'fund_transactions',
      <String, dynamic>{
        'amount': transaction.amount,
        'note': transaction.note,
        'date': _dateKey(transaction.date),
      },
      where: 'id = ?',
      whereArgs: <Object?>[transaction.id],
    );
    if (updated != 1) {
      throw StateError('تعذر العثور على المعاملة المالية لتحديثها');
    }
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
