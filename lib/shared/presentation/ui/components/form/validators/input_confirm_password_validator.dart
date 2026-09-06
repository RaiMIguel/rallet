import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:rallet/shared/presentation/ui/components/form/validators/i_input_validator.dart';

class InputConfirmPasswordValidator implements IInputValidator {
  final String? password;

  InputConfirmPasswordValidator(this.password);

  @override
  String? validate(String? value) {
    if (value != password) return R.strings.passwordsNotMatch;

    return null;
  }
}
