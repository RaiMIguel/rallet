import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:flutter/material.dart';

class RecurrenceScopeDialog {
  static Future<RecurrenceScopeEnum?> show({
    required BuildContext context,
    required bool deleting,
    bool stopping = false,
  }) {
    return showModalBottomSheet<RecurrenceScopeEnum>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final String title = stopping
            ? 'Parar recorrência'
            : deleting
                ? R.strings.deleteRecurrence
                : R.strings.editRecurrence;

        final String question = stopping
            ? 'Deseja retirar somente este lançamento da recorrência ou encerrar a recorrência a partir dele?'
            : deleting
                ? R.strings.deleteRecurrenceQuestion
                : R.strings.editRecurrenceQuestion;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      question,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.looks_one_outlined),
                title: Text(
                  stopping ? 'Somente este lançamento' : R.strings.recurrenceOnlyThis,
                ),
                subtitle: stopping
                    ? const Text('A recorrência continua normalmente nos próximos meses')
                    : null,
                onTap: () => Navigator.of(context).pop(RecurrenceScopeEnum.single),
              ),
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: Text(
                  stopping ? 'Este e os próximos' : R.strings.recurrenceThisAndFuture,
                ),
                subtitle: stopping
                    ? const Text('Mantém este lançamento e remove as ocorrências futuras')
                    : null,
                onTap: () => Navigator.of(context).pop(RecurrenceScopeEnum.currentAndFuture),
              ),
              if (!stopping)
                ListTile(
                  leading: const Icon(Icons.all_inclusive_outlined),
                  title: Text(R.strings.recurrenceAll),
                  onTap: () => Navigator.of(context).pop(RecurrenceScopeEnum.all),
                ),
            ],
          ),
        );
      },
    );
  }
}
