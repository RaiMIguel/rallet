class HomeMonthlyEconomyEntity {
  final double incomes;
  final double expenses;
  final double regularExpenses;
  final double creditCardPurchases;
  final double realizedFinancialCosts;
  final double plannedFinancialCosts;
  final double plannedPurchases;

  const HomeMonthlyEconomyEntity({
    required this.incomes,
    required this.expenses,
    this.regularExpenses = 0,
    this.creditCardPurchases = 0,
    this.realizedFinancialCosts = 0,
    this.plannedFinancialCosts = 0,
    this.plannedPurchases = 0,
  });

  double get financialCosts =>
      realizedFinancialCosts + plannedFinancialCosts;

  double get expenseCompositionTotal =>
      regularExpenses + creditCardPurchases + financialCosts + plannedPurchases;

  bool get isExpenseCompositionConsistent =>
      (expenses - expenseCompositionTotal).abs() <= 0.01;

  double get savings => incomes - expenses;

  double get savingsRate => incomes <= 0 ? 0 : (savings / incomes) * 100;
}
