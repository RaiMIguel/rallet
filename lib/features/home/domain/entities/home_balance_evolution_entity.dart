class HomeBalanceEvolutionEntity {
  final DateTime date;
  final double balance;
  final bool projected;

  const HomeBalanceEvolutionEntity({
    required this.date,
    required this.balance,
    required this.projected,
  });
}
