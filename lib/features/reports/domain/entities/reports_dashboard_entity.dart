import 'package:rallet/features/reports/domain/entities/report_category_entity.dart';
import 'package:rallet/features/reports/domain/entities/report_financial_explanation_entity.dart';
import 'package:rallet/shared/extensions/double_extension.dart';

class ReportMonthlyPoint {
  final DateTime month;
  final double expenses;

  const ReportMonthlyPoint({
    required this.month,
    required this.expenses,
  });
}

class ReportFutureCommitment {
  final DateTime month;
  final double amount;

  const ReportFutureCommitment({
    required this.month,
    required this.amount,
  });
}

/// Composição auditável de um custo financeiro gerado por crédito via cartão.
class ReportFinancialCostItem {
  final String? id;
  final String description;
  final double amountReceived;
  final double amountCharged;
  final double financialCost;
  final DateTime billDueDate;
  final bool planned;
  final bool purchaseInstallment;

  const ReportFinancialCostItem({
    required this.id,
    required this.description,
    required this.amountReceived,
    required this.amountCharged,
    required this.financialCost,
    required this.billDueDate,
    required this.planned,
    this.purchaseInstallment = false,
  });

  double get costRate =>
      amountReceived <= 0 ? 0 : (financialCost / amountReceived) * 100;
}


class ReportPlannedExpenseItem {
  final String id;
  final String description;
  final String categoryName;
  final String paymentLabel;
  final double amount;
  final DateTime date;

  const ReportPlannedExpenseItem({
    required this.id,
    required this.description,
    required this.categoryName,
    required this.paymentLabel,
    required this.amount,
    required this.date,
  });
}

class ReportVarianceItem {
  final String id;
  final String description;
  final DateTime date;
  final double expectedAmount;
  final double realizedAmount;

  /// Positivo = resultado melhor que o esperado; negativo = pior.
  final double difference;
  final bool expense;

  const ReportVarianceItem({
    required this.id,
    required this.description,
    required this.date,
    required this.expectedAmount,
    required this.realizedAmount,
    required this.difference,
    required this.expense,
  });

  bool get positive => difference >= 0;
}

class ReportCashCommitmentComposition {
  final double pendingExpenses;
  final double openBills;
  final double plannedCreditCharges;
  final double plannedExpenses;

  const ReportCashCommitmentComposition({
    required this.pendingExpenses,
    required this.openBills,
    required this.plannedCreditCharges,
    required this.plannedExpenses,
  });

  double get total =>
      (pendingExpenses + openBills + plannedCreditCharges + plannedExpenses)
          .toRound(2);
}



enum ReportGreenDebtKind {
  creditCardBill,
  pendingExpense,
}

class ReportGreenDebtComponent {
  final String description;
  final String originLabel;
  final double amount;

  const ReportGreenDebtComponent({
    required this.description,
    required this.originLabel,
    required this.amount,
  });
}

class ReportGreenDebtItem {
  final String id;
  final String title;
  final String originLabel;
  final double amount;
  final DateTime dueDate;
  final ReportGreenDebtKind kind;
  final bool recurring;
  final double alreadyPaid;
  final List<ReportGreenDebtComponent> components;

  const ReportGreenDebtItem({
    required this.id,
    required this.title,
    required this.originLabel,
    required this.amount,
    required this.dueDate,
    required this.kind,
    this.recurring = false,
    this.alreadyPaid = 0,
    this.components = const [],
  });
}

class ReportGreenProjectionPoint {
  final DateTime month;
  final double projectedBalance;
  final double remainingDebt;
  final double requiredCoverage;
  final double netMovement;

  const ReportGreenProjectionPoint({
    required this.month,
    required this.projectedBalance,
    required this.remainingDebt,
    required this.requiredCoverage,
    required this.netMovement,
  });

  bool get green => projectedBalance + 0.01 >= requiredCoverage;
}

class ReportGreenPathEntity {
  /// Momento em que a leitura foi calculada.
  final DateTime calculatedAt;

  /// Saldo atual das contas marcadas para compor o saldo total.
  final double availableBalance;

  /// Dívidas já assumidas e ainda abertas.
  final double openDebt;
  final double creditCardDebt;
  final double pendingExpenseDebt;

  /// Itens que compõem a dívida em aberto. Mantém a leitura agregada acima,
  /// mas permite ao usuário abrir o relatório e descobrir exatamente de onde
  /// cada obrigação veio.
  final List<ReportGreenDebtItem> debtItems;

