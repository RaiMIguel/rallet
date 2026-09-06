import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/first_steps/presentation/notifiers/first_steps_notifier.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/first_steps/presentation/guided_tour.dart';
import 'package:rallet/features/home/presentation/ui/home_page.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FirstStepsPage extends StatefulWidget {
  static const String route = 'first-steps';

  final bool firstShowing;

  const FirstStepsPage({super.key, required this.firstShowing});

  @override
  State<FirstStepsPage> createState() => _FirstStepsPageState();
}

class _FirstStepsPageState extends State<FirstStepsPage> with ThemeContext {
  final FirstStepsNotifier notifier = DI.get<FirstStepsNotifier>();
  final PageController _pageController = PageController();

  int _page = 0;
  bool _finishing = false;
  bool _showGuide = false;

  static const List<_TutorialStep> _steps = [
    _TutorialStep(
      icon: Icons.dashboard_rounded,
      title: 'Sua visão do mês',
      description:
          'A Home reúne as principais leituras do período para você entender rapidamente como o mês começou, como está agora e para onde tende a ir.',
      bullets: [
        'Use o seletor de mês para consultar passado, presente e futuro.',
        'Os cards respeitam o mês selecionado e cada um responde uma pergunta diferente.',
        'Saldo, fatura, Radar e economia se complementam sem representar a mesma coisa.',
      ],
      preview: _TutorialPreview.home,
    ),
    _TutorialStep(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Saldo atual x saldo previsto',
      description:
          'O saldo atual mostra o dinheiro disponível agora. O previsto estima onde você pode terminar o período com os compromissos conhecidos.',
      bullets: [
        'Atual parte dos saldos reais das contas incluídas no total.',
        'Previsto considera entradas e saídas futuras que já são conhecidas pelo Rallet.',
        'Previsão não é promessa: novos lançamentos alteram o resultado automaticamente.',
      ],
      preview: _TutorialPreview.home,
    ),
    _TutorialStep(
      icon: Icons.swap_vert_rounded,
      title: 'Receitas e despesas do período',
      description:
          'Receitas e despesas representam o resultado econômico do mês, enquanto entradas e saídas de caixa podem seguir datas diferentes.',
      bullets: [
        'Receita reconhece dinheiro que é renda; nem toda entrada em conta é receita.',
        'Despesa representa o gasto assumido sem duplicar pagamentos já reconhecidos.',
        'Os resumos ajudam a separar resultado do mês de movimentação de caixa.',
      ],
      preview: _TutorialPreview.transactions,
    ),
    _TutorialStep(
      icon: Icons.pending_actions_rounded,
      title: 'A receber e A pagar',
      description:
          'Esses valores mostram compromissos de caixa ainda pendentes no mês selecionado, e por isso podem ser diferentes de Receitas e Despesas.',
      bullets: [
        'A receber mostra entradas que ainda devem acontecer no período.',
        'A pagar reúne obrigações que ainda devem sair do caixa, como contas e faturas.',
        'Uma obrigação de caixa pode não criar uma nova despesa econômica.',
      ],
      preview: _TutorialPreview.transactions,
    ),
    _TutorialStep(
      icon: Icons.radar_rounded,
      title: 'Radar financeiro',
      description:
          'O Radar olha para frente e cruza saldo, compromissos, faturas, planejamentos e limite de cartões para procurar pontos de atenção.',
      bullets: [
        'Você escolhe o horizonte de projeção que deseja acompanhar.',
        'Sem riscos, o card informa por quantos meses a projeção segue segura.',
        'Com risco, o Rallet destaca a data e explica o que provocou o alerta.',
      ],
      preview: _TutorialPreview.radarEconomy,
    ),
    _TutorialStep(
      icon: Icons.savings_rounded,
      title: 'Economia mensal',
      description:
          'O gráfico circular transforma o resultado do mês em uma leitura rápida, comparando receitas e despesas consideradas no cálculo.',
      bullets: [
        'Resultado positivo indica que parte das receitas ficou livre no período.',
        'Resultado negativo indica que as despesas superaram as receitas consideradas.',
        'A mensagem do card ajuda a interpretar o percentual sem substituir os valores detalhados.',
      ],
      preview: _TutorialPreview.radarEconomy,
    ),
    _TutorialStep(
      icon: Icons.credit_card_rounded,
      title: 'Cartões e faturas',
      description:
          'O Rallet organiza compras do cartão pela fatura correta e acompanha o compromisso que será pago pela conta posteriormente.',
      bullets: [
        'A compra é reconhecida sem esperar o pagamento da fatura para existir.',
        'A fatura mostra a obrigação de caixa que será quitada na data de vencimento.',
        'Limite e valor da fatura são conceitos diferentes e são acompanhados separadamente.',
      ],
      preview: _TutorialPreview.card,
    ),
    _TutorialStep(
      icon: Icons.calendar_month_rounded,
      title: 'Parcelas e faturas futuras',
      description:
          'Compras parceladas e compromissos planejados são distribuídos para as competências futuras correspondentes.',
      bullets: [
        'Cada parcela aparece no mês da fatura em que deve ser cobrada.',
        'Ao navegar pelos meses, você consegue enxergar compromissos antes da fatura chegar.',
        'O Radar também usa esses valores para projetar saldo e limite.',
      ],
      preview: _TutorialPreview.card,
    ),
    _TutorialStep(
      icon: Icons.receipt_long_rounded,
      title: 'Transações e seus estados',
      description:
          'A tela de Transações diferencia o que já aconteceu, o que ainda está pendente e o que foi apenas planejado.',
      bullets: [
        'Realizada: a movimentação já foi efetivada.',
        'Pendente: existe, mas ainda falta pagar ou receber.',
        'Planejada: representa um compromisso futuro ainda não realizado.',
      ],
      preview: _TutorialPreview.transactions,
    ),
    _TutorialStep(
      icon: Icons.filter_alt_rounded,
      title: 'Filtros e resumos de Transações',
      description:
          'Use Todas, Receitas e Despesas para mudar o contexto da tela e depois refine a lista com os filtros de status.',
      bullets: [
        'Todas mantém uma visão geral do período.',
        'Receitas destaca receitas do mês e valores a receber.',
        'Despesas destaca despesas do mês e obrigações a pagar.',
      ],
      preview: _TutorialPreview.transactions,
    ),
    _TutorialStep(
      icon: Icons.event_note_rounded,
      title: 'Planejamento de despesas',
      description:
          'Planejar permite testar um compromisso antes de tratá-lo como gasto realizado.',
      bullets: [
        'Escolha data, valor, conta ou cartão e a forma de pagamento.',
        'O planejamento pode ser à vista ou parcelado.',
        'O Rallet mantém planejado separado de realizado para você comparar depois.',
      ],
      preview: _TutorialPreview.planning,
    ),
    _TutorialStep(
      icon: Icons.calculate_rounded,
      title: 'Simulação de saldo e limite',
      description:
          'Antes de confirmar um planejamento, o Rallet consegue mostrar o impacto esperado no caixa e no cartão.',
      bullets: [
        'Compromissos já conhecidos entram na simulação.',
        'Se faltar saldo ou limite, o app avisa sem bloquear sua decisão.',
        'O objetivo é mostrar consequência antes de você assumir o compromisso.',
      ],
      preview: _TutorialPreview.planning,
    ),
    _TutorialStep(
      icon: Icons.analytics_rounded,
      title: 'Relatórios que explicam os números',
      description:
          'Relatórios ajudam a entender composição, categorias, custos financeiros e evolução sem transformar toda movimentação em uma nova receita ou despesa.',
      bullets: [
        'Use o mês selecionado para manter a análise no período correto.',
        'Abra composições quando quiser entender de onde veio um total.',
        'Fluxo de caixa e resultado econômico são mostrados de acordo com o objetivo de cada visão.',
      ],
      preview: _TutorialPreview.reports,
    ),
    _TutorialStep(
      icon: Icons.compare_arrows_rounded,
      title: 'Planejado x realizado',
      description:
          'A comparação mostra o que você pretendia gastar e o que realmente aconteceu, ajudando a identificar desvios sem alterar os lançamentos originais.',
      bullets: [
        'Planejado permanece como referência do que estava previsto.',
        'Realizado usa o que efetivamente aconteceu.',
        'Diferença serve para análise e não cria uma nova movimentação financeira.',
      ],
      preview: _TutorialPreview.reports,
    ),
    _TutorialStep(
      icon: Icons.account_balance_rounded,
      title: 'Contas, cartões e categorias',
      description:
          'Esses cadastros são a base para organizar seus lançamentos e deixar os relatórios mais explicativos.',
      bullets: [
        'Contas representam onde seu dinheiro está.',
        'Cartões concentram compras, limite e faturas.',
        'Categorias ajudam a explicar para onde receitas e despesas estão indo.',
      ],
      preview: _TutorialPreview.accounts,
    ),
    _TutorialStep(
      icon: Icons.history_rounded,
      title: 'Histórico da conta e ajuste de saldo',
      description:
          'O histórico acompanha as movimentações que passaram pela conta e mostra como cada evento alterou o saldo.',
      bullets: [
        'O saldo após cada movimentação facilita a conferência do extrato.',
        'Operações vinculadas podem levar de volta à origem correspondente.',
        'Ajustar saldo serve para reconciliar a conta quando o valor real divergir do app.',
      ],
      preview: _TutorialPreview.accounts,
    ),
    _TutorialStep(
      icon: Icons.swap_horiz_rounded,
      title: 'Transferências entre suas contas',
      description:
          'Mover dinheiro entre duas contas suas muda onde o dinheiro está, mas não aumenta sua renda nem cria um novo gasto.',
      bullets: [
        'Uma conta perde saldo e a outra recebe o mesmo valor.',
        'O patrimônio total não muda apenas por causa da transferência.',
        'Por isso o Rallet trata a operação como neutra em receitas e despesas.',
      ],
      preview: _TutorialPreview.logic,
    ),
    _TutorialStep(
      icon: Icons.payments_rounded,
      title: 'Crédito recebido pelo cartão',
      description:
          'Quando você recebe dinheiro usando uma operação de crédito, o Rallet separa o dinheiro que entrou do custo financeiro criado pela operação.',
      bullets: [
        'O principal recebido aumenta o caixa, mas não é tratado como renda.',
        'O valor cobrado no cartão vira uma obrigação de pagamento.',
        'A diferença entre recebido e cobrado representa o custo financeiro.',
      ],
      preview: _TutorialPreview.logic,
    ),
    _TutorialStep(
      icon: Icons.receipt_rounded,
      title: 'Por que pagar a fatura não duplica a despesa',
      description:
          'A compra no cartão já representa o gasto. Quando a fatura é paga, ocorre a saída de caixa para quitar uma obrigação que já existia.',
      bullets: [
        'Compra no cartão: reconhece a despesa correspondente.',
        'Fatura a pagar: mostra a obrigação futura de caixa.',
        'Pagamento da fatura: quita a obrigação sem contar a mesma compra novamente.',
      ],
      preview: _TutorialPreview.logic,
    ),
    _TutorialStep(
      icon: Icons.tune_rounded,
      title: 'Personalize o Rallet',
      description:
          'Home e Relatórios podem ser reorganizados para destacar o que você realmente consulta no dia a dia.',
      bullets: [
        'Arraste para mudar a ordem das seções disponíveis.',
        'Oculte o que não quer ver sem apagar nenhum dado.',
        'Use Restaurar padrão se quiser voltar à organização original.',
      ],
      preview: _TutorialPreview.customization,
    ),
  ];

