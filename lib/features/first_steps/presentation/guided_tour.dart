import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// IDs dos pontos reais da interface usados pelo tour guiado.
abstract final class GuidedTourTargets {
  static const homeBalance = 'home-balance';
  static const homeRadar = 'home-radar';
  static const homeEconomy = 'home-economy';
  static const homeBill = 'home-bill';
  static const homeCustomize = 'home-customize';
  static const homeMenu = 'home-menu';

  static const transactionsFilters = 'transactions-filters';
  static const transactionsStatus = 'transactions-status';

  static const planningForm = 'planning-form';

  static const reportsMonth = 'reports-month';
  static const reportsPlannedVsRealized = 'reports-planned-vs-realized';
  static const reportsCustomize = 'reports-customize';
}

class GuidedTourStep {
  final String routeName;
  final String targetId;
  final IconData icon;
  final String title;
  final String description;
  final String? hint;
  final bool optional;

  const GuidedTourStep({
    required this.routeName,
    required this.targetId,
    required this.icon,
    required this.title,
    required this.description,
    this.hint,
    this.optional = false,
  });
}

/// Estado global e exclusivamente visual do tour.
///
/// Não toca no banco e não dispara ações financeiras. Ele apenas navega entre
/// as telas e posiciona um destaque sobre widgets reais registrados por
/// [GuidedTourTarget].
class GuidedTourController extends ChangeNotifier {
  GuidedTourController._();

  static final GuidedTourController instance = GuidedTourController._();

  final Map<String, GlobalKey> _targetKeys = <String, GlobalKey>{};