  /// Estimativa de um mês "normal" de consumo, sem pagamentos de fatura,
  /// principal de crédito, custos financeiros e planejamentos ainda não realizados.
  final double monthlyLivingCost;

  /// Renda mensal usada na simulação. Quando há receitas recorrentes no mês
  /// atual elas têm prioridade; caso contrário é usada média histórica.
  final double monthlyIncome;
  final bool incomeBasedOnRecurring;

  /// Parcela do custo mensal que acontece fora do cartão. Serve para estimar
  /// quanto da renda poderia, no máximo, ser comprometido com uma fatura sem
  /// ultrapassar a renda total.
  final double nonCardMonthlyCost;

  /// Saldo de faturas já registradas para o próximo mês.
  final double nextMonthCardBill;

  /// Quantidade de meses históricos realmente usada para estimar o custo.
  final int historyMonthsAnalyzed;

  /// Horizonte e evolução projetada do mesmo tipo de leitura usada pelo Radar:
  /// saldo atual + recebimentos - pagamentos, faturas e planejamentos conhecidos.
  final int projectionMonths;
  final List<ReportGreenProjectionPoint> projection;

  const ReportGreenPathEntity({
    required this.calculatedAt,
    required this.availableBalance,
    required this.openDebt,
    required this.creditCardDebt,
    required this.pendingExpenseDebt,
    this.debtItems = const [],
    required this.monthlyLivingCost,
    required this.monthlyIncome,
    required this.incomeBasedOnRecurring,
    required this.nonCardMonthlyCost,
    required this.nextMonthCardBill,
    required this.historyMonthsAnalyzed,
    this.projectionMonths = 6,
    this.projection = const [],
  });

  /// Quanto seria necessário hoje para quitar as dívidas registradas e ainda
  /// manter o equivalente a um mês normal de despesas com dinheiro próprio.
  double get greenTarget => (openDebt + monthlyLivingCost).toRound(2);

  double get amountMissing {
    final double value = greenTarget - availableBalance;
    return (value <= 0 ? 0.0 : value).toRound(2);
  }

  /// Quanto sobra por mês se a renda e o custo mensal permanecerem próximos
  /// das estimativas atuais. É essa sobra que pode reduzir dívida e depois
  /// formar a reserva de um mês.
  double get monthlyRecoveryCapacity =>
      (monthlyIncome - monthlyLivingCost).toRound(2);

  /// Limite pessoal teórico para cartão: renda menos despesas fora do cartão.
  /// Não é o limite bancário e não é uma recomendação de gastar tudo isso.
  double get sustainableCardCapacity {
    final double value = monthlyIncome - nonCardMonthlyCost;
    return (value <= 0 ? 0.0 : value).toRound(2);
  }

  double get nextMonthCardExcess {
    final double value = nextMonthCardBill - sustainableCardCapacity;
    return (value <= 0 ? 0.0 : value).toRound(2);
  }

  bool get isGreen => amountMissing <= 0.01;

  bool get hasOpenDebt => openDebt > 0.01;

  /// Primeiro mês em que a condição de verde é atingida e permanece atendida
  /// em todos os meses seguintes já conhecidos dentro do horizonte escolhido.
  /// Isso evita declarar recuperação em um mês e voltar ao vermelho logo depois
  /// por causa de uma fatura, parcela ou planejamento já cadastrado.
  DateTime? get estimatedGreenMonth {
    if (projection.isEmpty) {
      if (isGreen) {
        return DateTime(calculatedAt.year, calculatedAt.month, 1);
      }
      if (monthlyRecoveryCapacity <= 0.01) return null;
      final int months = (amountMissing / monthlyRecoveryCapacity).ceil();
      return DateTime(calculatedAt.year, calculatedAt.month + months, 1);
    }

    for (int index = 0; index < projection.length; index++) {
      final bool staysGreen =
          projection.skip(index).every((point) => point.green);
      if (projection[index].green && staysGreen) {
        return DateTime(
          projection[index].month.year,
          projection[index].month.month,
          1,
        );
      }
    }
    return null;
  }

  int? get monthsToGreen {
    final DateTime? forecast = estimatedGreenMonth;
    if (forecast == null) return null;
    final DateTime base = DateTime(calculatedAt.year, calculatedAt.month, 1);
    return (forecast.year - base.year) * 12 + forecast.month - base.month;
  }

  bool get reachesGreenWithinProjection => estimatedGreenMonth != null;

