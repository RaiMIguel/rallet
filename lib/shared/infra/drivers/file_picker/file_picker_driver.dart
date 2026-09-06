import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:rallet/shared/infra/drivers/file_picker/i_file_picker_driver.dart';
import 'package:flutter/services.dart';

class FilePickerDriver implements IFilePickerDriver {
  // Canal interno legado mantido por compatibilidade com o picker Android
  // validado antes do rebranding para Rallet.
  static const MethodChannel _androidBackupPickerChannel =
      MethodChannel('rallet/backup_picker');

  @override
  Future<File?> pickFile({required List<String>? allowedExtensions}) async {
    if (Platform.isAndroid) {
      final String? selectedPath = await _androidBackupPickerChannel
          .invokeMethod<String>('pickBackupFile');
      if (selectedPath == null || selectedPath.isEmpty) return null;
      return File(selectedPath);
    }

    final FilePickerResult? filePicker = await FilePicker.platform.pickFiles(
      lockParentWindow: true,
      allowMultiple: false,
      allowedExtensions: Platform.isWindows ? allowedExtensions : null,
      type: Platform.isWindows ? FileType.custom : FileType.any,
    );

    if (filePicker == null) return null;

    final String? selectedPath = filePicker.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty) return null;

    return File(selectedPath);
  }

  @override
  Future<File?> findPendingFile() async {
    if (!Platform.isAndroid) return null;

    final String? path = await _androidBackupPickerChannel
        .invokeMethod<String>('findPendingBackupFile');
    if (path == null || path.isEmpty) return null;

    final File file = File(path);
    if (!await file.exists()) {
      await _androidBackupPickerChannel
          .invokeMethod<void>('discardPendingBackupFile');
      return null;
    }

    return file;
  }

  @override
  Future<void> acknowledgePendingFile(File file) async {
    if (!Platform.isAndroid) return;

    await _androidBackupPickerChannel.invokeMethod<void>(
      'acknowledgePendingBackupFile',
      file.path,
    );
  }
}