  static const List<GuidedTourStep> steps = <GuidedTourStep>[
    GuidedTourStep(
      routeName: 'home',
      targetId: GuidedTourTargets.homeBalance,
      icon: Icons.dashboard_rounded,
      title: 'Comece pela visão do mês',
      description:
          'Inicial, Atual e Previsto ajudam a entender de onde o mês partiu, onde você está e onde tende a chegar com os compromissos conhecidos.',
      hint: 'Troque o mês quando quiser enxergar passado e futuro sem sair da Home.',
    ),
    GuidedTourStep(
      routeName: 'home',
      targetId: GuidedTourTargets.homeRadar,
      icon: Icons.radar_rounded,
      title: 'Radar: veja o aperto antes dele chegar',
      description:
          'O Rallet cruza saldo, contas, faturas, planejamentos e limite dos cartões para encontrar datas futuras que merecem atenção.',
      hint: 'Sem riscos, ele também mostra por quantos meses a projeção segue segura.',
      optional: true,
    ),
    GuidedTourStep(
      routeName: 'home',
      targetId: GuidedTourTargets.homeEconomy,
      icon: Icons.savings_rounded,
      title: 'Economia mensal: leia o resultado',
      description:
          'O gráfico compara receitas e despesas consideradas no mês e resume o resultado como economia ou déficit.',
      hint: 'A mensagem abaixo do gráfico ajuda a interpretar o percentual.',
      optional: true,
    ),
    GuidedTourStep(
      routeName: 'home',
      targetId: GuidedTourTargets.homeBill,
      icon: Icons.credit_card_rounded,
      title: 'Acompanhe a fatura atual e futura',
      description:
          'Parcelas, operações vinculadas e compras planejadas aparecem na competência correta quando você navega pelos meses.',
      hint: 'Esse passo é pulado se não houver um cartão disponível para mostrar.',
      optional: true,
    ),
    GuidedTourStep(
      routeName: 'transactions-list',
      targetId: GuidedTourTargets.transactionsFilters,
      icon: Icons.receipt_long_rounded,
      title: 'Troque o contexto das Transações',
      description:
          'Use Todas, Receitas e Despesas para mudar tanto a lista quanto o resumo financeiro do mês selecionado.',
      hint: 'Receitas mostra A receber; Despesas mostra A pagar.',
    ),
    GuidedTourStep(
      routeName: 'transactions-list',
      targetId: GuidedTourTargets.transactionsStatus,
      icon: Icons.filter_alt_rounded,
      title: 'Separe realizadas, pendentes e planejadas',
      description:
          'Os filtros de status deixam claro o que já aconteceu, o que ainda falta pagar ou receber e o que continua apenas planejado.',
      hint: 'Os estados não mudam a origem do lançamento: eles ajudam a interpretar a lista.',
    ),
    GuidedTourStep(
      routeName: 'purchase-planning',
      targetId: GuidedTourTargets.planningForm,
      icon: Icons.event_note_rounded,
      title: 'Planeje antes de assumir o gasto',
      description:
          'Simule à vista ou parcelado. O Rallet avalia saldo, limite e compromissos futuros antes de você confirmar o planejamento.',
      hint: 'Um alerta orienta sua decisão, mas não bloqueia o planejamento.',
    ),
    GuidedTourStep(
      routeName: 'reports',
      targetId: GuidedTourTargets.reportsMonth,
      icon: Icons.calendar_month_rounded,
      title: 'Relatórios também seguem o mês',
      description:
          'Navegue entre os períodos para manter os gráficos e totais alinhados com o mês que você está analisando.',
      hint: 'Assim passado, presente e futuro não se misturam na leitura.',
      optional: true,
    ),
    GuidedTourStep(
      routeName: 'reports',
      targetId: GuidedTourTargets.reportsPlannedVsRealized,
      icon: Icons.analytics_rounded,
      title: 'Compare planejado e realizado',
      description:
          'Veja quanto estava previsto e quanto realmente aconteceu sem transformar a diferença em uma nova movimentação financeira.',
      hint: 'Abra as composições quando quiser conferir de onde veio um total.',
      optional: true,
    ),
    GuidedTourStep(
      routeName: 'reports',
      targetId: GuidedTourTargets.reportsCustomize,
      icon: Icons.dashboard_customize_outlined,
      title: 'Organize seus Relatórios',
      description:
          'Mostre, oculte e reorganize as seções para deixar primeiro aquilo que você consulta com mais frequência.',
      hint: 'A personalização é visual e não altera nenhum cálculo.',
      optional: true,
    ),
    GuidedTourStep(
      routeName: 'home',
      targetId: GuidedTourTargets.homeCustomize,
      icon: Icons.tune_rounded,
      title: 'Deixe a Home do seu jeito',
      description:
          'Oculte cards e mude a ordem sem apagar dados nem alterar as regras financeiras do Rallet.',
      hint: 'Você pode restaurar a organização padrão quando quiser.',
    ),
    GuidedTourStep(
      routeName: 'home',
      targetId: GuidedTourTargets.homeMenu,
      icon: Icons.menu_book_rounded,
      title: 'Reveja o tutorial quando quiser',
      description:
          'No menu lateral, Tutorial de funções abre novamente este tour e também o guia completo em páginas.',
      hint: 'O guia detalhado fica no menu e pode ser consultado quantas vezes você quiser.',
    ),
  ];

  bool _active = false;
  int _index = 0;
  List<GuidedTourStep> _activeSteps = steps;
  Future<void> Function()? _onFinished;

  bool get active => _active;
  int get index => _index;
  int get totalSteps => _activeSteps.length;
  GuidedTourStep get currentStep => _activeSteps[_index];
  bool get isFirst => _index == 0;
  bool get isLast => _index == _activeSteps.length - 1;

  GlobalKey targetKey(String id) =>
      _targetKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'tour-$id'));

  void start({
    Future<void> Function()? onFinished,
    Set<String> excludedTargetIds = const <String>{},
  }) {
    _onFinished = onFinished;
    _activeSteps = steps
        .where((step) => !excludedTargetIds.contains(step.targetId))
        .toList(growable: false);
    _index = 0;
    _active = _activeSteps.isNotEmpty;
    notifyListeners();
  }

  void next() {
    if (!_active) return;
    if (isLast) {
      finish();
      return;
    }
    _index++;
    notifyListeners();
  }

  void previous() {
    if (!_active || isFirst) return;
    _index--;
    notifyListeners();
  }

  Future<void> finish() async {
    if (!_active) return;
    final callback = _onFinished;
    _active = false;
    _onFinished = null;
    notifyListeners();
    if (callback != null) await callback();
  }

  Future<void> skip() => finish();
}

/// Registra um widget real como ponto de destaque do tour.
class GuidedTourTarget extends StatelessWidget {
  final String id;
  final Widget child;

