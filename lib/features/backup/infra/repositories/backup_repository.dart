import 'dart:io';

import 'package:rallet/features/backup/domain/repositories/i_backup_repository.dart';
import 'package:rallet/shared/infra/data_sources/cache_local/i_cache_local.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local.dart';
import 'package:rallet/shared/infra/drivers/file_picker/i_file_picker_driver.dart';
import 'package:rallet/shared/infra/drivers/share/i_share_driver.dart';
import 'package:path_provider/path_provider.dart';

class BackupRepository implements IBackupRepository {
  final IDatabaseLocal _databaseLocal;
  final ICacheLocal _cacheLocal;
  final IShareDriver _shareDriver;
  final IFilePickerDriver _filePickerDriver;

  BackupRepository({
    required IDatabaseLocal databaseLocal,
    required ICacheLocal cacheLocal,
    required IShareDriver shareDriver,
    required IFilePickerDriver filePickerDriver,
  })  : _databaseLocal = databaseLocal,
        _cacheLocal = cacheLocal,
        _shareDriver = shareDriver,
        _filePickerDriver = filePickerDriver;

  static const String lastBackupDateKey = 'last_backup_date';

  @override
  Future<File> backup() async {
    final Directory tempDirectory = await getTemporaryDirectory();
    final DateTime now = DateTime.now();
    final String timestamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final String destinationPath =
        '${tempDirectory.path}/Rallet_backup_$timestamp.db';

    return _databaseLocal.createDatabaseBackup(destinationPath);
  }

  @override
  Future<void> restoreBackup(File file) =>
      _databaseLocal.restoreDatabaseBackup(file);

  @override
  Future<void> saveLastBackupDate(DateTime dateTime) =>
      _cacheLocal.save(lastBackupDateKey, dateTime.toIso8601String());

  @override
  DateTime? findLastBackupDate() =>
      DateTime.tryParse(_cacheLocal.get(lastBackupDateKey) ?? '')?.toLocal();

  @override
  Future<bool> shareBackup(File backupFile) =>
      _shareDriver.shareFiles([backupFile]);

  @override
  Future<File?> pickBackup() =>
      _filePickerDriver.pickFile(allowedExtensions: ['db']);

  @override
  Future<File?> findPendingBackup() => _filePickerDriver.findPendingFile();

  @override
  Future<void> acknowledgePendingBackup(File file) =>
      _filePickerDriver.acknowledgePendingFile(file);
}
