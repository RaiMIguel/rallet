import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:rallet/features/card_cash_advance/infra/data_sources/i_card_cash_advance_local_data_source.dart';
import 'package:rallet/features/card_cash_advance/infra/models/card_cash_advance_plan_model.dart';
import 'package:rallet/shared/infra/data_sources/constants/tables_names_constant.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_batch.dart';
import 'package:rallet/shared/infra/data_sources/local_data_source.dart';
import 'package:rallet/shared/infra/models/model.dart';

class CardCashAdvanceLocalDataSource
    extends LocalDataSource<CardCashAdvancePlanModel>
    implements ICardCashAdvanceLocalDataSource {
  CardCashAdvanceLocalDataSource({required super.databaseLocal});

  @override
  String get tableName => cardCashAdvancePlansTableName;

  @override
  String get orderByDefault => 'planned_date ASC';

  @override
  void createTable(IDatabaseLocalBatch batch) {
    batch.execute('''
      CREATE TABLE $tableName (
        ${baseColumnsSql()},
        description TEXT NOT NULL,
        id_account TEXT NOT NULL REFERENCES $accountsTableName(${Model.idColumnName}) ON UPDATE CASCADE ON DELETE RESTRICT,
        id_credit_card TEXT NOT NULL REFERENCES $creditCardsTableName(${Model.idColumnName}) ON UPDATE CASCADE ON DELETE RESTRICT,
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
    batch.execute('CREATE INDEX IF NOT EXISTS idx_cash_advance_status_date ON $tableName(status, planned_date);');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_cash_advance_card ON $tableName(id_credit_card);');
  }

  @override
  CardCashAdvancePlanModel fromMap(Map<String, dynamic> map, {String prefix = ''}) {
    final base = baseFromMap(map, prefix: prefix);
    return CardCashAdvancePlanModel(
      id: base.id,
      createdAt: base.createdAt,
      deletedAt: base.deletedAt,
      description: map['${prefix}description'],
      idAccount: map['${prefix}id_account'],
      idCreditCard: map['${prefix}id_credit_card'],
      amountReceived: (map['${prefix}amount_received'] as num).toDouble(),
      amountCharged: (map['${prefix}amount_charged'] as num).toDouble(),
      plannedDate: DateTime.parse(map['${prefix}planned_date']).toLocal(),
      billDueDate: DateTime.parse(map['${prefix}bill_due_date']).toLocal(),
      status: CardCashAdvanceStatusEnum.fromValue(map['${prefix}status'] as int),
      realizedAt: DateTime.tryParse(map['${prefix}realized_at']?.toString() ?? '')?.toLocal(),
      idStatement: map['${prefix}id_statement'],
      idCreditCardTransaction: map['${prefix}id_credit_card_transaction'],
    );
  }
}
