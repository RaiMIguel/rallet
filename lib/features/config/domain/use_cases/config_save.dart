import 'package:rallet/features/config/domain/repositories/i_config_repository.dart';
import 'package:rallet/features/config/domain/use_cases/i_config_save.dart';
import 'package:flutter/material.dart';

class ConfigSave implements IConfigSave {
  final IConfigRepository _repository;

  ConfigSave({required IConfigRepository repository}) : _repository = repository;

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) => _repository.saveThemeMode(themeMode);

  @override
  Future<void> saveLocale(Locale locale) => _repository.saveLocale(locale);

  @override
  Future<void> saveHideAmounts(bool hideAmounts) => _repository.saveHideAmounts(hideAmounts);

  @override
  Future<void> saveRadarMonths(int months) => _repository.saveRadarMonths(months.clamp(1, 24).toInt());

  @override
  Future<void> saveGreenPathMonths(int months) {
    final int normalized = months <= 6 ? 6 : months <= 12 ? 12 : 24;
    return _repository.saveGreenPathMonths(normalized);
  }
}
