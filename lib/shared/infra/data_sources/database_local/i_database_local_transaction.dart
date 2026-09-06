import 'package:rallet/shared/infra/data_sources/database_local/database_operation.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_batch.dart';

typedef ActionTxn<T> = Future<T> Function(ITransactionExecutor txn);

abstract interface class IDatabaseLocalTransaction {
  Future<T> openTransaction<T>(ActionTxn<T> action);
}

/// Operações disponíveis dentro de uma transação SQLite.
///
/// O executor transacional não controla ciclo de vida do banco, backup ou
/// restore. Isso evita que uma transação implemente métodos que nunca podem ser
/// executados de forma válida.
abstract interface class ITransactionExecutor {
  IDatabaseLocalBatch batch();

  Future<int> insert(String table, Map<String, dynamic> values);

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  });

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  });

  Future<void> execute(String sql, [List<dynamic>? arguments]);

  Future<dynamic> raw(
    String sql,
    DatabaseOperation operation, [
    List<dynamic>? arguments,
  ]);

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });
}