  bool get _isLastPage => _page == _steps.length - 1;

  int get _logicGuideIndex {
    final int index = _steps.indexWhere((step) => step.preview == _TutorialPreview.logic);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();

    if (widget.firstShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (notifier.value.done) {
          context.goNamed(HomePage.route);
          return;
        }
        _startGuidedTour();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.firstShowing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_showGuide) return _buildTutorialHub();
    return _buildGuideCarousel();
  }

  Widget _buildTutorialHub() {
    return PopScope(
      canPop: !widget.firstShowing,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.firstShowing,
          title: const Text('Tutorial de funções'),
          centerTitle: true,
          actions: [
            if (widget.firstShowing)
              TextButton(
                onPressed: _finishing ? null : _skip,
                child: const Text('Pular'),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withValues(alpha: .13),
                      colorScheme.surfaceContainerHigh,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: .18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: .11),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'GUIA RALLET',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.firstShowing
                          ? 'Entenda seu dinheiro em poucos minutos'
                          : 'Reveja o que torna o Rallet diferente',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Um tour pelas telas reais mostra Radar, previsão, economia mensal, faturas futuras, planejamento e relatórios sem alterar seus dados.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TutorialFeatureChip(icon: Icons.radar_rounded, label: 'Radar'),
                        _TutorialFeatureChip(icon: Icons.auto_graph_rounded, label: 'Previsões'),
                        _TutorialFeatureChip(icon: Icons.event_note_rounded, label: 'Planejamento'),
                        _TutorialFeatureChip(icon: Icons.analytics_rounded, label: 'Relatórios'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _finishing ? null : _startGuidedTour,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Iniciar tour interativo'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Explore no seu ritmo',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _TutorialActionCard(
                icon: Icons.menu_book_outlined,
                title: 'Guia visual completo',
                description: '20 capítulos com exemplos das telas, cálculos e conceitos do Rallet.',
                onTap: () => setState(() => _showGuide = true),
              ),
              const SizedBox(height: 10),
              _TutorialActionCard(
                icon: Icons.account_tree_outlined,
                title: 'Como o Rallet interpreta seu dinheiro',
                description: 'Entenda transferências, faturas, crédito e por que o app evita dupla contagem.',
                onTap: () => _openGuideAt(_logicGuideIndex),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: .55)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'O tutorial é apenas visual: não cria, altera nem apaga transações, contas, faturas ou planejamentos.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openGuideAt(int index) {
    setState(() {
      _showGuide = true;
      _page = index.clamp(0, _steps.length - 1).toInt();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) _pageController.jumpToPage(_page);
    });
  }

  Widget _buildGuideCarousel() {
    return PopScope(
      canPop: !widget.firstShowing,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          leading: IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => _showGuide = false),
          ),
          title: const Text('Guia completo'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Fazer tour guiado',
              icon: const Icon(Icons.touch_app_outlined),
              onPressed: _startGuidedTour,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (_, index) => _TutorialStepView(
                    step: _steps[index],
                    page: index + 1,
                    total: _steps.length,
                  ),
                ),
              ),
              _buildPageIndicator(),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (_page + 1) / _steps.length,
                minHeight: 6,
                backgroundColor: colorScheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_page + 1}/${_steps.length}',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (_page > 0) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _finishing ? null : _previous,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: _page > 0 ? 1 : 2,
            child: FilledButton.icon(
              onPressed: _finishing ? null : (_isLastPage ? _finish : _next),
              icon: _finishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isLastPage
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
              label: Text(
                _isLastPage
                    ? (widget.firstShowing ? 'Começar a usar' : 'Concluir')
                    : 'Próximo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startGuidedTour() async {
    bool hasCreditCard = false;

    try {
      final ICreditCardFind creditCardFind = DI.get<ICreditCardFind>();
      final creditCards = await creditCardFind.findAll();
      hasCreditCard = creditCards.isNotEmpty;
    } catch (error, stackTrace) {
      // Se não for possível consultar os cartões, é mais seguro ocultar esse
      // passo do que deixar o tour procurar um alvo que não existe na Home.
      debugPrint(
        'Rallet guided tour: failed to check credit cards: $error\n$stackTrace',
      );
    }

    if (!mounted) return;

    GuidedTourController.instance.start(
      onFinished: widget.firstShowing ? _markTutorialDone : null,
      // Estrutura de decisão: o passo da fatura só entra no tour quando existe
      // ao menos um cartão cadastrado. Vale tanto para o primeiro acesso quanto
      // para o tour iniciado manualmente pelo menu.
      excludedTargetIds: hasCreditCard
          ? const <String>{}
          : const {GuidedTourTargets.homeBill},
    );

    context.goNamed(HomePage.route);
  }

  Future<void> _markTutorialDone() async {
    if (notifier.value.done) return;
    notifier.value.done = true;
    await notifier.save();
  }

  Future<void> _next() async {
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _previous() async {
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skip() => _completeTutorial(goHome: true);

  Future<void> _finish() => _completeTutorial(goHome: widget.firstShowing);

  Future<void> _completeTutorial({required bool goHome}) async {
    if (_finishing) return;

    setState(() => _finishing = true);

    try {
      await _markTutorialDone();

      if (!mounted) return;

      if (goHome) {
        context.goNamed(HomePage.route);
      } else {
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }
}

class _TutorialFeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TutorialFeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: scheme.primary.withValues(alpha: .13)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TutorialActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _TutorialActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialStepView extends StatelessWidget {
  final _TutorialStep step;
  final int page;
  final int total;

  const _TutorialStepView({
    required this.step,
    required this.page,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return LayoutBuilder(
      builder: (_, constraints) {
        final bool compactHeight = constraints.maxHeight < 590;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, compactHeight ? 12 : 24, 20, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$page de $total',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'Rallet',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compactHeight ? 14 : 24),
                  Center(
                    child: Container(
                      width: compactHeight ? 70 : 82,
                      height: compactHeight ? 70 : 82,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        step.icon,
                        size: compactHeight ? 34 : 40,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  SizedBox(height: compactHeight ? 14 : 20),
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    step.description,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: compactHeight ? 16 : 22),
                  _TutorialMiniPreview(type: step.preview),
                  SizedBox(height: compactHeight ? 14 : 20),
                  ...step.bullets.map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bullet,
                              style: textTheme.bodyMedium?.copyWith(height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TutorialMiniPreview extends StatelessWidget {
  final _TutorialPreview type;

  const _TutorialMiniPreview({required this.type});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: switch (type) {
        _TutorialPreview.home => _homePreview(context),
        _TutorialPreview.radarEconomy => _radarEconomyPreview(context),
        _TutorialPreview.transactions => _transactionsPreview(context),
        _TutorialPreview.planning => _planningPreview(context),
        _TutorialPreview.card => _cardPreview(context),
        _TutorialPreview.reports => _reportsPreview(context),
        _TutorialPreview.accounts => _accountsPreview(context),
        _TutorialPreview.logic => _logicPreview(context),
        _TutorialPreview.customization => _customizationPreview(context),
      },
    );
  }

  Widget _homePreview(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _metric(context, 'Inicial', 'R\$ 2.100', Icons.flag_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _metric(context, 'Atual', 'R\$ 1.886', Icons.account_balance_wallet_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _metric(context, 'Previsto', 'R\$ 2.241', Icons.auto_graph_rounded)),
          ],
        ),
        const SizedBox(height: 10),
        _line(context, 'Fatura prevista', 'R\$ 550,00', Icons.credit_card_rounded),
      ],
    );
  }

  Widget _transactionsPreview(BuildContext context) {
    return Column(
      children: [
        _line(context, 'Salário estágio', '+ R\$ 1.000,00', Icons.south_west_rounded),
        const SizedBox(height: 8),
        _line(context, 'Internet', '- R\$ 95,00', Icons.north_east_rounded),
        const SizedBox(height: 8),
        _line(context, 'Internet nova', '- R\$ 30,00', Icons.schedule_rounded),
      ],
    );
  }

  Widget _planningPreview(BuildContext context) {
    return Column(
      children: [
        _line(context, 'Notebook', '3x de R\$ 450', Icons.shopping_bag_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _tag(context, 'Saldo simulado')),
            const SizedBox(width: 8),
            Expanded(child: _tag(context, 'Limite projetado')),
          ],
        ),
      ],
    );
  }

  Widget _radarEconomyPreview(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: .68,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              Text(
                '32%',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              _line(context, 'Radar', '6 meses OK', Icons.radar_rounded),
              const SizedBox(height: 8),
              _line(context, 'Economia', '32% livre', Icons.savings_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _line(context, 'Fatura prevista', 'R\$ 550,00', Icons.credit_card_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _tag(context, 'Fechamento')),
            const SizedBox(width: 8),
            Expanded(child: _tag(context, 'Limite')),
            const SizedBox(width: 8),
            Expanded(child: _tag(context, 'Parcelas')),
          ],
        ),
      ],
    );
  }

  Widget _reportsPreview(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _metric(context, 'Despesas', 'R\$ 1.165', Icons.pie_chart_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _metric(context, 'Planejado', 'R\$ 1.230', Icons.event_available_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _metric(context, 'Custo', 'R\$ 50', Icons.percent_rounded)),
      ],
    );
  }

  Widget _accountsPreview(BuildContext context) {
    return Column(
      children: [
        _line(context, 'Conta principal', 'R\$ 1.886,75', Icons.account_balance_rounded),
        const SizedBox(height: 8),
        _line(context, 'Após Internet', 'R\$ 1.791,75', Icons.history_rounded),
      ],
    );
  }

  Widget _logicPreview(BuildContext context) {
    return Column(
      children: [
        _logicRow(context, 'Transferência', 'Neutra', Icons.swap_horiz_rounded),
        const SizedBox(height: 8),
        _logicRow(context, 'Pagamento da fatura', 'Sem duplicar despesa', Icons.receipt_long_rounded),
        const SizedBox(height: 8),
        _logicRow(context, 'Crédito', 'Custo separado', Icons.link_rounded),
      ],
    );
  }

  Widget _customizationPreview(BuildContext context) {
    return Column(
      children: [
        _dragRow(context, 'Radar financeiro', true),
        const SizedBox(height: 8),
        _dragRow(context, 'Fatura do cartão', true),
        const SizedBox(height: 8),
        _dragRow(context, 'Economia do mês', false),
      ],
    );
  }

  Widget _metric(BuildContext context, String label, String value, IconData icon) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value, IconData icon) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Text(value, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _tag(BuildContext context, String label) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall,
      ),
    );
  }

  Widget _logicRow(BuildContext context, String title, String detail, IconData icon) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        Text(detail, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _dragRow(BuildContext context, String title, bool visible) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.drag_indicator_rounded, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        Icon(
          visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: visible ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _TutorialStep {
  final IconData icon;
  final String title;
  final String description;
  final List<String> bullets;
  final _TutorialPreview preview;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.bullets,
    required this.preview,
  });
}

enum _TutorialPreview {
  home,
  radarEconomy,
  transactions,
  planning,
  card,
  reports,
  accounts,
  logic,
  customization,
}
