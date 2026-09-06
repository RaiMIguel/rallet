import 'dart:io';

import 'package:rallet/shared/infra/data_sources/database_local/database_operation.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_batch.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';

abstract interface class IDatabaseLocal {
  /// Cria um snapshot SQLite consistente e independente do banco ativo.
  Future<File> createDatabaseBackup(String destinationPath);

  /// Importa os dados de um backup validado para o banco atual.
  /// A sessão/autenticação do aparelho de destino é preservada.
  Future<void> restoreDatabaseBackup(File backupFile);

  Future<void> deleteFileDatabase();

  /// Troca a conexão local para o banco exclusivo do usuário autenticado no
  /// Firebase. O banco legado `rallet.db` é migrado somente quando pertence ao
  /// mesmo usuário, evitando mistura de dados entre contas.
  Future<void> switchToAuthenticatedUser();

  /// Fecha o banco do usuário atual e abre uma sessão local neutra para a tela
  /// de login. Os bancos de cada usuário permanecem preservados no aparelho.
  Future<void> switchToSignedOutSession();

  IDatabaseLocalBatch batch();

  IDatabaseLocalTransaction transactionInstance();

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
