import 'dart:io';

import 'package:rallet/features/config/domain/repositories/i_config_repository.dart';
import 'package:rallet/features/config/domain/use_cases/i_config_find.dart';
import 'package:flutter/material.dart';

class ConfigFind implements IConfigFind {
  final IConfigRepository _repository;

  ConfigFind({required IConfigRepository repository}) : _repository = repository;

  @override
  ThemeMode findThemeMode() {
    final ThemeMode? themeMode = _repository.findThemeMode();

    return themeMode ?? ThemeMode.dark;
  }

  @override
  Locale findLocale() {
    final Locale? locale = _repository.findLocale();

    return locale ?? Locale(Platform.localeName.split('_').first);
  }

  @override
  bool findHideAmounts() {
    final bool? hideAmounts = _repository.findHideAmounts();

    return hideAmounts ?? false;
  }

  @override
  int findRadarMonths() {
    final int months = _repository.findRadarMonths() ?? 6;
    return months.clamp(1, 24).toInt();
  }

  @override
  int findGreenPathMonths() {
    // Na primeira utilização, herda o horizonte já escolhido no Radar.
    // Depois disso o relatório mantém sua própria preferência 6/12/24.
    final int months =
        _repository.findGreenPathMonths() ?? _repository.findRadarMonths() ?? 6;
    if (months <= 6) return 6;
    if (months <= 12) return 12;
    return 24;
  }
}
