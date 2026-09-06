import 'package:rallet/features/credit_card/domain/enums/installment_scope_enum.dart';
import 'package:flutter/material.dart';

class InstallmentScopeDialog {
  static Future<InstallmentScopeEnum?> show({
    required BuildContext context,
    required bool deleting,
    required int currentInstallment,
    required int totalInstallments,
  }) {
    return showModalBottomSheet<InstallmentScopeEnum>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
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
                      deleting ? 'Excluir compra parcelada' : 'Alterar compra parcelada',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Esta é a parcela $currentInstallment de $totalInstallments. O que deseja ${deleting ? 'excluir' : 'alterar'}?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.looks_one_outlined),
                title: const Text('Somente esta parcela'),
                onTap: () => Navigator.of(context).pop(InstallmentScopeEnum.single),
              ),
              ListTile(
                leading: const Icon(Icons.skip_next_outlined),
                title: const Text('Esta e as próximas'),
                subtitle: Text(
                  deleting
                      ? 'Mantém as parcelas anteriores no histórico'
                      : 'Mantém as parcelas anteriores como estão',
                ),
                onTap: () => Navigator.of(context).pop(InstallmentScopeEnum.currentAndFuture),
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive_outlined),
                title: const Text('Todas as parcelas'),
                onTap: () => Navigator.of(context).pop(InstallmentScopeEnum.all),
              ),
            ],
          ),
        );
      },
    );
  }
}
