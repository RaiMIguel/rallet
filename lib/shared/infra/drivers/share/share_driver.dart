import 'dart:io';

import 'package:rallet/shared/infra/drivers/share/i_share_driver.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:share_plus/share_plus.dart';

class ShareDriver implements IShareDriver {
  @override
  Future<bool> shareFiles(List<File> files, {String? description}) async {
    try {
      final List<XFile> paths = files.map((file) => XFile(file.path)).toList();
      final ShareResult result = await Share.shareXFiles(paths, text: description);

      return result.status == ShareResultStatus.success;
    } catch (_) {
      throw Exception(R.strings.notPossibleShare);
    }
  }

  @override
  Future<bool> shareText(String text) async {
    try {
      final ShareResult result = await Share.shareWithResult(text);

      return result.status == ShareResultStatus.success;
    } catch (_) {
      throw Exception(R.strings.notPossibleShare);
    }
  }
}
