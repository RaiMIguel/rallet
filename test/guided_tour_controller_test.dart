import 'package:rallet/features/first_steps/presentation/guided_tour.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guided tour navigates steps and finishes without financial state', () async {
    final controller = GuidedTourController.instance;
    var finished = 0;

    controller.start(onFinished: () async => finished++);

    expect(controller.active, isTrue);
    expect(controller.index, 0);
    expect(controller.currentStep.targetId, GuidedTourTargets.homeBalance);
    expect(GuidedTourController.steps.any((step) => step.targetId == GuidedTourTargets.homeRadar), isTrue);
    expect(GuidedTourController.steps.any((step) => step.targetId == GuidedTourTargets.homeEconomy), isTrue);
    expect(GuidedTourController.steps.length, 12);
    expect(GuidedTourController.steps.any((step) => step.targetId == GuidedTourTargets.homeBill && step.optional), isTrue);
    expect(GuidedTourController.steps.any((step) => step.targetId == GuidedTourTargets.reportsPlannedVsRealized), isTrue);
    expect(GuidedTourController.steps.any((step) => step.targetId == GuidedTourTargets.transactionsStatus), isTrue);
    expect(GuidedTourController.steps.any((step) => step.targetId == GuidedTourTargets.reportsMonth), isTrue);

    controller.next();
    expect(controller.index, 1);

    controller.previous();
    expect(controller.index, 0);

    while (!controller.isLast) {
      controller.next();
    }

    await controller.finish();

    expect(controller.active, isFalse);
    expect(finished, 1);
  });
}
