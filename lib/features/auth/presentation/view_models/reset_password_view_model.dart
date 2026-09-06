import 'package:rallet/features/auth/domain/use_cases/i_reset_password.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/cupertino.dart';

class ResetPasswordViewModel extends ChangeNotifier {
  late final Command1<void, String> send;

  ResetPasswordViewModel({required IResetPassword resetPassword}) {
    send = Command1<void, String>(resetPassword.send);
  }
}
