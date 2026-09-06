import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/extensions/string_extension.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:rallet/shared/presentation/ui/components/form/validators/i_input_validator.dart';

class InputGreaterThanValueValidator implements IInputValidator {
  final double value;

  InputGreaterThanValueValidator(this.value);

  @override
  String? validate(String? input) {
    final String raw = input?.trim() ?? '';
    if (raw.isEmpty || !RegExp(r'\d').hasMatch(raw)) {
      return R.strings.invalidValue;
    }

    final double valueNum = raw.moneyToDouble();
    if (valueNum <= value) {
      return '${R.strings.greaterThan} ${value.removeTrailingZeros()}.';
    }

    return null;
  }
}
