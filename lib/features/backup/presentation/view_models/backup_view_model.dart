import 'dart:io';

import 'package:rallet/features/backup/domain/use_cases/i_backup.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:flutter/foundation.dart';

class BackupViewModel extends ChangeNotifier {
  final IBackup _backup;

  late final Command0 backupAndShare;

  BackupViewModel({required IBackup backup}) : _backup = backup {
    backupAndShare = Command0(_backupAndShare);
    _lastBackupDate = backup.findLastBackupDate();
  }

  DateTime? _lastBackupDate;

  DateTime? get lastBackupDate => _lastBackupDate;

  void setLastBackupDate(DateTime value) {
    _lastBackupDate = value;
    notifyListeners();
  }

  Future<void> _backupAndShare() async {
    // Gera um snapshot novo a cada solicitação.
    final File backupFile = await _backup.backup();

    if (!await _backup.shareBackup(backupFile)) throw Exception(R.strings.unsharedBackup);

    final DateTime now = DateTime.now();
    await _backup.saveLastBackupDate(now);
    setLastBackupDate(now);
  }
}
