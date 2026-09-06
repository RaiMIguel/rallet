import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/infra/data_sources/i_purchase_planning_local_data_source.dart';
import 'package:rallet/features/purchase_planning/infra/models/planned_purchase_model.dart';
import 'package:rallet/shared/infra/data_sources/constants/tables_names_constant.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_batch.dart';
import 'package:rallet/shared/infra/data_sources/local_data_source.dart';

class PurchasePlanningLocalDataSource
    extends LocalDataSource<PlannedPurchaseModel>
    implements IPurchasePlanningLocalDataSource {
  PurchasePlanningLocalDataSource({required super.databaseLocal});

  @override
  String get tableName => plannedPurchasesTableName;

  @override
  String get orderByDefault => 'planned_date ASC';

  @override
  void createTable(IDatabaseLocalBatch batch) {
    batch.execute('''
      CREATE TABLE $tableName (
        ${baseColumnsSql()},
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        planned_date TEXT NOT NULL,
        reserve_amount REAL NOT NULL DEFAULT 0,
        payment_type INTEGER NOT NULL DEFAULT 0,
        id_credit_card TEXT,
        installment_count INTEGER NOT NULL DEFAULT 1,
        total_charged REAL NOT NULL DEFAULT 0,
        first_bill_due_date TEXT,
        id_category TEXT REFERENCES categories(id) ON UPDATE CASCADE ON DELETE RESTRICT,
        id_account TEXT REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
        observation TEXT
      );
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_planned_purchase_date ON $tableName(planned_date);',
    );
  }

  @override
  PlannedPurchaseModel fromMap(Map<String, dynamic> map, {String prefix = ''}) {
    final base = baseFromMap(map, prefix: prefix);
    return PlannedPurchaseModel(
      id: base.id,
      createdAt: base.createdAt,
      deletedAt: base.deletedAt,
      description: map['${prefix}description']?.toString() ?? '',
      amount: (map['${prefix}amount'] as num).toDouble(),
      plannedDate: DateTime.parse(map['${prefix}planned_date']).toLocal(),
      reserveAmount: (map['${prefix}reserve_amount'] as num?)?.toDouble() ?? 0,
      paymentType: PlannedPurchasePaymentType.values[((map['${prefix}payment_type'] as num?)?.toInt() ?? 0).clamp(0, PlannedPurchasePaymentType.values.length - 1).toInt()],
      idCreditCard: map['${prefix}id_credit_card']?.toString(),
      installmentCount: (map['${prefix}installment_count'] as num?)?.toInt() ?? 1,
      totalCharged: (map['${prefix}total_charged'] as num?)?.toDouble() ?? (map['${prefix}amount'] as num).toDouble(),
      firstBillDueDate: map['${prefix}first_bill_due_date'] == null ? null : DateTime.parse(map['${prefix}first_bill_due_date']).toLocal(),
      idCategory: map['${prefix}id_category']?.toString(),
      idAccount: map['${prefix}id_account']?.toString(),
      observation: map['${prefix}observation']?.toString(),
    );
  }
}
