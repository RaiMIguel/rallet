import 'dart:async';
import 'dart:io';

import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/backup/domain/repositories/i_backup_repository.dart';
import 'package:rallet/features/splash/presentation/ui/initial_splash_page.dart';
import 'package:rallet/shared/presentation/ui/app.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // O tempo mínimo passa a contar somente depois que a identidade completa
  // (logo + "by Rotecº") terminou o fade de entrada. Assim, 1 segundo significa
  // 1 segundo de marca realmente visível, e não 1 segundo desde o início do main().
  final Completer<void> brandVisible = Completer<void>();

  runApp(
    InitialSplashPage(
      onBrandVisible: () {
        if (!brandVisible.isCompleted) {
          brandVisible.complete();
        }
      },
    ),
  );

  final Future<void> initialization = Future.wait([
    AppLocale().load(),
    DependencyInjection().setup(),
  ]).then((_) async {
    await _restoreAndroidBackupSelectionInterruptedByProcessDeath();
  });

  await brandVisible.future;
  final Stopwatch visibleStopwatch = Stopwatch()..start();
  const Duration minimumVisibleDuration = Duration(seconds: 1);

  await initialization;

  final Duration remainingVisibleTime =
      minimumVisibleDuration - visibleStopwatch.elapsed;
  if (!remainingVisibleTime.isNegative) {
    await Future<void>.delayed(remainingVisibleTime);
  }

  runApp(const App());
}

Future<void> reset() async {
  await DependencyInjection().dispose();
  await main();
}

Future<void> _restoreAndroidBackupSelectionInterruptedByProcessDeath() async {
  if (!Platform.isAndroid) return;

  final IBackupRepository repository = DI.get<IBackupRepository>();
  final File? pendingBackup = await repository.findPendingBackup();
  if (pendingBackup == null) return;

  try {
    debugPrint(
      'Rallet: retomando backup selecionado após recriação do Android.',
    );
    await repository.restoreBackup(pendingBackup);
    await repository.acknowledgePendingBackup(pendingBackup);
    debugPrint('Rallet: restore retomado e concluído com sucesso.');
  } catch (error, stackTrace) {
    // Evita loop infinito no startup se o arquivo selecionado for inválido.
    await repository.acknowledgePendingBackup(pendingBackup);
    debugPrint('Rallet: falha ao retomar restore: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
