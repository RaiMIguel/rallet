import 'package:rallet/features/backup/domain/use_cases/i_restore_backup.dart';
import 'package:rallet/shared/domain/domain/i_delete_app_data.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/cupertino.dart';

class RestoreBackupViewModel extends ChangeNotifier {
  late final Command0<bool> restoreBackup;
  late final Command0<void> deleteAppData;

  RestoreBackupViewModel({
    required IRestoreBackup restoreBackup,
    required IDeleteAppData deleteAppData,
  }) {
    this.restoreBackup = Command0<bool>(restoreBackup.restore);
    this.deleteAppData = Command0<void>(deleteAppData.delete);
  }

  bool get isLoading => restoreBackup.running || deleteAppData.running;
}
