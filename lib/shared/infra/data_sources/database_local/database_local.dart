import 'dart:io';

import 'package:rallet/features/account/infra/data_sources/account_local_data_source.dart';
import 'package:rallet/features/auth/infra/data_sources/auth_local_data_source.dart';
import 'package:rallet/features/card_cash_advance/infra/data_sources/card_cash_advance_local_data_source.dart';
import 'package:rallet/features/category/infra/data_sources/category_local_data_source.dart';
import 'package:rallet/features/credit_card/infra/data_sources/credit_card_bill_local_data_source.dart';
import 'package:rallet/features/credit_card/infra/data_sources/credit_card_local_data_source.dart';
import 'package:rallet/features/credit_card/infra/data_sources/credit_card_transaction_local_data_source.dart';
import 'package:rallet/features/credit_card/infra/data_sources/i_credit_card_bill_local_data_source.dart';
import 'package:rallet/features/first_steps/infra/data_sources/first_steps_local_data_source.dart';
import 'package:rallet/features/purchase_planning/infra/data_sources/purchase_planning_local_data_source.dart';
import 'package:rallet/features/statement/infra/data_sources/statement_local_data_source.dart';
import 'package:rallet/features/transactions/infra/data_sources/expense_local_data_source.dart';
import 'package:rallet/features/transactions/infra/data_sources/income_local_data_source.dart';
import 'package:rallet/features/transactions/infra/data_sources/transfer_local_data_source.dart';
import 'package:rallet/features/user_account/infra/data_sources/user_account_local_data_source.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/infra/data_sources/database_local/database_local_batch.dart';
import 'package:rallet/shared/infra/data_sources/database_local/database_local_exception.dart';
import 'package:rallet/shared/infra/data_sources/database_local/database_local_transaction.dart';
import 'package:rallet/shared/infra/data_sources/database_local/database_operation.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_batch.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

final class DatabaseLocal implements IDatabaseLocal {
  static const String _legacyDatabaseName = 'rallet.db';

  String? _activeUserId;

  String get _name => _activeUserId == null
      ? _legacyDatabaseName
      : 'rallet_${_safeUserId(_activeUserId!)}.db';

  int get _version => 17;

  // Backups portáteis anteriores ao schema 9 não fazem parte do contrato
  // validado do Rallet. As migrações suportadas para restore são 9 -> 17.
  static const int _minimumPortableBackupVersion = 9;

  late Database database;

  static DatabaseLocal? _instance;

  DatabaseLocal._() : _activeUserId = _currentFirebaseUserId();

