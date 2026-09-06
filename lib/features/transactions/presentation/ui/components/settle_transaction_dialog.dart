import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/extensions/string_extension.dart';
import 'package:rallet/shared/presentation/ui/components/form/mask/mask_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

typedef SettleTransactionResult = ({
  double realizedAmount,
  bool trackVariance,
  DateTime realizedAt,
});

/// Confirma uma receita/despesa pendente sem confundir duas situações:
/// 1) o valor cadastrado sempre esteve errado (correção);
/// 2) o valor previsto estava certo, mas o realizado foi diferente (variação).
class SettleTransactionDialog extends StatefulWidget {
  final String description;
  final double expectedAmount;
  final bool expense;

  const SettleTransactionDialog._({
    required this.description,
    required this.expectedAmount,
    required this.expense,
  });

  static Future<SettleTransactionResult?> show({
    required BuildContext context,
    required String description,
    required double expectedAmount,
    required bool expense,
  }) {
    return showDialog<SettleTransactionResult>(
      context: context,
      builder: (_) => SettleTransactionDialog._(
        description: description,
        expectedAmount: expectedAmount.abs(),
        expense: expense,
      ),
    );
  }

  @override
  State<SettleTransactionDialog> createState() =>
      _SettleTransactionDialogState();
}

class _SettleTransactionDialogState extends State<SettleTransactionDialog> {
  late final TextEditingController amountController;
  DateTime realizedAt = DateTime.now();

  double get amount => amountController.text.moneyToDouble();

  bool get changed => (amount - widget.expectedAmount).abs() > 0.004;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(
      text: widget.expectedAmount.moneyWithoutSymbol,
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double difference = widget.expense
        ? widget.expectedAmount - amount
        : amount - widget.expectedAmount;

    return AlertDialog(
      title: Text(widget.expense ? 'Confirmar pagamento' : 'Confirmar recebimento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.description),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              autofocus: false,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                MaskInputFormatter.currency(),
              ],
              decoration: InputDecoration(
                labelText: 'Valor realizado',
                prefixText: 'R\$ ',
                helperText: 'Previsto: ${widget.expectedAmount.money}',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Data realizada'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(realizedAt)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectDate,
            ),
            if (amount <= 0)
              Text(
                'Informe um valor maior que zero.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
              )
            else if (changed) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  difference >= 0
                      ? (widget.expense
                          ? 'Diferença favorável de ${difference.abs().money}.'
                          : 'Receita ${difference.abs().money} acima do esperado.')
                      : (widget.expense
                          ? '${difference.abs().money} acima do esperado.'
                          : 'Receita ${difference.abs().money} abaixo do esperado.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Se o valor anterior sempre esteve errado, use “Só corrigir valor”. '
                'Se ele era realmente o previsto e o valor final mudou, use “Registrar diferença real”.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (changed && amount > 0)
          TextButton(
            onPressed: () => _finish(trackVariance: false),
            child: const Text('Só corrigir valor'),
          ),
        FilledButton(
          onPressed: amount > 0
              ? () => _finish(trackVariance: changed)
              : null,
          child: Text(changed ? 'Registrar diferença real' : 'Confirmar'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: realizedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected == null) return;
    setState(() => realizedAt = selected);
  }

  void _finish({required bool trackVariance}) {
    Navigator.pop(
      context,
      (
        realizedAmount: amount,
        trackVariance: trackVariance,
        realizedAt: realizedAt,
      ),
    );
  }
}