  DateTime get projectionEnd {
    if (projection.isNotEmpty) return projection.last.month;
    return DateTime(calculatedAt.year, calculatedAt.month + projectionMonths, 0);
  }
}

class ReportsDashboardEntity {
  final DateTime month;
  final double incomes;
  final double expenses;

  /// Despesas comuns (sem pagamentos de fatura).
  final double regularExpenses;

  /// Compras normais de cartão consideradas pelo vencimento da fatura.
  final double creditCardPurchases;

  /// Juros/taxas já transformados em transação real de cartão.
  final double realizedFinancialCosts;

  /// Juros/taxas de operações ainda planejadas.
  final double plannedFinancialCosts;

  /// Compras ainda planejadas para o mês.
  final double plannedPurchases;

  /// Total relacionado ao cartão que compõe despesas: compras + custos.
  final double creditCardExpenses;

  /// Quanto ainda pode precisar sair do caixa no mês selecionado. Este valor
  /// responde à pergunta de A pagar e não deve ser confundido com despesa
  /// econômica do relatório.
  final ReportCashCommitmentComposition cashCommitments;

  final double fixedExpenses;
  final double variableExpenses;
  final double previousMonthExpenses;
  final List<ReportCategoryEntity> expenseCategories;
  final List<ReportMonthlyPoint> evolution;
  final List<ReportFutureCommitment> futureCommitments;
  final List<ReportFinancialCostItem> financialCostItems;
  final List<ReportPlannedExpenseItem> plannedExpenseItems;
  final List<ReportVarianceItem> varianceItems;

  /// Auditoria detalhada que reconcilia fluxo de caixa e resultado econômico.
  final ReportFinancialExplanationEntity financialExplanation;

  /// Leitura atual de dívida, custo mensal e prazo estimado para chegar a uma
  /// situação em que as dívidas estejam quitadas e haja um mês de despesas
  /// coberto pelo próprio dinheiro.
  final ReportGreenPathEntity greenPath;

  const ReportsDashboardEntity({
    required this.month,
    required this.incomes,
    required this.expenses,
    required this.regularExpenses,
    required this.creditCardPurchases,
    required this.realizedFinancialCosts,
    required this.plannedFinancialCosts,
    this.plannedPurchases = 0,
    required this.creditCardExpenses,
    required this.cashCommitments,
    required this.fixedExpenses,
    required this.variableExpenses,
    required this.previousMonthExpenses,
    required this.expenseCategories,
    required this.evolution,
    required this.futureCommitments,
    required this.financialCostItems,
    this.plannedExpenseItems = const [],
    this.varianceItems = const [],
    required this.financialExplanation,
    required this.greenPath,
  });

  double get financialCosts =>
      realizedFinancialCosts + plannedFinancialCosts;

  double get expenseCompositionTotal =>
      regularExpenses + creditCardPurchases + financialCosts + plannedPurchases;

  double get expenseCompositionDifference =>
      (expenses - expenseCompositionTotal).abs();

  bool get isExpenseCompositionConsistent =>
      expenseCompositionDifference <= 0.01;

  double get financialCostItemsTotal => financialCostItems.fold(
        0.0,
        (total, item) => total + item.financialCost,
      );

  double get financialCostCompositionDifference =>
      (financialCosts - financialCostItemsTotal).abs();

  bool get isFinancialCostCompositionConsistent =>
      financialCostCompositionDifference <= 0.01;

  double get categoryExpensesTotal => expenseCategories.fold(
        0.0,
        (total, category) => total + category.amount.abs(),
      );

  double get categoryCompositionDifference =>
      (expenses - categoryExpensesTotal).abs();

  bool get isCategoryCompositionConsistent =>
      categoryCompositionDifference <= 0.01;

  double get plannedExpensesDetailedTotal => plannedExpenseItems.fold(
        0.0,
        (total, item) => total + item.amount,
      );

  double get positiveVariance => varianceItems
      .where((item) => item.difference > 0)
      .fold(0.0, (total, item) => total + item.difference);

  double get negativeVariance => varianceItems
      .where((item) => item.difference < 0)
      .fold(0.0, (total, item) => total + item.difference.abs());

  double get netVariance => varianceItems.fold(
        0.0,
        (total, item) => total + item.difference,
      );

  double get savings => incomes - expenses;

  double get savingsRate => incomes <= 0 ? 0 : (savings / incomes) * 100;

  double get expenseVariationPercent {
    if (previousMonthExpenses <= 0) return 0;
    return ((expenses - previousMonthExpenses) / previousMonthExpenses) * 100;
  }
}
