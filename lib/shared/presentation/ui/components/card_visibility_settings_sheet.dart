import 'package:flutter/material.dart';

class CardCustomizationResult {
  final Set<String> hiddenCards;
  final List<String> cardOrder;

  const CardCustomizationResult({
    required this.hiddenCards,
    required this.cardOrder,
  });
}

Future<CardCustomizationResult?> showCardVisibilitySettingsSheet({
  required BuildContext context,
  required String title,
  required String description,
  required Map<String, String> options,
  required Set<String> hiddenCards,
  required List<String> cardOrder,
}) {
  final Set<String> workingHidden = Set<String>.from(hiddenCards);
  final List<String> defaultOrder = options.keys.toList();
  final List<String> workingOrder = [
    ...cardOrder.where(options.containsKey),
    ...defaultOrder.where((id) => !cardOrder.contains(id)),
  ];

  return showModalBottomSheet<CardCustomizationResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: StatefulBuilder(
        builder: (context, setSheetState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.drag_indicator_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Segure o ícone e arraste para alterar a ordem.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: workingOrder.length,
                  onReorder: (oldIndex, newIndex) {
                    setSheetState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final String item = workingOrder.removeAt(oldIndex);
                      workingOrder.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final String id = workingOrder[index];
                    return CheckboxListTile(
                      key: ValueKey(id),
                      value: !workingHidden.contains(id),
                      title: Text(options[id] ?? id),
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_indicator_rounded),
                        ),
                      ),
                      onChanged: (visible) {
                        setSheetState(() {
                          if (visible ?? false) {
                            workingHidden.remove(id);
                          } else {
                            workingHidden.add(id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancelar'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setSheetState(() {
                          workingHidden.clear();
                          workingOrder
                            ..clear()
                            ..addAll(defaultOrder);
                        });
                      },
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Restaurar padrão'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(
                        CardCustomizationResult(
                          hiddenCards: Set<String>.from(workingHidden),
                          cardOrder: List<String>.from(workingOrder),
                        ),
                      ),
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
