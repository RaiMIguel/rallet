import 'dart:io';

import 'package:rallet/features/backup/domain/repositories/i_backup_repository.dart';
import 'package:rallet/features/backup/domain/use_cases/i_restore_backup.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';

class RestoreBackup implements IRestoreBackup {
  final IBackupRepository _repository;

  RestoreBackup({required IBackupRepository repository})
      : _repository = repository;

  @override
  Future<bool> restore() async {
    final File? file = await _repository.pickBackup();
    if (file == null) return false;

    // No Android o DocumentProvider pode entregar um caminho temporário sem a
    // extensão original. A validação real é feita abrindo o arquivo como SQLite.
    try {
      await _repository.restoreBackup(file);
      await _repository.acknowledgePendingBackup(file);
      return true;
    } on FormatException {
      await _repository.acknowledgePendingBackup(file);
      throw Exception(R.strings.selectFileInvalid);
    } catch (_) {
      await _repository.acknowledgePendingBackup(file);
      rethrow;
    }
  }
}
