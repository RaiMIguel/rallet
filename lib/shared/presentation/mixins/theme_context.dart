import 'package:flutter/material.dart';
import 'package:rallet/l10n/generated/app_localizations.dart';

mixin ThemeContext<T extends StatefulWidget> on State<T> {
  ThemeData get theme => Theme.of(context);

  ColorScheme get colorScheme => theme.colorScheme;

  TextTheme get textTheme => theme.textTheme;

  AppLocalizations get strings => AppLocalizations.of(context)!;
}