  const GuidedTourTarget({
    super.key,
    required this.id,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: GuidedTourController.instance.targetKey(id),
      child: child,
    );
  }
}

class GuidedTourOverlay extends StatefulWidget {
  final Widget child;
  final GoRouter router;

  const GuidedTourOverlay({
    super.key,
    required this.child,
    required this.router,
  });

  @override
  State<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay>
    with WidgetsBindingObserver {
  final GuidedTourController controller = GuidedTourController.instance;
  final GlobalKey _overlayKey = GlobalKey(debugLabel: 'guided-tour-overlay');

  Rect? _targetRect;
  Timer? _retryTimer;
  int _retryCount = 0;
  int _stabilizationPass = 0;
  String? _lastRoute;
  int? _lastIndex;
  int? _lastEnsuredIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted || !controller.active) return;
    _scheduleTargetLookup(reset: true);
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (!controller.active) {
      _retryTimer?.cancel();
      setState(() {
        _targetRect = null;
        _lastIndex = null;
        _lastRoute = null;
        _lastEnsuredIndex = null;
        _stabilizationPass = 0;
      });
      return;
    }

    final step = controller.currentStep;
    final bool stepChanged = _lastIndex != controller.index;
    _lastIndex = controller.index;

    if (stepChanged) {
      setState(() => _targetRect = null);
    }

    if (_lastRoute != step.routeName) {
      _lastRoute = step.routeName;
      widget.router.goNamed(step.routeName);
    }

    _scheduleTargetLookup(reset: stepChanged);
    setState(() {});
  }

  void _scheduleTargetLookup({bool reset = false}) {
    if (reset) {
      _retryCount = 0;
      _stabilizationPass = 0;
    }
    _retryTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lookupTarget());
  }

  void _lookupTarget() {
    if (!mounted || !controller.active) return;

    final GlobalKey key = controller.targetKey(controller.currentStep.targetId);
    final BuildContext? targetContext = key.currentContext;
    final BuildContext? overlayContext = _overlayKey.currentContext;

    if (targetContext != null && overlayContext != null) {
      if (_lastEnsuredIndex != controller.index) {
        _lastEnsuredIndex = controller.index;
        Scrollable.ensureVisible(
          targetContext,
          alignment: .24,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ).whenComplete(() {
          if (!mounted || !controller.active) return;
          _retryTimer = Timer(const Duration(milliseconds: 45), _lookupTarget);
        });
        return;
      }

      final RenderObject? targetObject = targetContext.findRenderObject();
      final RenderObject? overlayObject = overlayContext.findRenderObject();

      if (targetObject is RenderBox &&
          overlayObject is RenderBox &&
          targetObject.hasSize &&
          overlayObject.hasSize) {
        // Mede o alvo diretamente no sistema de coordenadas do overlay. Isso
        // continua correto mesmo se algum ancestral aplicar transformação ou
        // deslocamento durante animações/layout assíncrono.
        final Offset topLeft = targetObject.localToGlobal(
          Offset.zero,
          ancestor: overlayObject,
        );
        final Offset bottomRight = targetObject.localToGlobal(
          targetObject.size.bottomRight(Offset.zero),
          ancestor: overlayObject,
        );
        final Rect overlayBounds = Offset.zero & overlayObject.size;
        final Rect rect = Rect.fromPoints(topLeft, bottomRight)
            .inflate(6)
            .intersect(overlayBounds);

        if (mounted) {
          setState(() => _targetRect = rect);
        }

        // Alguns cards terminam de carregar depois do primeiro frame e podem
        // mudar de tamanho/posição. Revalidamos por um curto período para o
        // spotlight não ficar preso em uma geometria antiga.
        if (_stabilizationPass < 8) {
          _stabilizationPass++;
          _retryTimer = Timer(
            const Duration(milliseconds: 180),
            _lookupTarget,
          );
        }
        return;
      }
    }

    if (_retryCount < 28) {
      _retryCount++;
      _retryTimer = Timer(
        const Duration(milliseconds: 70),
        _lookupTarget,
      );
      return;
    }

    if (controller.currentStep.optional) {
      controller.next();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _overlayKey,
      fit: StackFit.expand,
      children: [
        widget.child,
        if (controller.active) _buildTourLayer(context),
      ],
    );
  }

  Widget _buildTourLayer(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Rect? rect = _targetRect;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(
                target: rect,
                overlayColor: Colors.black.withValues(alpha: .72),
              ),
            ),
          ),
          if (rect != null)
            Positioned.fromRect(
              rect: rect,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.next,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: .22),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          _TourCallout(
            step: controller.currentStep,
            target: rect,
            index: controller.index,
            total: controller.totalSteps,
            isFirst: controller.isFirst,
            isLast: controller.isLast,
            onPrevious: controller.previous,
            onNext: controller.next,
            onSkip: controller.skip,
          ),
        ],
      ),
    );
  }
}

