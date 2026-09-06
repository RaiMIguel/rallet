import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/card_cash_advance/presentation/ui/card_cash_advance_form_page.dart';
import 'package:rallet/features/home/domain/entities/financial_radar_entity.dart';
import 'package:rallet/features/home/presentation/ui/financial_alerts_page.dart';
import 'package:rallet/features/home/presentation/view_models/home_view_model.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _RadarAccentPreset { blue, green, orange, red, none }

const String _radarOkAccentPreference = 'home_radar_ok_accent';
const String _radarAlertAccentPreference = 'home_radar_alert_accent';

class HomeFinancialAlertsCard extends StatefulWidget {
  final HomeViewModel viewModel;

  const HomeFinancialAlertsCard({
    super.key,
    required this.viewModel,
  });

  @override
  State<HomeFinancialAlertsCard> createState() => _HomeFinancialAlertsCardState();
}

class _HomeFinancialAlertsCardState extends State<HomeFinancialAlertsCard> {
  HomeViewModel get viewModel => widget.viewModel;

  SharedPreferences get _preferences => DI.get<SharedPreferences>();

  _RadarAccentPreset _readPreset(String key, _RadarAccentPreset fallback) {
    final String? stored = _preferences.getString(key);
    return _RadarAccentPreset.values.firstWhere(
      (preset) => preset.name == stored,
      orElse: () => fallback,
    );
  }

  Color _presetColor(_RadarAccentPreset preset, ColorScheme scheme) {
    return switch (preset) {
      _RadarAccentPreset.blue => const Color(0xFF3C65F6),
      _RadarAccentPreset.green => const Color(0xFF2CC985),
      _RadarAccentPreset.orange => scheme.primary,
      _RadarAccentPreset.red => const Color(0xFFE34B42),
      _RadarAccentPreset.none => scheme.onSurfaceVariant,
    };
  }

  String _presetLabel(_RadarAccentPreset preset) {
    return switch (preset) {
      _RadarAccentPreset.blue => 'Azul',
      _RadarAccentPreset.green => 'Verde',
      _RadarAccentPreset.orange => 'Laranja',
      _RadarAccentPreset.red => 'Vermelho',
      _RadarAccentPreset.none => 'Sem cor',
    };
  }

