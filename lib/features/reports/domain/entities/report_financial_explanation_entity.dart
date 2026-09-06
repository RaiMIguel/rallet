import 'package:rallet/shared/extensions/double_extension.dart';

enum ReportAuditTreatment {
  economicIncome,
  economicExpense,
  cashInflowNotIncome,
  cashOutflowNotNewExpense,
  neutral,
}

/// Classifica o motivo financeiro real por trás de um item da auditoria.
///
/// O tratamento (`ReportAuditTreatment`) diz COMO o item entra no cálculo.
/// O caso (`ReportAuditCase`) diz POR QUE ele pode fazer caixa e resultado
/// econômico parecerem contraditórios para o usuário.
enum ReportAuditCase {
  ordinary,
  pendingIncome,
  pendingExpense,
  creditCardPurchase,
  billPayment,
  openBill,
  cardCreditPrincipal,
  cardCreditObligation,
  transfer,
  plannedExpense,
  plannedCardCharge,
}

class ReportAuditItem {
  final String id;
  final String description;
  final DateTime date;
  final double amount;
  final String reason;
  final ReportAuditTreatment treatment;
  final ReportAuditCase caseType;
  final bool planned;

  /// Metadados opcionais de origem. São usados para mostrar, por exemplo,
  /// que um crédito entrou em setembro mas gerou uma obrigação/fatura em
  /// outubro, sem transformar o principal em renda ou em nova despesa.
  final String? originLabel;
  final String? relatedDateLabel;
  final DateTime? relatedDate;

  const ReportAuditItem({
    required this.id,
    required this.description,
    required this.date,
    required this.amount,
    required this.reason,
    required this.treatment,
    this.caseType = ReportAuditCase.ordinary,
    this.planned = false,
    this.originLabel,
    this.relatedDateLabel,
    this.relatedDate,
  });
}

class ReportFinancialExplanationEntity {
  final DateTime month;

  /// Valores oficiais usados no resultado econômico do relatório.
  final double economicIncomes;
  final double economicExpenses;

  /// Valores de caixa ainda pendentes para o período.
  final double cashReceivable;
  final double cashPayable;

  final List<ReportAuditItem> economicIncomeItems;
  final List<ReportAuditItem> economicExpenseItems;
  final List<ReportAuditItem> cashReceivableItems;
  final List<ReportAuditItem> cashPayableItems;
  final List<ReportAuditItem> nonEconomicItems;

  const ReportFinancialExplanationEntity({
    required this.month,
    required this.economicIncomes,
    required this.economicExpenses,
    required this.cashReceivable,
    required this.cashPayable,
    required this.economicIncomeItems,
    required this.economicExpenseItems,
    required this.cashReceivableItems,
    required this.cashPayableItems,
    required this.nonEconomicItems,
  });

  double get savings => (economicIncomes - economicExpenses).toRound(2);

  double get cashPendingBalance => (cashReceivable - cashPayable).toRound(2);

  bool get shouldExplainPositiveEconomyWithNegativePendingCash =>
      cashPayable > cashReceivable + 0.01 && savings > 0.01;

  /// Diferença absoluta entre o que os cards pendentes sugerem
  /// (A receber - A pagar) e o resultado econômico do mês.
  double get economyPendingDifference =>
      (savings - cashPendingBalance).abs().toRound(2);

  /// O aviso explicativo deve aparecer sempre que as duas leituras não
  /// fecharem entre si até a tolerância de um centavo.
  bool get shouldExplainEconomyVsPending => economyPendingDifference > 0.01;

  List<ReportAuditItem> itemsForCase(ReportAuditCase caseType) => [
        ...economicIncomeItems,
        ...economicExpenseItems,
        ...cashReceivableItems,
        ...cashPayableItems,
        ...nonEconomicItems,
      ].where((item) => item.caseType == caseType).toList();

  double totalForCase(ReportAuditCase caseType) => itemsForCase(caseType)
      .fold(0.0, (total, item) => total + item.amount.abs())
      .toRound(2);

  double get economicIncomeItemsTotal => economicIncomeItems
      .fold(0.0, (total, item) => total + item.amount.abs())
      .toRound(2);

  double get economicExpenseItemsTotal => economicExpenseItems
      .fold(0.0, (total, item) => total + item.amount.abs())
      .toRound(2);

  double get cashReceivableItemsTotal => cashReceivableItems
      .fold(0.0, (total, item) => total + item.amount.abs())
      .toRound(2);

  double get cashPayableItemsTotal => cashPayableItems
      .fold(0.0, (total, item) => total + item.amount.abs())
      .toRound(2);

  bool get isEconomicIncomeCompositionConsistent =>
      (economicIncomes - economicIncomeItemsTotal).abs() <= 0.01;

  bool get isEconomicExpenseCompositionConsistent =>
      (economicExpenses - economicExpenseItemsTotal).abs() <= 0.01;

  bool get isCashReceivableCompositionConsistent =>
      (cashReceivable - cashReceivableItemsTotal).abs() <= 0.01;

  bool get isCashPayableCompositionConsistent =>
      (cashPayable - cashPayableItemsTotal).abs() <= 0.01;

  bool get isFullyReconciled =>
      isEconomicIncomeCompositionConsistent &&
      isEconomicExpenseCompositionConsistent &&
      isCashReceivableCompositionConsistent &&
      isCashPayableCompositionConsistent;
}
