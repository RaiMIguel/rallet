import 'dart:io';

import 'package:rallet/features/backup/domain/repositories/i_backup_repository.dart';
import 'package:rallet/features/backup/domain/use_cases/restore_backup.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AppLocale().load();
  });

  test('cancelar seletor retorna false e nao executa restore', () async {
    final repository = _FakeBackupRepository(selectedFile: null);
    final restore = RestoreBackup(repository: repository);

    final bool restored = await restore.restore();

    expect(restored, isFalse);
    expect(repository.restoreCalls, 0);
  });

  test('caminho temporario sem extensao e aceito e validado pelo repository', () async {
    final repository = _FakeBackupRepository(
      selectedFile: File('/tmp/document-provider-cache-file'),
    );
    final restore = RestoreBackup(repository: repository);

    final bool restored = await restore.restore();

    expect(restored, isTrue);
    expect(repository.restoreCalls, 1);
    expect(repository.acknowledgeCalls, 1);
  });

  test('erro inesperado de restore e propagado e limpa o temporario', () async {
    final repository = _FakeBackupRepository(
      selectedFile: File('/tmp/backup-valido'),
      restoreError: StateError('falha simulada'),
    );
    final restore = RestoreBackup(repository: repository);

    await expectLater(restore.restore(), throwsA(isA<StateError>()));
    expect(repository.restoreCalls, 1);
    expect(repository.acknowledgeCalls, 1);
  });

  test('backup SQLite invalido vira erro de arquivo invalido', () async {
    final repository = _FakeBackupRepository(
      selectedFile: File('/tmp/arquivo-invalido'),
      restoreError: const FormatException('invalido'),
    );
    final restore = RestoreBackup(repository: repository);

    await expectLater(
      restore.restore(),
      throwsA(
        predicate(
          (Object error) =>
              error.toString().contains(R.strings.selectFileInvalid),
        ),
      ),
    );

    expect(repository.acknowledgeCalls, 1);
  });
}

class _FakeBackupRepository implements IBackupRepository {
  final File? selectedFile;
  final Object? restoreError;

  int restoreCalls = 0;
  int acknowledgeCalls = 0;

  _FakeBackupRepository({
    required this.selectedFile,
    this.restoreError,
  });

  @override
  Future<File?> pickBackup() async => selectedFile;

  @override
  Future<File?> findPendingBackup() async => null;

  @override
  Future<void> acknowledgePendingBackup(File file) async {
    acknowledgeCalls++;
  }

  @override
  Future<void> restoreBackup(File file) async {
    restoreCalls++;
    if (restoreError != null) throw restoreError!;
  }

  @override
  Future<File> backup() => throw UnimplementedError();

  @override
  DateTime? findLastBackupDate() => null;

  @override
  Future<void> saveLastBackupDate(DateTime dateTime) async {}

  @override
  Future<bool> shareBackup(File backupFile) async => true;
}
