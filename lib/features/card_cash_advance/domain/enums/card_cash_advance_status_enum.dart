enum CardCashAdvanceStatusEnum {
  planned(0),
  realized(1);

  final int value;

  const CardCashAdvanceStatusEnum(this.value);

  static CardCashAdvanceStatusEnum fromValue(int value) =>
      CardCashAdvanceStatusEnum.values.firstWhere(
        (item) => item.value == value,
        orElse: () => CardCashAdvanceStatusEnum.planned,
      );
}