class _TourCallout extends StatelessWidget {
  final GuidedTourStep step;
  final Rect? target;
  final int index;
  final int total;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Future<void> Function() onSkip;

  const _TourCallout({
    required this.step,
    required this.target,
    required this.index,
    required this.total,
    required this.isFirst,
    required this.isLast,
    required this.onPrevious,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.viewPaddingOf(context);
    final double maxWidth = size.width > 422 ? 390.0 : size.width - 32;

    final double left = target == null
        ? (size.width - maxWidth) / 2
        : (target!.center.dx - maxWidth / 2)
            .clamp(16.0, size.width - maxWidth - 16)
            .toDouble();

    const double edgeGap = 12;
    const double targetGap = 16;
    const double minimumSideHeight = 300;

    final double safeTop = safe.top + edgeGap;
    final double safeBottom = size.height - safe.bottom - edgeGap;
    final double totalAvailableHeight =
        (safeBottom - safeTop).clamp(0.0, size.height).toDouble();

    double? top;
    double? bottom;
    late double maxHeight;
    bool alignToBottom = false;

    if (target == null) {
      // Enquanto o alvo ainda está sendo localizado, mantém o callout inteiro
      // dentro da área segura em vez de usar uma altura estimada.
      bottom = safe.bottom + edgeGap;
      alignToBottom = true;
      maxHeight = totalAvailableHeight > 520 ? 520 : totalAvailableHeight;
    } else {
      final double belowTop = target!.bottom + targetGap;
      final double aboveBottom = target!.top - targetGap;
      final double belowHeight = safeBottom - belowTop;
      final double aboveHeight = aboveBottom - safeTop;

      final bool belowFits = belowHeight >= minimumSideHeight;
      final bool aboveFits = aboveHeight >= minimumSideHeight;

      if (belowFits && (!aboveFits || target!.center.dy < size.height * .52)) {
        top = belowTop;
        maxHeight = belowHeight;
      } else if (aboveFits) {
        bottom = size.height - aboveBottom;
        alignToBottom = true;
        maxHeight = aboveHeight;
      } else {
        // Alvos muito altos podem não deixar espaço suficiente nem acima nem
        // abaixo. Nesse caso o callout vira um painel flutuante limitado pela
        // SafeArea; o conteúdo central rola, mas os botões permanecem visíveis.
        bottom = safe.bottom + edgeGap;
        alignToBottom = true;
        maxHeight = totalAvailableHeight > 520 ? 520 : totalAvailableHeight;
      }
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Positioned(
      left: left,
      width: maxWidth,
      top: top,
      bottom: bottom,
      child: Align(
        alignment: alignToBottom ? Alignment.bottomCenter : Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(22),
            color: scheme.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${index + 1} de $total',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => onSkip(),
                        child: const Text('Pular tour'),
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (index + 1) / total,
                      minHeight: 3,
                      backgroundColor:
                          scheme.outlineVariant.withValues(alpha: .45),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: .11),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  step.icon,
                                  size: 21,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  step.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        height: 1.08,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Text(
                            step.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                          ),
                          if (step.hint != null) ...[
                            const SizedBox(height: 9),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 17,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    step.hint!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (!isFirst) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onPrevious,
                            child: const Text('Voltar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: !isFirst ? 1 : 2,
                        child: FilledButton.icon(
                          onPressed: onNext,
                          icon: Icon(
                            isLast
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(isLast ? 'Concluir' : 'Próximo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? target;
  final Color overlayColor;

  const _SpotlightPainter({required this.target, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = overlayColor;
    final Path path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);

    if (target != null) {
      path.addRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(18)),
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.overlayColor != overlayColor;
}
