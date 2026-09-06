import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/reports/domain/entities/report_financial_explanation_entity.dart';
import 'package:rallet/features/reports/domain/entities/reports_dashboard_entity.dart';
import 'package:rallet/features/reports/presentation/view_models/reports_dashboard_view_model.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FinancialResultExplanationPage extends StatefulWidget {
  static const String route = 'financial-result-explanation';

  final DateTime initialMonth;

  const FinancialResultExplanationPage({
    super.key,
    required this.initialMonth,
  });

  @override
  State<FinancialResultExplanationPage> createState() =>
      _FinancialResultExplanationPageState();
}

class _FinancialResultExplanationPageState
    extends State<FinancialResultExplanationPage> {
  final ReportsDashboardViewModel viewModel = DI.get<ReportsDashboardViewModel>();

  @override
  void initState() {
    super.initState();
    viewModel.initialize(initialMonth: widget.initialMonth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entenda o resultado'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([viewModel, viewModel.loadDashboard]),
          builder: (_, __) {
            final previous = viewModel.loadDashboard.previous;

            if (viewModel.loadDashboard.running && previous?.completed != true) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.loadDashboard.hasError && previous?.completed != true) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    viewModel.loadDashboard.error
                        .toString()
                        .replaceAll('Exception: ', ''),
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              );
            }

            final ReportsDashboardEntity? data =
                viewModel.loadDashboard.result ?? previous?.result;
            if (data == null) return const SizedBox.shrink();

            return _ExplanationContent(data: data);
          },
        ),
      ),
    );
  }
}

class _ExplanationContent extends StatelessWidget {
  final ReportsDashboardEntity data;