  Future<void> _showAppearanceSettings() async {
    _RadarAccentPreset okPreset = _readPreset(
      _radarOkAccentPreference,
      _RadarAccentPreset.orange,
    );
    _RadarAccentPreset alertPreset = _readPreset(
      _radarAlertAccentPreference,
      _RadarAccentPreset.red,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final ColorScheme scheme = Theme.of(context).colorScheme;

            Widget options({
              required _RadarAccentPreset selected,
              required ValueChanged<_RadarAccentPreset> onSelected,
            }) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _RadarAccentPreset.values.map((preset) {
                  final bool isSelected = preset == selected;
                  final Color color = _presetColor(preset, scheme);
                  return ChoiceChip(
                    selected: isSelected,
                    onSelected: (_) => onSelected(preset),
                    avatar: preset == _RadarAccentPreset.none
                        ? Icon(
                            Icons.block_rounded,
                            size: 17,
                            color: isSelected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                          )
                        : Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                    label: Text(_presetLabel(preset)),
                  );
                }).toList(),
              );
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(Icons.palette_outlined, color: scheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aparência do alerta',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              Text(
                                'Escolha apenas entre as cores padrão do Rallet.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Quando estiver tudo bem',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    options(
                      selected: okPreset,
                      onSelected: (preset) => setModalState(() => okPreset = preset),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Quando houver alertas',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    options(
                      selected: alertPreset,
                      onSelected: (preset) => setModalState(() => alertPreset = preset),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              okPreset = _RadarAccentPreset.orange;
                              alertPreset = _RadarAccentPreset.red;
                            });
                          },
                          icon: const Icon(Icons.restore_rounded),
                          label: const Text('Restaurar padrão'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () async {
                            await _preferences.setString(
                              _radarOkAccentPreference,
                              okPreset.name,
                            );
                            await _preferences.setString(
                              _radarAlertAccentPreference,
                              alertPreset.name,
                            );
                            if (!mounted) return;
                            Navigator.of(this.context).pop();
                            setState(() {});
                          },
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          viewModel,
          viewModel.loadFinancialRadar,
        ]),
        builder: (_, __) {
          final previous = viewModel.loadFinancialRadar.previous;

          if (viewModel.loadFinancialRadar.running && previous?.completed != true) {
            return const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (viewModel.loadFinancialRadar.hasError && previous?.completed != true) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Alertas financeiros', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Não foi possível calcular os alertas financeiros agora.',
                    style: textTheme.bodySmall?.copyWith(color: scheme.error),
                  ),
                ],
              ),
            );
          }

          final FinancialRadarEntity? radar =
              viewModel.loadFinancialRadar.result ?? previous?.result;

          if (radar == null) return const SizedBox.shrink();

          final bool hasAlerts = radar.hasAlerts;
          final _RadarAccentPreset preset = hasAlerts
              ? _readPreset(_radarAlertAccentPreference, _RadarAccentPreset.red)
              : _readPreset(_radarOkAccentPreference, _RadarAccentPreset.orange);
          final bool accentEnabled = preset != _RadarAccentPreset.none;
          final Color accent = _presetColor(preset, scheme);
          final bool dark = Theme.of(context).brightness == Brightness.dark;
          final String horizon =
              '${viewModel.radarMonths} ${viewModel.radarMonths == 1 ? 'mês' : 'meses'}';

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: accentEnabled
                    ? [
                        accent.withValues(
                          alpha: hasAlerts
                              ? (dark ? .14 : .09)
                              : (dark ? .07 : .04),
                        ),
                        scheme.surfaceContainer,
                      ]
                    : [scheme.surfaceContainer, scheme.surfaceContainer],
              ),
              border: Border.all(
                color: accentEnabled
                    ? accent.withValues(alpha: hasAlerts ? .24 : .08)
                    : scheme.outlineVariant.withValues(alpha: .65),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: dark ? .13 : .08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.radar_rounded, color: accent, size: 21),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alertas financeiros',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              hasAlerts
                                  ? 'Atenção nos próximos $horizon'
                                  : 'Tudo ok pelos próximos $horizon',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Aparência do alerta',
                        visualDensity: VisualDensity.compact,
                        onPressed: _showAppearanceSettings,
                        icon: Icon(
                          Icons.settings_outlined,
                          size: 19,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: dark ? .11 : .07),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasAlerts
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_rounded,
                              size: 15,
                              color: accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasAlerts ? '${radar.totalAlerts}' : 'OK',
                              style: textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasAlerts) ...[
                    if (radar.alerts.isNotEmpty)
                      _AlertPreview(
                        alert: radar.alerts.first,
                        hideAmounts: viewModel.hideAmounts,
                        color: accent,
                      )
                    else if (radar.cardLimitAlerts.isNotEmpty)
                      _CardLimitAlertPreview(
                        alert: radar.cardLimitAlerts.first,
                        hideAmounts: viewModel.hideAmounts,
                        color: accent,
                      ),
                    if (radar.totalAlerts > 1) ...[
                      const SizedBox(height: 7),
                      Text(
                        '+ ${radar.totalAlerts - 1} outro${radar.totalAlerts - 1 == 1 ? '' : 's'} ponto${radar.totalAlerts - 1 == 1 ? '' : 's'} de atenção no período.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (radar.alerts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await context.pushNamed(
                              CardCashAdvanceFormPage.route,
                              extra: CardCashAdvanceFormArgs(
                                suggestedAmount: radar.alerts.first.shortage,
                              ),
                            );
                            if (result == true) await viewModel.load();
                          },
                          icon: const Icon(Icons.credit_card_outlined, size: 18),
                          label: const Text('Planejar cobertura'),
                        ),
                      ),
                    ],
                  ] else ...[
                    Text(
                      'Sem risco de saldo ou limite no período analisado.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: .34),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _RadarMetric(
                                label: 'Menor saldo',
                                value: viewModel.hideAmounts
                                    ? '●●●●'
                                    : radar.minimumProjectedBalance.money,
                                icon: Icons.account_balance_wallet_outlined,
                                color: accent,
                              ),
                            ),
                            VerticalDivider(
                              width: 18,
                              color: scheme.outlineVariant.withValues(alpha: .55),
                            ),
                            Expanded(
                              child: _RadarMetric(
                                label: 'Data',
                                value: DateFormat('dd/MM').format(radar.minimumBalanceDate),
                                icon: Icons.event_outlined,
                                color: accent,
                              ),
                            ),
                            VerticalDivider(
                              width: 18,
                              color: scheme.outlineVariant.withValues(alpha: .55),
                            ),
                            Expanded(
                              child: _RadarMetric(
                                label: 'Horizonte',
                                value: horizon,
                                icon: Icons.schedule_rounded,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context.pushNamed(
                        FinancialAlertsPage.route,
                        extra: viewModel,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      label: Text(
                        hasAlerts ? 'Ver todos os alertas' : 'Ver projeção completa',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RadarMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _RadarMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AlertPreview extends StatelessWidget {
  final FinancialAlertEntity alert;
  final bool hideAmounts;
  final Color color;

  const _AlertPreview({
    required this.alert,
    required this.hideAmounts,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String date = DateFormat('dd/MM').format(alert.worstDate);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .12 : .06,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo insuficiente para pagamentos nesse dia.',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  hideAmounts
                      ? 'Risco identificado em $date.'
                      : 'Faltariam ${alert.shortage.money} até $date. ${alert.chargesCount == 0 ? 'O saldo disponível já está abaixo de zero.' : '${alert.chargesCount} cobrança${alert.chargesCount == 1 ? '' : 's'} considerada${alert.chargesCount == 1 ? '' : 's'} neste período.'}',
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (alert.recoveryDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'A projeção volta ao positivo em ${DateFormat('dd/MM').format(alert.recoveryDate!)}.',
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardLimitAlertPreview extends StatelessWidget {
  final CreditCardSafetyAlertEntity alert;
  final bool hideAmounts;
  final Color color;

  const _CardLimitAlertPreview({
    required this.alert,
    required this.hideAmounts,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool exceeded = alert.level == CreditCardSafetyAlertLevel.exceeded;

    final String title = alert.bankLimitExceeded
        ? 'Limite insuficiente no cartão ${alert.cardDescription} para esse compromisso nesse dia.'
        : exceeded
            ? 'Limite de segurança ultrapassado'
            : 'Atenção ao limite de ${alert.cardDescription}';

    final String detail;
    if (alert.bankLimitExceeded) {
      final String when = alert.riskDate == null
          ? 'na data planejada'
          : 'em ${DateFormat('dd/MM').format(alert.riskDate!)}';
      detail = hideAmounts
          ? 'Um planejamento não cabe no limite disponível $when.'
          : 'Faltam ${alert.bankShortage.money} de limite $when para ${alert.riskDescription ?? 'a operação planejada'}.';
    } else {
      detail = hideAmounts
          ? '${(alert.safetyRatio * 100).round()}% do limite de segurança comprometido.'
          : exceeded
              ? '${alert.cardDescription}: ${alert.amountOverSafety.money} acima do limite de segurança.'
              : '${(alert.safetyRatio * 100).round()}% do limite de segurança comprometido${alert.plannedAmount > 0 ? ' incluindo planejamentos' : ''}.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .12 : .06,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.speed_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
