extension StringExtension on String {
  int? toColor() => int.tryParse("0xFF$this");

  /// Converte valores monetários digitados pelo usuário para `double` de forma
  /// consistente. Aceita tanto o padrão brasileiro (1.234,56) quanto valores
  /// simples com ponto decimal (1234.56).
  ///
  /// O retorno é normalizado em centavos para evitar pequenas diferenças de
  /// ponto flutuante entre formulários diferentes do Rallet.
  double moneyToDouble() {
    String raw = trim()
        .replaceAll(RegExp(r'[^0-9,\.\-]'), '');
    if (raw.isEmpty || raw == '-') return 0.0;

    final int lastComma = raw.lastIndexOf(',');
    final int lastDot = raw.lastIndexOf('.');
    String normalized;

    if (lastComma >= 0 && lastDot >= 0) {
      // O separador que aparece por último é tratado como decimal; o outro é
      // separador de milhar.
      if (lastComma > lastDot) {
        normalized = raw.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = raw.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot >= 0) {
      final int decimalDigits = raw.length - lastDot - 1;
      if (decimalDigits == 1 || decimalDigits == 2) {
        normalized = raw;
      } else {
        // Ex.: 1.234 deve continuar significando mil duzentos e trinta e
        // quatro quando não houver casas decimais plausíveis.
        normalized = raw.replaceAll('.', '');
      }
    } else {
      normalized = raw;
    }

    final double parsed = double.tryParse(normalized) ?? 0.0;
    return (parsed * 100).round() / 100.0;
  }

  String capitalizeFirstLetter() {
    if (isEmpty) return this;

    return substring(0, 1).toUpperCase() + substring(1);
  }
}