  const _ExplanationContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final ReportFinancialExplanationEntity explanation =
        data.financialExplanation;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String monthLabel = DateFormat('MMMM yyyy', 'pt_BR')
        .format(explanation.month);
    final String formattedMonth =
        monthLabel[0].toUpperCase() + monthLabel.substring(1);
    final double indicatorDifference = explanation.economyPendingDifference;
    final bool legacyCase =
        explanation.shouldExplainPositiveEconomyWithNegativePendingCash;
    final bool differentReadings = explanation.shouldExplainEconomyVsPending;
    final List<_DiagnosisCaseData> diagnosisCases =
        _buildDiagnosisCases(explanation);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Text(
          'O que aconteceu neste mês?',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          formattedMonth,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        _DiagnosisHeader(
          explanation: explanation,
          caseCount: diagnosisCases.length,
        ),
        if (diagnosisCases.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...diagnosisCases.expand(
            (item) => [
              _DiagnosisCaseCard(data: item),
              const SizedBox(height: 10),
            ],
          ),
        ],
        if (differentReadings) ...[
          _InfoPanel(
            icon: Icons.compare_arrows_rounded,
            title: 'Os dois números realmente estão contando momentos diferentes',
            body: legacyCase
                ? 'Neste mês ainda há mais dinheiro a pagar do que a receber, mas a Economia mensal ficou positiva. Os casos reais acima mostram quais lançamentos são de caixa, quais pertencem à competência do mês e quais não podem ser contados duas vezes.'
                : 'A diferença entre A receber e A pagar é ${explanation.cashPendingBalance.money}, enquanto a Economia mensal é ${explanation.savings.money}. A diferença de ${indicatorDifference.money} não é tratada como um valor escondido: os lançamentos reais acima mostram por que cada indicador enxerga o mês de um jeito diferente.',
            accent: scheme.primary,
          ),
          const SizedBox(height: 12),
        ],
        _InfoPanel(
          icon: Icons.account_balance_wallet_outlined,
          title: 'O que cada número responde',
          body:
              'A receber e A pagar respondem quanto ainda falta entrar ou sair. A Economia mensal responde qual é o resultado atribuído ao mês. Ela pode incluir despesas ainda não pagas, compras do cartão pela competência da fatura e planejamentos aplicáveis ao período. Por isso ela não é simplesmente saldo final menos saldo inicial.',
          accent: scheme.primary,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '1. O que ainda falta movimentar',
          subtitle:
              'Fluxo de caixa pendente. Aqui entram somente obrigações e entradas que ainda precisam acontecer.',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricBox(
                      label: 'A receber',
                      value: explanation.cashReceivable,
                      color: const Color(0xFF2CC985),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricBox(
                      label: 'A pagar',
                      value: explanation.cashPayable,
                      color: const Color(0xFFE34B42),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _EquationRow(
                label: 'Saldo do que ainda falta movimentar',
                value: explanation.cashPendingBalance,
                positiveColor: const Color(0xFF2CC985),
                negativeColor: const Color(0xFFE34B42),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '2. O resultado econômico do mês',
          subtitle:
              'Esta é a conta usada pela Economia mensal. Ela considera o que pertence ao mês e também os planejamentos aplicáveis ao período, mesmo quando o dinheiro ainda não entrou ou saiu da conta.',
          child: Column(
            children: [
              _EquationRow(
                label: 'Receitas economicamente consideradas',
                value: explanation.economicIncomes,
                positiveColor: const Color(0xFF2CC985),
              ),
              const SizedBox(height: 8),
              _EquationRow(
                label: 'Despesas economicamente consideradas',
                value: -explanation.economicExpenses,
                negativeColor: const Color(0xFFE34B42),
              ),
              const Divider(height: 24),
              _EquationRow(
                label: 'Economia mensal',
                value: explanation.savings,
                positiveColor: scheme.primary,
                negativeColor: const Color(0xFFE34B42),
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '3. Por que os dois resultados são diferentes?',
          subtitle: differentReadings
              ? 'A diferença entre as duas leituras é ${indicatorDifference.money}. Isso não significa que exista um valor oculto de ${indicatorDifference.money}; significa que A receber/A pagar e Economia mensal usam bases diferentes.'
              : 'Fluxo de caixa pendente e resultado econômico medem coisas diferentes. A diferença entre eles não deve ser interpretada como erro ou como um lançamento escondido.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (differentReadings) ...[
                _EquationRow(
                  label: 'A receber - A pagar',
                  value: explanation.cashPendingBalance,
                  positiveColor: const Color(0xFF2CC985),
                  negativeColor: const Color(0xFFE34B42),
                ),
                const SizedBox(height: 8),
                _EquationRow(
                  label: 'Economia mensal',
                  value: explanation.savings,
                  positiveColor: scheme.primary,
                  negativeColor: const Color(0xFFE34B42),
                ),
                const SizedBox(height: 8),
                _EquationRow(
                  label: 'Diferença entre as duas leituras',
                  value: indicatorDifference,
                  positiveColor: scheme.primary,
                  emphasized: true,
                ),
                const Divider(height: 24),
              ],
              const _RuleLine(
                icon: Icons.schedule_rounded,
                title: 'A receber / A pagar',
                text:
                    'Pergunta: quanto ainda falta entrar ou sair? Uma receita já recebida deixa de estar em A receber, mas continua sendo receita econômica do mês. Uma despesa já paga deixa de estar em A pagar, mas continua sendo despesa econômica do mês.',
              ),
              const SizedBox(height: 12),
              const _RuleLine(
                icon: Icons.receipt_long_outlined,
                title: 'Fatura do cartão',
                text:
                    'A fatura em aberto é uma obrigação real de caixa. Porém o pagamento não cria outra despesa: as compras e os custos da fatura já foram reconhecidos economicamente, evitando dupla contagem.',
              ),
              const SizedBox(height: 12),
              const _RuleLine(
                icon: Icons.credit_card_rounded,
                title: 'Crédito recebido pelo cartão',
                text:
                    'O principal recebido aumenta o caixa, mas cria uma dívida equivalente. Portanto não é renda. Na visão econômica, somente juros e taxas são custo.',
              ),
              const SizedBox(height: 12),
              const _RuleLine(
                icon: Icons.swap_horiz_rounded,
                title: 'Transferências',
                text:
                    'Mover dinheiro entre suas próprias contas não aumenta nem reduz seu patrimônio. É movimento de caixa, não receita nem despesa econômica.',
              ),
              const SizedBox(height: 12),
              const _RuleLine(
                icon: Icons.event_note_outlined,
                title: 'Planejamentos',
                text:
                    'Planejamentos entram nas projeções do mês para antecipar custos e compromissos. O Rallet os identifica como planejados para não confundir previsão com realização.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ReconciliationCard(explanation: explanation),
        const SizedBox(height: 16),
        _AuditSection(
          title: 'Receitas econômicas usadas no cálculo',
          description:
              'São as receitas cadastradas para o mês, recebidas ou ainda pendentes. Elas aumentam o resultado econômico.',
          items: explanation.economicIncomeItems,
          emptyText: 'Nenhuma receita econômica considerada neste mês.',
          accent: const Color(0xFF2CC985),
        ),
        const SizedBox(height: 12),
        _AuditSection(
          title: 'Despesas econômicas usadas no cálculo',
          description:
              'Inclui despesas comuns, compras do cartão pela competência da fatura, custos financeiros e planejamentos aplicáveis ao mês.',
          items: explanation.economicExpenseItems,
          emptyText: 'Nenhuma despesa econômica considerada neste mês.',
          accent: const Color(0xFFE34B42),
        ),
        const SizedBox(height: 12),
        _AuditSection(
          title: 'O que compõe A receber',
          description:
              'Entradas que ainda precisam acontecer. Algumas são receita econômica; crédito via cartão pode entrar no caixa sem ser renda.',
          items: explanation.cashReceivableItems,
          emptyText: 'Não há entradas pendentes para este período.',
          accent: const Color(0xFF2CC985),
        ),
        const SizedBox(height: 12),
        _AuditSection(
          title: 'O que compõe A pagar',
          description:
              'Obrigações que ainda exigem caixa: despesas pendentes, faturas abertas, cobranças previstas de crédito e despesas planejadas.',
          items: explanation.cashPayableItems,
          emptyText: 'Não há obrigações pendentes para este período.',
          accent: const Color(0xFFE34B42),
        ),
        const SizedBox(height: 12),
        _AuditSection(
          title: 'Movimentos que não viram nova receita ou despesa',
          description:
              'Aqui aparecem movimentos encontrados no mês que alteram caixa ou posição das contas, mas recebem tratamento econômico diferente para evitar distorções.',
          items: explanation.nonEconomicItems,
          emptyText:
              'Nenhum movimento neutro ou de tratamento especial foi encontrado neste mês. Mesmo assim, A receber/A pagar podem diferir da Economia porque mostram somente o que ainda está pendente.',
          accent: scheme.primary,
        ),
        const SizedBox(height: 12),
        _InfoPanel(
          icon: Icons.verified_outlined,
          title: 'Regra de confiança do Rallet',
          body: explanation.isFullyReconciled
              ? 'Os totais usados nesta explicação fecham entre si, item por item, com tolerância de 1 centavo. Isso confirma a composição deste relatório. Não é uma prova isolada de que o saldo bancário está correto; por isso o Rallet mostra acima os lançamentos reais que podem fazer caixa e Economia mensal acontecerem em momentos diferentes.'
              : 'O Rallet não conseguiu reconciliar todos os totais até os centavos. Por segurança, esta tela não afirma que o cálculo está conferido. Revise os detalhes acima antes de confiar na explicação.',
          accent: explanation.isFullyReconciled
              ? scheme.primary
              : scheme.error,
        ),
      ],
    );
  }

  List<_DiagnosisCaseData> _buildDiagnosisCases(
    ReportFinancialExplanationEntity explanation,
  ) {
    final List<_DiagnosisCaseData> cases = [];

    void addCase({
      required ReportAuditCase caseType,
      required List<ReportAuditItem> source,
      required IconData icon,
      required String Function(double total, int count) title,
      required String body,
    }) {
      final List<ReportAuditItem> items = source
          .where((item) => item.caseType == caseType)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (items.isEmpty) return;
      final double total = items
          .fold(0.0, (sum, item) => sum + item.amount.abs())
          .toRound(2);
      cases.add(
        _DiagnosisCaseData(
          icon: icon,
          title: title(total, items.length),
          body: body,
          items: items,
        ),
      );
    }

    addCase(
      caseType: ReportAuditCase.billPayment,
      source: explanation.nonEconomicItems,
      icon: Icons.receipt_long_outlined,
      title: (total, count) =>
          'Saiu ${total.money} para pagar fatura, sem criar outra despesa',
      body:
          'Esse dinheiro saiu da conta neste mês, mas o pagamento da fatura não é uma nova despesa do mês. As compras e custos da fatura já são atribuídos à competência da própria fatura. Se ela reúne compras de outro período, o caixa pode cair agora sem o mesmo valor ser descontado novamente da Economia mensal.',
    );

    addCase(
      caseType: ReportAuditCase.plannedExpense,
      source: explanation.economicExpenseItems,
      icon: Icons.event_note_outlined,
      title: (total, count) =>
          '${total.money} são despesas planejadas, ainda não necessariamente realizadas',
      body:
          'Esses valores entram na visão do mês como previsão de custo. Eles podem reduzir a Economia mensal antes de o dinheiro realmente sair da conta. Se você estiver comparando com o saldo bancário, este é um dos motivos mais importantes para os números parecerem fora de sincronia.',
    );

    addCase(
      caseType: ReportAuditCase.cardCreditObligation,
      source: explanation.nonEconomicItems,
      icon: Icons.link_rounded,
      title: (total, count) =>
          '${total.money} em obrigações têm origem em crédito vinculado',
      body:
          'Aqui o Rallet liga a obrigação à entrada que a criou. Assim você consegue ver em qual mês o dinheiro entrou, em qual fatura a dívida ficou e por que o principal não deve ser contado como renda na entrada nem como uma segunda despesa quando a fatura for paga.',
    );

    addCase(
      caseType: ReportAuditCase.plannedCardCharge,
      source: explanation.cashPayableItems,
      icon: Icons.credit_card_outlined,
      title: (total, count) =>
          '${total.money} envolvem cobranças planejadas de crédito/cartão',
      body:
          'A cobrança prevista pressiona o caixa futuro, mas o principal do crédito não vira nova despesa econômica. No resultado entram somente os custos que realmente representam juros ou taxas, evitando contar o principal duas vezes.',
    );

    addCase(
      caseType: ReportAuditCase.creditCardPurchase,
      source: explanation.economicExpenseItems,
      icon: Icons.credit_card_rounded,
      title: (total, count) =>
          '${total.money} em compras/custos de cartão pertencem a este mês',
      body:
          'Essas despesas são reconhecidas pela competência da fatura. Elas podem reduzir a Economia mensal antes de o pagamento da fatura sair da conta. Quando a fatura for paga, o Rallet não cria uma segunda despesa.',
    );

    addCase(
      caseType: ReportAuditCase.pendingExpense,
      source: explanation.cashPayableItems,
      icon: Icons.schedule_rounded,
      title: (total, count) =>
          '${total.money} já contam como despesa, mas ainda não foram pagos',
      body:
          'Essas despesas já pertencem ao resultado deste mês, mesmo que o dinheiro ainda esteja na conta. Por isso a Economia mensal pode piorar antes de você enxergar a mesma queda no saldo.',
    );

    addCase(
      caseType: ReportAuditCase.pendingIncome,
      source: explanation.cashReceivableItems,
      icon: Icons.schedule_outlined,
      title: (total, count) =>
          '${total.money} já contam como receita, mas ainda não foram recebidos',
      body:
          'Essas receitas pertencem ao mês e aumentam a Economia mensal, porém ainda não aumentaram o saldo da conta. Enquanto estiverem pendentes, resultado econômico e caixa naturalmente ficam em momentos diferentes.',
    );

    addCase(
      caseType: ReportAuditCase.openBill,
      source: explanation.cashPayableItems,
      icon: Icons.account_balance_wallet_outlined,
      title: (total, count) =>
          'Há ${total.money} em faturas abertas que ainda exigem caixa',
      body:
          'A fatura em aberto aparece em A pagar porque ainda precisa ser quitada. Ela não é somada novamente como nova despesa econômica, pois as compras e custos que a formaram já foram reconhecidos na competência correspondente.',
    );

    addCase(
      caseType: ReportAuditCase.cardCreditPrincipal,
      source: explanation.nonEconomicItems,
      icon: Icons.south_west_rounded,
      title: (total, count) =>
          '${total.money} de entrada via cartão não são tratados como renda',
      body:
          'O principal recebido aumenta ou pode aumentar o caixa, mas cria uma obrigação no cartão. Cada item abaixo agora mostra a origem e a data da fatura vinculada: a entrada pertence ao caixa do mês em que foi recebida, enquanto a obrigação aparece na competência da fatura. O principal não melhora a Economia como salário e não vira nova despesa ao ser pago; somente juros e taxas são custo econômico.',
    );

    addCase(
      caseType: ReportAuditCase.transfer,
      source: explanation.nonEconomicItems,
      icon: Icons.swap_horiz_rounded,
      title: (total, count) =>
          '${total.money} apenas mudaram de uma conta sua para outra',
      body:
          'Transferências alteram o saldo de cada conta individual, mas não o seu resultado econômico total. O Rallet as mantém fora de receitas e despesas para não fabricar ganho ou perda.',
    );

    return cases;
  }
}

class _DiagnosisCaseData {
  final IconData icon;
  final String title;
  final String body;
  final List<ReportAuditItem> items;

  const _DiagnosisCaseData({
    required this.icon,
    required this.title,
    required this.body,
    required this.items,
  });
}

class _DiagnosisHeader extends StatelessWidget {
  final ReportFinancialExplanationEntity explanation;
  final int caseCount;

  const _DiagnosisHeader({
    required this.explanation,
    required this.caseCount,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool ok = explanation.isFullyReconciled;
    final String body;

    if (caseCount > 0 && ok) {
      final String countLabel =
          caseCount == 1 ? '1 situação real' : '$caseCount situações reais';
      body =
          'Antes de concluir que existe uma conta errada, o Rallet encontrou $countLabel neste mês em que o dinheiro entra ou sai em um momento diferente daquele usado no resultado econômico. Os totais desta explicação também fecham até 1 centavo. Veja os lançamentos encontrados logo abaixo.';
    } else if (caseCount > 0) {
      body =
          'O Rallet encontrou movimentos reais que podem explicar a diferença entre caixa e Economia mensal. Porém a conferência interna dos totais não fechou completamente; trate o resultado como algo a revisar, não como uma explicação definitiva.';
    } else if (ok) {
      body =
          'Os totais desta explicação fecham até 1 centavo, mas não foi encontrado um movimento especial dominante. A diferença pode vir apenas do momento entre receitas/despesas já atribuídas ao mês e valores que ainda estão pendentes.';
    } else {
      body =
          'Não foi possível fechar completamente a composição do relatório. Neste caso o Rallet não tenta convencer você de que a diferença é normal: revise os lançamentos detalhados abaixo.';
    }

    return _InfoPanel(
      icon: ok ? Icons.search_rounded : Icons.warning_amber_rounded,
      title: caseCount > 0
          ? 'Diagnóstico com os seus lançamentos reais'
          : 'Conferência do seu mês',
      body: body,
      accent: ok ? scheme.primary : scheme.error,
    );
  }
}

class _DiagnosisCaseCard extends StatelessWidget {
  final _DiagnosisCaseData data;

  const _DiagnosisCaseCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<ReportAuditItem> preview = data.items.take(3).toList();
    final int remaining = data.items.length - preview.length;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, size: 19, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.body,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          ...preview.map((item) => _DiagnosisItemLine(item: item)),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'E mais $remaining lançamento${remaining == 1 ? '' : 's'} deste mesmo tipo. Todos aparecem na auditoria detalhada abaixo.',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiagnosisItemLine extends StatelessWidget {
  final ReportAuditItem item;

  const _DiagnosisItemLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String date = DateFormat('dd/MM').format(item.date);

    final String? related = item.relatedDate == null
        ? null
        : '${item.relatedDateLabel ?? 'Relacionado'}: ${DateFormat('dd/MM/yyyy').format(item.relatedDate!)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.subdirectory_arrow_right_rounded,
              size: 17,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$date • ${item.description}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (item.originLabel != null || related != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (item.originLabel != null) item.originLabel!,
                      if (related != null) related,
                    ].join('  •  '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.amount.abs().money,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReconciliationCard extends StatelessWidget {
  final ReportFinancialExplanationEntity explanation;

  const _ReconciliationCard({required this.explanation});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool ok = explanation.isFullyReconciled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.verified_outlined : Icons.warning_amber_rounded,
                  color: ok ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ok ? 'Cálculo conferido' : 'Conferência incompleta',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CheckRow(
              label: 'Receitas econômicas',
              expected: explanation.economicIncomes,
              detailed: explanation.economicIncomeItemsTotal,
              ok: explanation.isEconomicIncomeCompositionConsistent,
            ),
            _CheckRow(
              label: 'Despesas econômicas',
              expected: explanation.economicExpenses,
              detailed: explanation.economicExpenseItemsTotal,
              ok: explanation.isEconomicExpenseCompositionConsistent,
            ),
            _CheckRow(
              label: 'A receber',
              expected: explanation.cashReceivable,
              detailed: explanation.cashReceivableItemsTotal,
              ok: explanation.isCashReceivableCompositionConsistent,
            ),
            _CheckRow(
              label: 'A pagar',
              expected: explanation.cashPayable,
              detailed: explanation.cashPayableItemsTotal,
              ok: explanation.isCashPayableCompositionConsistent,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final double expected;
  final double detailed;
  final bool ok;

  const _CheckRow({
    required this.label,
    required this.expected,
    required this.detailed,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: ok ? scheme.primary : scheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            '${detailed.money} / ${expected.money}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _AuditSection extends StatelessWidget {
  final String title;
  final String description;
  final List<ReportAuditItem> items;
  final String emptyText;
  final Color accent;

  const _AuditSection({
    required this.title,
    required this.description,
    required this.items,
    required this.emptyText,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
                child: Text(
                  emptyText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else
              ...items.map(
                (item) => _AuditItemTile(item: item, accent: accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuditItemTile extends StatelessWidget {
  final ReportAuditItem item;
  final Color accent;

  const _AuditItemTile({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String date = DateFormat('dd/MM/yyyy').format(item.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .11),
            shape: BoxShape.circle,
          ),
          child: Icon(_iconFor(item.treatment), size: 17, color: accent),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.amount.abs().money,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: accent),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(date),
            if (item.planned) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Planejado',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _treatmentLabel(item.treatment),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          if (item.originLabel != null || item.relatedDate != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.originLabel != null)
                      Text(
                        item.originLabel!,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    if (item.relatedDate != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${item.relatedDateLabel ?? 'Relacionado'}: ${DateFormat('dd/MM/yyyy').format(item.relatedDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.reason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }


  String _treatmentLabel(ReportAuditTreatment treatment) {
    switch (treatment) {
      case ReportAuditTreatment.economicIncome:
        return 'CONSIDERADO COMO RECEITA ECONÔMICA';
      case ReportAuditTreatment.economicExpense:
        return 'CONSIDERADO COMO DESPESA ECONÔMICA';
      case ReportAuditTreatment.cashInflowNotIncome:
        return 'ENTRADA DE CAIXA • NÃO É RECEITA';
      case ReportAuditTreatment.cashOutflowNotNewExpense:
        return 'SAÍDA/OBRIGAÇÃO DE CAIXA • NÃO É NOVA DESPESA';
      case ReportAuditTreatment.neutral:
        return 'MOVIMENTO NEUTRO';
    }
  }

  IconData _iconFor(ReportAuditTreatment treatment) {
    switch (treatment) {
      case ReportAuditTreatment.economicIncome:
        return Icons.south_west_rounded;
      case ReportAuditTreatment.economicExpense:
        return Icons.north_east_rounded;
      case ReportAuditTreatment.cashInflowNotIncome:
        return Icons.credit_card_rounded;
      case ReportAuditTreatment.cashOutflowNotNewExpense:
        return Icons.receipt_long_outlined;
      case ReportAuditTreatment.neutral:
        return Icons.swap_horiz_rounded;
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value.abs().money,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquationRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? positiveColor;
  final Color? negativeColor;
  final bool emphasized;

  const _EquationRow({
    required this.label,
    required this.value,
    this.positiveColor,
    this.negativeColor,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color valueColor = value > 0
        ? (positiveColor ?? scheme.onSurface)
        : value < 0
            ? (negativeColor ?? scheme.onSurface)
            : scheme.onSurfaceVariant;
    final String formatted = value > 0
        ? '+${value.abs().money}'
        : value < 0
            ? '-${value.abs().money}'
            : value.abs().money;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasized
                ? Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w800)
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatted,
          style: (emphasized
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.bodyMedium)
              ?.copyWith(color: valueColor, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _RuleLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _RuleLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .09),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
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