  static Future<DatabaseLocal> getInstance() async {
    if (_instance != null) {
      if (!_instance!.database.isOpen) {
        await _instance!._loadDatabase();
      }
      return _instance!;
    }

    _instance = DatabaseLocal._();

    try {
      await _instance!._migrateLegacyDatabaseIfNeeded();
      await _instance!._loadDatabase();
      return _instance!;
    } catch (_) {
      _instance = null;
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (database.isOpen) {
      await database.close();
    }
    _instance = null;
  }

  static const Set<String> _portableBackupExcludedTables = {
    'android_metadata',
    // A sessão e a identidade Firebase pertencem ao aparelho que está usando
    // o app. O restore substitui somente os dados locais portáteis.
    'auth',
    'user_account',
  };

  @override
  Future<File> createDatabaseBackup(String destinationPath) async {
    final File destination = File(destinationPath);
    await destination.parent.create(recursive: true);
    await _deleteDatabaseFileAndSidecars(destination.path);

    // A leitura inteira ocorre dentro de uma única transação, portanto todas
    // as tabelas pertencem ao mesmo instante lógico do banco.
    final Map<String, List<Map<String, Object?>>> sourceData =
        await database.transaction((txn) => _readPortableData(txn));

    Database? backupDatabase;
    try {
      backupDatabase = await openDatabase(
        destination.path,
        version: _version,
        onCreate: _onCreate,
        singleInstance: false,
      );

      await _replacePortableData(
        target: backupDatabase,
        sourceData: sourceData,
      );
      await _assertDatabaseMatchesData(backupDatabase, sourceData);
    } catch (_) {
      if (backupDatabase != null && backupDatabase.isOpen) {
        await backupDatabase.close();
      }
      await _deleteDatabaseFileAndSidecars(destination.path);
      rethrow;
    }

    if (backupDatabase.isOpen) {
      await backupDatabase.close();
    }

    // Validação final usando uma nova conexão, exatamente sobre o arquivo que
    // será compartilhado com o usuário.
    await _inspectDatabaseFile(destination, validateRalletDatabase: true);
    return destination;
  }

  @override
  Future<void> restoreDatabaseBackup(File backupFile) async {
    final _DatabaseBackupSnapshot sourceSnapshot =
        await _inspectDatabaseFile(backupFile, validateRalletDatabase: true);

    final String databasePath = await _getPath();
    final File stagedRestore = File('$databasePath.restore_import');
    await _deleteDatabaseFileAndSidecars(stagedRestore.path);

    // Copiar primeiro desacopla o restore do DocumentProvider/FilePicker do
    // Android. Depois daqui o arquivo selecionado pode até ser temporário.
    await backupFile.copy(stagedRestore.path);

    Map<String, List<Map<String, Object?>>>? previousData;
    bool targetChanged = false;

    try {
      final _DatabaseBackupSnapshot stagedSnapshot =
          await _inspectDatabaseFile(stagedRestore, validateRalletDatabase: true);
      _assertSameBackupContent(sourceSnapshot, stagedSnapshot);

      if (stagedSnapshot.version < _version) {
        final Database migrationDatabase = await openDatabase(
          stagedRestore.path,
          version: _version,
          onUpgrade: _onUpgrade,
          singleInstance: false,
        );
        await migrationDatabase.close();
      }

      final _DatabaseBackupSnapshot migratedSnapshot =
          await _inspectDatabaseFile(stagedRestore, validateRalletDatabase: true);
      if (migratedSnapshot.version != _version) {
        throw FormatException(
          'Schema do backup após migração: ${migratedSnapshot.version}; '
          'esperado: $_version.',
        );
      }

      Database? sourceDatabase;
      late final Map<String, List<Map<String, Object?>>> sourceData;
      try {
        sourceDatabase = await openDatabase(
          stagedRestore.path,
          readOnly: true,
          singleInstance: false,
        );
        sourceData = await _readPortableData(sourceDatabase);
      } finally {
        if (sourceDatabase != null && sourceDatabase.isOpen) {
          await sourceDatabase.close();
        }
      }

      // Mantemos uma imagem lógica do banco anterior. A transação já protege
      // contra falhas durante delete/insert; esta cópia permite reverter também
      // se uma validação posterior ao COMMIT falhar.
      previousData = await database.transaction((txn) => _readPortableData(txn));

      debugPrint(
        'Rallet restore selecionado: ${_rowCountsFromData(sourceData)}',
      );

      await _replacePortableData(
        target: database,
        sourceData: sourceData,
      );
      targetChanged = true;

      await _assertDatabaseMatchesData(database, sourceData);
      await _checkpointDatabase(database);

      // Prova adicional: abre outra conexão sobre o arquivo real do aplicativo.
      // Um restore só é considerado concluído se essa conexão independente
      // enxergar os mesmos totais que o backup selecionado.
      Database? diskDatabase;
      try {
        diskDatabase = await openDatabase(
          databasePath,
          readOnly: true,
          singleInstance: false,
        );
        await _assertDatabaseMatchesData(diskDatabase, sourceData);
      } finally {
        if (diskDatabase != null && diskDatabase.isOpen) {
          await diskDatabase.close();
        }
      }

      debugPrint(
        'Rallet restore concluído: ${_rowCountsFromData(sourceData)}',
      );
    } catch (_) {
      if (targetChanged && previousData != null) {
        try {
          await _replacePortableData(
            target: database,
            sourceData: previousData,
          );
          await _checkpointDatabase(database);
        } catch (rollbackError, rollbackStackTrace) {
          debugPrint('Rallet: falha ao reverter restore: $rollbackError');
          debugPrintStack(stackTrace: rollbackStackTrace);
        }
      }
      rethrow;
    } finally {
      await _deleteDatabaseFileAndSidecars(stagedRestore.path);
    }
  }

  @override
  Future<void> deleteFileDatabase() async {
    if (database.isOpen) {
      await _checkpointDatabase(database);
      await database.close();
    }

    final String path = await _getPath();
    await _deleteDatabaseFileAndSidecars(path);
    await _loadDatabase();
  }

  Future<void> _checkpointDatabase(Database target) async {
    if (!target.isOpen) return;

    try {
      await target.rawQuery('PRAGMA wal_checkpoint(FULL);');
    } catch (_) {
      // journal_mode=DELETE não necessita de checkpoint WAL.
    }
  }

  Future<void> _deleteDatabaseSidecars(String databasePath) async {
    for (final String suffix in const ['-wal', '-shm', '-journal']) {
      final File sidecar = File('$databasePath$suffix');
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }
  }

  Future<void> _deleteDatabaseFileAndSidecars(String databasePath) async {
    await _deleteDatabaseSidecars(databasePath);
    final File file = File(databasePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<String>> _portableTableNames(DatabaseExecutor executor) async {
    final List<Map<String, Object?>> rows = await executor.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name;",
    );

    return rows
        .map((row) => row['name']?.toString())
        .whereType<String>()
        .where((name) => !_portableBackupExcludedTables.contains(name))
        .toList(growable: false);
  }

  Future<Map<String, List<Map<String, Object?>>>> _readPortableData(
    DatabaseExecutor executor,
  ) async {
    final List<String> tables = await _portableTableNames(executor);
    final Map<String, List<Map<String, Object?>>> result = {};

    for (final String table in tables) {
      final List<Map<String, Object?>> rows = await executor.query(table);
      result[table] = rows
          .map((row) => Map<String, Object?>.from(row))
          .toList(growable: false);
    }

    return result;
  }

  Future<void> _replacePortableData({
    required Database target,
    required Map<String, List<Map<String, Object?>>> sourceData,
  }) async {
    final List<Map<String, Object?>> foreignKeyRows =
        await target.rawQuery('PRAGMA foreign_keys;');
    final Object? rawForeignKeys =
        foreignKeyRows.isEmpty ? null : foreignKeyRows.first.values.first;
    final bool foreignKeysWereEnabled =
        rawForeignKeys == 1 || rawForeignKeys?.toString() == '1';

    if (foreignKeysWereEnabled) {
      await target.execute('PRAGMA foreign_keys = OFF;');
    }

    try {
      await target.transaction((txn) async {
        final Set<String> targetTables =
            (await _portableTableNames(txn)).toSet();

        for (final String sourceTable in sourceData.keys) {
          if (!targetTables.contains(sourceTable)) {
            throw FormatException(
              'Tabela do backup não existe no banco atual: $sourceTable.',
            );
          }
        }

        final Batch batch = txn.batch();

        // Limpa inclusive tabelas que estão vazias no backup, evitando mistura
        // de dados do aparelho de destino com os dados restaurados.
        for (final String table in targetTables) {
          batch.delete(table);
        }

        for (final MapEntry<String, List<Map<String, Object?>>> entry
            in sourceData.entries) {
          for (final Map<String, Object?> row in entry.value) {
            batch.insert(entry.key, row);
          }
        }

        await batch.commit(noResult: true);
        await _assertDatabaseMatchesData(txn, sourceData);
      });
    } finally {
      if (foreignKeysWereEnabled) {
        await target.execute('PRAGMA foreign_keys = ON;');
      }
    }
  }

  Map<String, int> _rowCountsFromData(
    Map<String, List<Map<String, Object?>>> data,
  ) {
    return {
      for (final MapEntry<String, List<Map<String, Object?>>> entry
          in data.entries)
        entry.key: entry.value.length,
    };
  }

  Future<void> _assertDatabaseMatchesData(
    DatabaseExecutor executor,
    Map<String, List<Map<String, Object?>>> expectedData,
  ) async {
    final Set<String> tables = (await _portableTableNames(executor)).toSet();

    for (final MapEntry<String, List<Map<String, Object?>>> entry
        in expectedData.entries) {
      if (!tables.contains(entry.key)) {
        throw FormatException('Tabela ausente após restore: ${entry.key}.');
      }

      final List<Map<String, Object?>> rows = await executor.rawQuery(
        'SELECT COUNT(*) AS total FROM "${entry.key}";',
      );
      final Object? rawCount = rows.isEmpty ? null : rows.first['total'];
      final int count = rawCount is int
          ? rawCount
          : int.tryParse(rawCount?.toString() ?? '') ?? -1;

      if (count != entry.value.length) {
        throw FormatException(
          'Restore incompleto em ${entry.key}: '
          'esperado ${entry.value.length}, encontrado $count.',
        );
      }
    }

    final List<Map<String, Object?>> integrityRows =
        await executor.rawQuery('PRAGMA integrity_check;');
    final String integrity = integrityRows.isEmpty
        ? ''
        : integrityRows.first.values.first.toString().toLowerCase();
    if (integrity != 'ok') {
      throw const FormatException('O banco SQLite não passou na integridade.');
    }

    final List<Map<String, Object?>> foreignKeyViolations =
        await executor.rawQuery('PRAGMA foreign_key_check;');
    if (foreignKeyViolations.isNotEmpty) {
      throw FormatException(
        'O banco possui referência inválida entre tabelas: '
        '${foreignKeyViolations.first}.',
      );
    }
  }

  Future<_DatabaseBackupSnapshot> _inspectDatabaseFile(
    File file, {
    required bool validateRalletDatabase,
  }) async {
    if (!await file.exists() || await file.length() < 100) {
      throw const FormatException('Arquivo de backup inválido.');
    }

    Database? inspectedDatabase;
    try {
      inspectedDatabase = await openDatabase(
        file.path,
        readOnly: true,
        singleInstance: false,
      );

      final List<Map<String, Object?>> integrityRows =
          await inspectedDatabase.rawQuery('PRAGMA integrity_check;');
      final String integrity = integrityRows.isEmpty
          ? ''
          : integrityRows.first.values.first.toString().toLowerCase();
      if (integrity != 'ok') {
        throw const FormatException('O backup SQLite está corrompido.');
      }

      final List<Map<String, Object?>> versionRows =
          await inspectedDatabase.rawQuery('PRAGMA user_version;');
      final Object? rawVersion =
          versionRows.isEmpty ? null : versionRows.first.values.first;
      final int version = rawVersion is int
          ? rawVersion
          : int.tryParse(rawVersion?.toString() ?? '') ?? 0;

      if (version < _minimumPortableBackupVersion || version > _version) {
        throw FormatException(
          'Versão de banco incompatível para restore: $version. '
          'Versões suportadas: $_minimumPortableBackupVersion até $_version.',
        );
      }

      final Set<String> tableNames =
          (await _portableTableNames(inspectedDatabase)).toSet();
      const Set<String> requiredTables = {'accounts', 'expenses', 'incomes'};
      if (validateRalletDatabase && !requiredTables.every(tableNames.contains)) {
        throw const FormatException('O arquivo não é um backup do Rallet.');
      }

      final Map<String, int> rowCounts = {};
      for (final String table in tableNames) {
        final List<Map<String, Object?>> countRows = await inspectedDatabase
            .rawQuery('SELECT COUNT(*) AS total FROM "$table";');
        final Object? rawCount =
            countRows.isEmpty ? null : countRows.first['total'];
        rowCounts[table] = rawCount is int
            ? rawCount
            : int.tryParse(rawCount?.toString() ?? '') ?? 0;
      }

      return _DatabaseBackupSnapshot(
        version: version,
        length: await file.length(),
        rowCounts: rowCounts,
      );
    } on DatabaseException {
      throw const FormatException('Arquivo de backup SQLite inválido.');
    } finally {
      if (inspectedDatabase != null && inspectedDatabase.isOpen) {
        await inspectedDatabase.close();
      }
    }
  }

  void _assertSameBackupContent(
    _DatabaseBackupSnapshot source,
    _DatabaseBackupSnapshot copy,
  ) {
    if (source.version != copy.version || source.length != copy.length) {
      throw const FormatException('A cópia temporária do backup ficou inválida.');
    }

    for (final MapEntry<String, int> entry in source.rowCounts.entries) {
      if (copy.rowCounts[entry.key] != entry.value) {
        throw FormatException(
          'A cópia do backup divergiu em ${entry.key}.',
        );
      }
    }
  }

  Future<void> _loadDatabase() async {
    database = await openDatabase(
      await _getPath(),
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final IDatabaseLocalBatch batch = DatabaseLocalBatch(database: db);

    CategoryLocalDataSource(databaseLocal: this).createTable(batch);
    AccountLocalDataSource(databaseLocal: this).createTable(batch);
    StatementLocalDataSource(databaseLocal: this).createTable(batch);
    ExpenseLocalDataSource(databaseLocal: this).createTable(batch);
    IncomeLocalDataSource(databaseLocal: this).createTable(batch);
    TransferLocalDataSource(databaseLocal: this).createTable(batch);
    final CreditCardTransactionLocalDataSource creditCardTransactionLocalDataSource = CreditCardTransactionLocalDataSource(databaseLocal: this)..createTable(batch);
    final ICreditCardBillLocalDataSource creditCardBillLocalDataSource = CreditCardBillLocalDataSource(databaseLocal: this, creditCardTransactionLocalDataSource: creditCardTransactionLocalDataSource)..createTable(batch);
    CreditCardLocalDataSource(databaseLocal: this, creditCardBillLocalDataSource: creditCardBillLocalDataSource).createTable(batch);
    CardCashAdvanceLocalDataSource(databaseLocal: this).createTable(batch);
    PurchasePlanningLocalDataSource(databaseLocal: this).createTable(batch);
    AuthLocalDataSource(databaseLocal: this).createTable(batch);
    UserAccountLocalDataSource(databaseLocal: this).createTable(batch);
    FirstStepsLocalDataSource(databaseLocal: this).createTable(batch);

    await batch.commit();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final IDatabaseLocalBatch batch = DatabaseLocalBatch(database: db);

    if (oldVersion < 2) {
      batch.execute('''
        CREATE TABLE first_steps (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          deleted_at TEXT,
          account_step_done INTEGER NOT NULL DEFAULT 0,
          credit_card_step_done INTEGER NOT NULL DEFAULT 0,
          income_step_done INTEGER NOT NULL DEFAULT 0,
          expense_step_done INTEGER NOT NULL DEFAULT 0
        );
      ''');

      batch.insert('first_steps', {
        'id': const Uuid().v1(),
        'created_at': DateTime.now().toIso8601String(),
        'account_step_done': 1,
        'credit_card_step_done': 1,
        'income_step_done': 1,
        'expense_step_done': 1,
      });
    }

    if (oldVersion < 3) {
      final result = await db.rawQuery('''
        SELECT
          credit_card_transactions.id AS credit_card_transactions_id,
          credit_card_transactions.created_at AS credit_card_transactions_created_at,
          credit_card_transactions.deleted_at AS credit_card_transactions_deleted_at,
          credit_card_transactions.description AS credit_card_transactions_description,
          credit_card_transactions.amount AS credit_card_transactions_amount,
          credit_card_transactions.date AS credit_card_transactions_date,
          credit_card_transactions.id_category AS credit_card_transactions_id_category,
          credit_card_transactions.id_credit_card AS credit_card_transactions_id_credit_card,
          credit_card_transactions.id_credit_card_bill AS credit_card_transactions_id_credit_card_bill,
          credit_card_transactions.observation AS credit_card_transactions_observation
        FROM credit_card_transactions
        INNER JOIN credit_card_bills
          ON credit_card_bills.id = credit_card_transactions.id_credit_card_bill
        WHERE 
          credit_card_bills.paid = 1 AND
          credit_card_transactions.amount > 0 AND
          credit_card_transactions.deleted_at IS NULL AND
          credit_card_bills.deleted_at IS NULL;
      ''');

      if (result.isNotEmpty) {
        batch.execute(
          '''
            UPDATE expenses
            SET deleted_at = ?
            WHERE id_credit_card_transaction IN (${result.map((e) => '?').join(',')});
          ''',
          [DateTime.now().toIso8601String(), ...result.map((e) => e['credit_card_transactions_id'])],
        );

        batch.execute(
          '''
            UPDATE transactions
            SET deleted_at = ?
            WHERE id IN (
                SELECT id_transaction 
                FROM expenses
                WHERE id_credit_card_transaction IN (${result.map((e) => '?').join(',')})
            );
          ''',
          [DateTime.now().toIso8601String(), ...result.map((e) => e['credit_card_transactions_id'])],
        );

        final billPayments = await db.rawQuery('''
          SELECT
            credit_card_transactions.id AS credit_card_transactions_id,
            credit_card_transactions.created_at AS credit_card_transactions_created_at,
            credit_card_transactions.deleted_at AS credit_card_transactions_deleted_at,
            credit_card_transactions.description AS credit_card_transactions_description,
            credit_card_transactions.amount AS credit_card_transactions_amount,
            credit_card_transactions.date AS credit_card_transactions_date,
            credit_card_transactions.id_category AS credit_card_transactions_id_category,
            credit_card_transactions.id_credit_card AS credit_card_transactions_id_credit_card,
            credit_card_transactions.id_credit_card_bill AS credit_card_transactions_id_credit_card_bill,
            credit_card_transactions.observation AS credit_card_transactions_observation,
            account.id_account AS id_account
          FROM credit_card_transactions
          INNER JOIN credit_card_bills
            ON credit_card_bills.id = credit_card_transactions.id_credit_card_bill
          INNER JOIN credit_cards
            ON credit_cards.id = credit_card_bills.id_credit_card
          INNER JOIN (
              SELECT 
                id_account, 
                id_credit_card_bill
              FROM expenses
              INNER JOIN credit_card_transactions
                ON expenses.id_credit_card_transaction = credit_card_transactions.id
              INNER JOIN transactions
                ON expenses.id_transaction = transactions.id
              GROUP BY credit_card_transactions.id_credit_card_bill
          ) AS account
            ON account.id_credit_card_bill = credit_card_bills.id
          WHERE
            credit_card_bills.paid = 1 AND
            credit_card_transactions.amount < 0 AND
            credit_card_transactions.deleted_at IS NULL AND
            credit_card_bills.deleted_at IS NULL AND
            NOT EXISTS (
              SELECT 1
              FROM expenses
              WHERE expenses.id_credit_card_transaction = credit_card_transactions.id
            );
        ''');

        for (final billPayment in billPayments) {
          final idTransaction = const Uuid().v1();
          final createdAt = DateTime.now().toIso8601String();

          batch.execute(
            '''
              INSERT INTO expenses (id, created_at, description, id_category, id_credit_card_transaction, id_transaction, observation)
              VALUES (?, ?, ?, ?, ?, ?, ?);
            ''',
            [
              const Uuid().v1(),
              createdAt,
              billPayment['credit_card_transactions_description'],
              billPayment['credit_card_transactions_id_category'],
              billPayment['credit_card_transactions_id'],
              idTransaction,
              billPayment['credit_card_transactions_observation'],
            ],
          );

          batch.execute(
            '''
              INSERT INTO transactions (id, created_at, amount, type, date, id_account)
              VALUES (?, ?, ?, ?, ?, ?);
            ''',
            [
              idTransaction,
              createdAt,
              billPayment['credit_card_transactions_amount'],
              1,
              billPayment['credit_card_transactions_date'],
              billPayment['id_account'],
            ],
          );
        }

        batch.execute('ALTER TABLE credit_card_bills DROP COLUMN paid;');

        batch.execute('''
          CREATE TABLE statements (
            id TEXT NOT NULL PRIMARY KEY,
            created_at TEXT NOT NULL,
            deleted_at TEXT,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            id_account TEXT NOT NULL REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            id_expense TEXT REFERENCES expenses(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            id_income TEXT REFERENCES incomes(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            id_transfer TEXT REFERENCES transfers(id) ON UPDATE CASCADE ON DELETE RESTRICT
          );
        ''');

        batch.execute('''
          INSERT INTO statements (id, created_at, deleted_at, amount, date, id_account, id_expense, id_income, id_transfer)
            SELECT
              transactions.id,
              transactions.created_at,
              transactions.deleted_at,
              transactions.amount,
              transactions.date,
              transactions.id_account,
              expenses.id,
              incomes.id,
              COALESCE(transfers_from.id, transfers_to.id)
            FROM transactions
            LEFT JOIN expenses
              ON transactions.id = expenses.id_transaction
            LEFT JOIN incomes
              ON transactions.id = incomes.id_transaction
            LEFT JOIN transfers AS transfers_from
              ON transactions.id = transfers_from.id_transaction_from
            LEFT JOIN transfers AS transfers_to
              ON transactions.id = transfers_to.id_transaction_to;
        ''');

        batch.execute('ALTER TABLE expenses ADD COLUMN paid INTEGER NOT NULL DEFAULT 1;');
        batch.execute('ALTER TABLE incomes ADD COLUMN received INTEGER NOT NULL DEFAULT 1;');

        batch.execute('''
          CREATE TABLE expenses_new (
            id TEXT NOT NULL PRIMARY KEY,
            created_at TEXT NOT NULL,
            deleted_at TEXT,
            description TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            paid INTEGER NOT NULL DEFAULT 1,
            id_account TEXT NOT NULL REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            id_category TEXT NOT NULL REFERENCES categories(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            id_credit_card TEXT REFERENCES credit_cards(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            id_credit_card_transaction TEXT REFERENCES credit_card_transactions(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            observation TEXT
          );
        ''');

        batch.execute('''
          INSERT INTO expenses_new (id, created_at, deleted_at, description, amount, date, paid, id_account, id_category, id_credit_card, id_credit_card_transaction, observation)
            SELECT
              expenses.id,
              expenses.created_at,
              expenses.deleted_at,
              expenses.description,
              transactions.amount,
              transactions.date,
              1,
              transactions.id_account,
              expenses.id_category,
              credit_card_transactions.id_credit_card,
              credit_card_transactions.id,
              expenses.observation
            FROM expenses
            INNER JOIN transactions
              ON expenses.id_transaction = transactions.id
            LEFT JOIN credit_card_transactions
              ON expenses.id_credit_card_transaction = credit_card_transactions.id;
        ''');

        batch.execute('''
          CREATE TABLE incomes_new (
            id TEXT NOT NULL PRIMARY KEY,
            created_at TEXT NOT NULL,
            deleted_at TEXT,
            description TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            received INTEGER NOT NULL DEFAULT 1,
            id_account TEXT NOT NULL REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            id_category TEXT NOT NULL REFERENCES categories(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            observation TEXT
          );
        ''');

        batch.execute('''
          INSERT INTO incomes_new (id, created_at, deleted_at, description, amount, date, received, id_account, id_category, observation)
            SELECT
              incomes.id,
              incomes.created_at,
              incomes.deleted_at,
              incomes.description,
              transactions.amount,
              transactions.date,
              1,
              transactions.id_account,
              incomes.id_category,
              incomes.observation
            FROM incomes
            INNER JOIN transactions
              ON incomes.id_transaction = transactions.id;
        ''');

        batch.execute('''
          CREATE TABLE transfers_mew (
            id TEXT NOT NULL PRIMARY KEY,
            created_at TEXT NOT NULL,
            deleted_at TEXT,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            id_account_from TEXT NOT NULL REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE CASCADE,
            id_account_to TEXT NOT NULL REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE CASCADE
          );
        ''');

        batch.execute('''
          INSERT INTO transfers_mew (id, created_at, deleted_at, amount, date, id_account_from, id_account_to)
            SELECT
              transfers.id,
              transfers.created_at,
              transfers.deleted_at,
              transactions_to.amount,
              transactions_to.date,
              transactions_from.id_account,
              transactions_to.id_account
            FROM transfers
            INNER JOIN transactions transactions_from
              ON transfers.id_transaction_from = transactions_from.id
            INNER JOIN transactions transactions_to
              ON transfers.id_transaction_to = transactions_to.id;
        ''');

        batch.execute('DROP TABLE transactions;');

        batch.execute('DROP TABLE expenses;');
        batch.execute('ALTER TABLE expenses_new RENAME TO expenses;');

        batch.execute('DROP TABLE incomes;');
        batch.execute('ALTER TABLE incomes_new RENAME TO incomes;');

        batch.execute('DROP TABLE transfers;');
        batch.execute('ALTER TABLE transfers_mew RENAME TO transfers;');

        batch.execute('''
          INSERT INTO categories (id, created_at, deleted_at, description, type, color, icon)
          VALUES ('00000000-0000-0000-0000-000000000002', ?, ?, ?, 1, 'FF46A66C', ?);
        ''', [DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), R.strings.creditCard, Icons.credit_score_outlined.codePoint]);

        batch.execute('''
          UPDATE expenses
          SET id_category = '00000000-0000-0000-0000-000000000002'
          WHERE 
            id_credit_card_transaction IS NOT NULL AND
            deleted_at IS NULL;
        ''');
      }
    }

    if (oldVersion < 9) {
      final List<Map<String, dynamic>> bills = await db.rawQuery('''
        SELECT
          credit_card_bills.id,
          ROUND(SUM(credit_card_transactions.amount), 2) AS total_amount
        FROM credit_card_bills
        LEFT JOIN credit_card_transactions
          ON credit_card_bills.id = credit_card_transactions.id_credit_card_bill AND credit_card_transactions.deleted_at IS NULL
        GROUP BY credit_card_bills.id
        HAVING ABS(ROUND(SUM(credit_card_transactions.amount), 2)) = 0.01;
      ''');

      for (final bill in bills) {
        final List<Map<String, dynamic>> transactions = await db.rawQuery('''
          SELECT
            id,
            amount
          FROM credit_card_transactions
          WHERE
            id_credit_card_bill = ? AND
            deleted_at IS NULL AND
            credit_card_transactions.amount < 0;
        ''', [bill['id']]);

        if (transactions.isNotEmpty) {
          final double amountTransaction = transactions.first['amount'] ?? 0.0;
          final double totalAmountBill = bill['total_amount'] ?? 0.0;
          final double newAmount = (amountTransaction - totalAmountBill).truncateFractionalDigits(2);

          final List<Map<String, dynamic>> expense = await db.rawQuery('''
            SELECT id
            FROM expenses
            WHERE id_credit_card_transaction = ?;
          ''', [transactions.first['id']]);

          await db.transaction((txn) async {
            if (expense.isNotEmpty) {
              await txn.update(
                'expenses',
                {'amount': newAmount},
                where: 'id = ?',
                whereArgs: [expense.first['id']],
              );

              await txn.update(
                'statements',
                {'amount': newAmount},
                where: 'id_expense = ?',
                whereArgs: [expense.first['id']],
              );
            }

            await txn.update(
              'credit_card_transactions',
              {'amount': newAmount},
              where: 'id = ?',
              whereArgs: [transactions.first['id']],
            );
          });
        }
      }

      batch.execute('ALTER TABLE accounts ADD COLUMN id_statement_initial_amount TEXT REFERENCES statements ON UPDATE CASCADE ON DELETE RESTRICT;');

      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT 
            accounts.*,
            ROUND(COALESCE(SUM(statements.amount), 0.0), 2) AS transactions_amount
          FROM accounts
          LEFT JOIN statements
            ON accounts.id = statements.id_account AND statements.deleted_at IS NULL
          GROUP BY accounts.id, description;
      ''');

      for (final account in result) {
        final double initialAmount = account['initial_amount'] ?? 0;
        final double transactionsAmount = account['transactions_amount'] ?? 0;
        final balance = (initialAmount + transactionsAmount).toRound(2);

        final String idStatement = const Uuid().v1();

        if (initialAmount > 0) {
          batch.insert(
            'statements',
            {
              'id': idStatement,
              'created_at': DateTime.now().toIso8601String(),
              'amount': initialAmount,
              'date': account['created_at'],
              'id_account': account['id'],
            },
          );

          batch.update(
            'accounts',
            {'id_statement_initial_amount': idStatement},
            where: 'id = ?',
            whereArgs: [account['id']],
          );
        }

        if (balance != 0) {
          batch.update(
            'accounts',
            {'deleted_at': null},
            where: 'id = ?',
            whereArgs: [account['id']],
          );
        }
      }

      batch.execute('ALTER TABLE accounts DROP COLUMN initial_amount;');
    }

    if (oldVersion < 10) {
      batch.execute('ALTER TABLE expenses ADD COLUMN recurring INTEGER NOT NULL DEFAULT 0;');
      batch.execute('ALTER TABLE expenses ADD COLUMN recurrence_id TEXT;');
      batch.execute('ALTER TABLE incomes ADD COLUMN recurring INTEGER NOT NULL DEFAULT 0;');
      batch.execute('ALTER TABLE incomes ADD COLUMN recurrence_id TEXT;');

      batch.execute('CREATE INDEX IF NOT EXISTS idx_expenses_recurrence_id ON expenses(recurrence_id);');
      batch.execute('CREATE INDEX IF NOT EXISTS idx_incomes_recurrence_id ON incomes(recurrence_id);');
    }

    if (oldVersion < 11) {
      batch.execute('ALTER TABLE credit_card_transactions ADD COLUMN installment_group_id TEXT;');
      batch.execute('ALTER TABLE credit_card_transactions ADD COLUMN installment_number INTEGER;');
      batch.execute('ALTER TABLE credit_card_transactions ADD COLUMN installment_count INTEGER;');
      batch.execute('CREATE INDEX IF NOT EXISTS idx_credit_card_transactions_installment_group_id ON credit_card_transactions(installment_group_id);');
    }


    if (oldVersion < 12) {
      batch.execute('ALTER TABLE credit_cards ADD COLUMN safety_limit REAL;');
      batch.execute('ALTER TABLE credit_card_transactions ADD COLUMN cash_advance_plan_id TEXT;');
      batch.execute('ALTER TABLE credit_card_transactions ADD COLUMN cash_advance_principal REAL;');

      batch.execute('''
        CREATE TABLE card_cash_advance_plans (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          deleted_at TEXT,
          description TEXT NOT NULL,
          id_account TEXT NOT NULL REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          id_credit_card TEXT NOT NULL REFERENCES credit_cards(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          amount_received REAL NOT NULL,
          amount_charged REAL NOT NULL,
          planned_date TEXT NOT NULL,
          bill_due_date TEXT NOT NULL,
          status INTEGER NOT NULL DEFAULT 0,
          realized_at TEXT,
          id_statement TEXT,
          id_credit_card_transaction TEXT
        );
      ''');
      batch.execute('CREATE INDEX IF NOT EXISTS idx_cash_advance_status_date ON card_cash_advance_plans(status, planned_date);');
      batch.execute('CREATE INDEX IF NOT EXISTS idx_cash_advance_card ON card_cash_advance_plans(id_credit_card);');
    }

    if (oldVersion < 13) {
      batch.execute('''
        CREATE TABLE planned_purchases (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          deleted_at TEXT,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          planned_date TEXT NOT NULL,
          reserve_amount REAL NOT NULL DEFAULT 0
        );
      ''');
      batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_planned_purchase_date ON planned_purchases(planned_date);',
      );
    }

    if (oldVersion < 14) {
      batch.execute('ALTER TABLE planned_purchases ADD COLUMN payment_type INTEGER NOT NULL DEFAULT 0;');
      batch.execute('ALTER TABLE planned_purchases ADD COLUMN id_credit_card TEXT;');
      batch.execute('ALTER TABLE planned_purchases ADD COLUMN installment_count INTEGER NOT NULL DEFAULT 1;');
      batch.execute('ALTER TABLE planned_purchases ADD COLUMN total_charged REAL NOT NULL DEFAULT 0;');
      batch.execute('ALTER TABLE planned_purchases ADD COLUMN first_bill_due_date TEXT;');
      batch.execute('UPDATE planned_purchases SET total_charged = amount WHERE total_charged = 0;');
      batch.execute('ALTER TABLE credit_card_transactions ADD COLUMN planned_purchase_id TEXT;');
      batch.execute('ALTER TABLE credit_card_transactions ADD COLUMN planned_purchase_principal REAL;');
    }

    if (oldVersion < 15) {
      batch.execute('ALTER TABLE planned_purchases ADD COLUMN id_category TEXT;');
      batch.execute('ALTER TABLE planned_purchases ADD COLUMN id_account TEXT;');
      batch.execute('ALTER TABLE planned_purchases ADD COLUMN observation TEXT;');

      batch.execute('ALTER TABLE expenses ADD COLUMN expected_amount REAL;');
      batch.execute('ALTER TABLE expenses ADD COLUMN track_variance INTEGER NOT NULL DEFAULT 0;');
      batch.execute('ALTER TABLE incomes ADD COLUMN expected_amount REAL;');
      batch.execute('ALTER TABLE incomes ADD COLUMN track_variance INTEGER NOT NULL DEFAULT 0;');
    }

    if (oldVersion < 16) {
      // Marca exclusivamente diferenças que o usuário confirmou como
      // "esperado x realizado". Flags antigas sem confirmação explícita não
      // devem aparecer no relatório novo.
      batch.execute('ALTER TABLE expenses ADD COLUMN variance_registered_at TEXT;');
      batch.execute('ALTER TABLE incomes ADD COLUMN variance_registered_at TEXT;');
    }

    if (oldVersion < 17) {
      // Preserva a competência original em `date` e registra separadamente
      // quando o dinheiro realmente entrou/saiu da conta.
      batch.execute('ALTER TABLE expenses ADD COLUMN realized_at TEXT;');
      batch.execute('ALTER TABLE incomes ADD COLUMN realized_at TEXT;');
      batch.execute("UPDATE expenses SET realized_at = date WHERE paid = 1 AND realized_at IS NULL;");
      batch.execute("UPDATE incomes SET realized_at = date WHERE received = 1 AND realized_at IS NULL;");
    }

    await batch.commit();
  }

  Future<String> _getPath() async {
    final String databasesPath = await getDatabasesPath();
    final String path = join(databasesPath, _name);
    await Directory(databasesPath).create(recursive: true);
    return path;
  }

  @override
  Future<void> switchToAuthenticatedUser() async {
    final User? user = _currentFirebaseUser();
    if (user == null) return;
    if (_activeUserId == user.uid && database.isOpen) return;

    await _closeCurrentDatabase();
    _activeUserId = user.uid;
    await _migrateLegacyDatabaseIfNeeded(user: user);
    await _loadDatabase();
  }

  @override
  Future<void> switchToSignedOutSession() async {
    if (_activeUserId == null && database.isOpen) return;

    await _closeCurrentDatabase();
    _activeUserId = null;
    await _loadDatabase();
  }

  Future<void> _closeCurrentDatabase() async {
    if (!database.isOpen) return;
    await _checkpointDatabase(database);
    await database.close();
  }

  Future<void> _migrateLegacyDatabaseIfNeeded({User? user}) async {
    final User? authenticatedUser = user ?? _currentFirebaseUser();
    if (authenticatedUser == null || _activeUserId == null) return;

    final String databasesPath = await getDatabasesPath();
    await Directory(databasesPath).create(recursive: true);

    final String legacyPath = join(databasesPath, _legacyDatabaseName);
    final String targetPath = join(databasesPath, _name);
    final File legacyFile = File(legacyPath);
    final File targetFile = File(targetPath);

    if (await targetFile.exists() || !await legacyFile.exists()) return;

    Database? legacyDatabase;
    try {
      legacyDatabase = await openDatabase(
        legacyPath,
        singleInstance: false,
      );

      final List<Map<String, Object?>> rows = await legacyDatabase.query(
        'auth',
        columns: const ['id', 'email'],
        limit: 1,
      );

      if (rows.isEmpty) return;

      final String legacyId = rows.first['id']?.toString() ?? '';
      final String legacyEmail =
          rows.first['email']?.toString().trim().toLowerCase() ?? '';
      final String firebaseEmail =
          authenticatedUser.email?.trim().toLowerCase() ?? '';

      final bool belongsToUser = legacyId == authenticatedUser.uid ||
          (legacyEmail.isNotEmpty && legacyEmail == firebaseEmail);
      if (!belongsToUser) return;

      await _checkpointDatabase(legacyDatabase);
      await legacyDatabase.close();
      legacyDatabase = null;

      await legacyFile.copy(targetPath);

      Database? migratedDatabase;
      try {
        migratedDatabase = await openDatabase(
          targetPath,
          readOnly: true,
          singleInstance: false,
        );
        final List<Map<String, Object?>> integrity =
            await migratedDatabase.rawQuery('PRAGMA integrity_check;');
        final Object? value = integrity.isEmpty ? null : integrity.first.values.first;
        if (value?.toString().toLowerCase() != 'ok') {
          throw const FormatException('Falha ao validar o banco separado por usuário.');
        }
      } finally {
        if (migratedDatabase != null && migratedDatabase.isOpen) {
          await migratedDatabase.close();
        }
      }

      // Só remove o banco genérico depois de validar a cópia. Assim a primeira
      // atualização para bancos por usuário não arrisca os dados existentes.
      await _deleteDatabaseFileAndSidecars(legacyPath);
      debugPrint(
        'Rallet: banco local legado migrado para o usuário ${authenticatedUser.uid}.',
      );
    } catch (error, stackTrace) {
      debugPrint('Rallet: não foi possível migrar o banco legado: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (await targetFile.exists()) {
        await _deleteDatabaseFileAndSidecars(targetPath);
      }
    } finally {
      if (legacyDatabase != null && legacyDatabase.isOpen) {
        await legacyDatabase.close();
      }
    }
  }

  static User? _currentFirebaseUser() {
    if (Platform.isLinux) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  static String? _currentFirebaseUserId() => _currentFirebaseUser()?.uid;

  static String _safeUserId(String userId) =>
      userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  @override
  IDatabaseLocalBatch batch() => DatabaseLocalBatch(database: database);

  @override
  IDatabaseLocalTransaction transactionInstance() =>
      DatabaseLocalTransaction(databaseProvider: () => database);

  @override
  Future<int> insert(String table, Map<String, dynamic> values) async {
    try {
      return await database.insert(table, values);
    } on DatabaseException catch (e, stackTrace) {
      throw DatabaseLocalException(e.toString(), e.getResultCode(), stackTrace);
    }
  }

  @override
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs}) async {
    try {
      return await database.update(table, values, where: where, whereArgs: whereArgs);
    } on DatabaseException catch (e, stackTrace) {
      throw DatabaseLocalException(e.toString(), e.getResultCode(), stackTrace);
    }
  }

  @override
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    try {
      return await database.delete(table, where: where, whereArgs: whereArgs);
    } on DatabaseException catch (e, stackTrace) {
      throw DatabaseLocalException(e.toString(), e.getResultCode(), stackTrace);
    }
  }

  @override
  Future<dynamic> execute(String sql, [List<dynamic>? arguments]) async {
    try {
      return await database.execute(sql, arguments);
    } on DatabaseException catch (e, stackTrace) {
      throw DatabaseLocalException(e.toString(), e.getResultCode(), stackTrace);
    }
  }

  @override
  Future<dynamic> raw(String sql, DatabaseOperation operation, [List<dynamic>? arguments]) {
    try {
      switch (operation) {
        case DatabaseOperation.select:
          return database.rawQuery(sql, arguments);
        case DatabaseOperation.insert:
          return database.rawInsert(sql, arguments);
        case DatabaseOperation.update:
          return database.rawUpdate(sql, arguments);
        case DatabaseOperation.delete:
          return database.rawDelete(sql, arguments);
      }
    } on DatabaseException catch (e, stackTrace) {
      throw DatabaseLocalException(e.toString(), e.getResultCode(), stackTrace);
    }
  }

  @override
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
  }) async {
    try {
      return await database.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } on DatabaseException catch (e, stackTrace) {
      throw DatabaseLocalException(e.toString(), e.getResultCode(), stackTrace);
    }
  }
}

final class _DatabaseBackupSnapshot {
  final int version;
  final int length;
  final Map<String, int> rowCounts;

  const _DatabaseBackupSnapshot({
    required this.version,
    required this.length,
    required this.rowCounts,
  });
}
