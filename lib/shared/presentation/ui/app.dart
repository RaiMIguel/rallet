import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/config/presentation/notifiers/locale_notifier.dart';
import 'package:rallet/features/config/presentation/notifiers/theme_mode_notifier.dart';
import 'package:rallet/features/first_steps/presentation/guided_tour.dart';
import 'package:rallet/shared/presentation/ui/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rallet/l10n/generated/app_localizations.dart';

const String appName = 'Rallet';
const String appVersion = '1.0.0-rc.2.17';

// Identidade Rallet.
const Color ralletOrange = Color(0xFFFF6A00);
const Color ralletLightBackground = Color(0xFFFFF5F2);
const Color ralletDarkBackground = Color(0xFF151210);

// Mantido por compatibilidade com telas que importam primaryColor.
const Color primaryColor = ralletOrange;

class App extends StatefulWidget {
  const App({super.key});

  static final ThemeModeNotifier themeNotifier = DI.get<ThemeModeNotifier>();
  static final LocaleNotifier localeNotifier = DI.get<LocaleNotifier>();

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final GoRouter routerConfig = AppRouter.routerConfig() as GoRouter;

  @override
  void initState() {
    super.initState();

    App.themeNotifier.find();
    App.localeNotifier.find();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([App.localeNotifier, App.themeNotifier]),
      builder: (_, __) {
        return MaterialApp.router(
          title: appName,
          debugShowCheckedModeBanner: false,
          routerConfig: routerConfig,
          themeMode: App.themeNotifier.value,
          theme: _buildTheme(themeLight),
          darkTheme: _buildTheme(themeDark),
          locale: App.localeNotifier.value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => GuidedTourOverlay(
            router: routerConfig,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          fixedSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          fixedSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          fixedSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          fixedSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(
          fixedSize: WidgetStatePropertyAll<Size>(Size.fromHeight(40)),
          padding: WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        space: 2,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.only(
          left: 16,
          top: 8,
          right: 24,
          bottom: 8,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.all(16),
      ),
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainer,
      ),
    );
  }

  ColorScheme get themeLight {
    final ColorScheme generated = ColorScheme.fromSeed(
      seedColor: ralletOrange,
      brightness: Brightness.light,
    );

    return generated.copyWith(
      primary: ralletOrange,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFE1D0),
      onPrimaryContainer: const Color(0xFF6A2800),
      secondary: const Color(0xFFE85D00),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFE9DE),
      onSecondaryContainer: const Color(0xFF642300),
      surface: ralletLightBackground,
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFFFBF9),
      surfaceContainer: const Color(0xFFFFFFFF),
      surfaceContainerHigh: const Color(0xFFFFEEE8),
      surfaceContainerHighest: const Color(0xFFFFE5DC),
      onSurface: const Color(0xFF2C2421),
      onSurfaceVariant: const Color(0xFF6D5B54),
      outline: const Color(0xFFD8C3BA),
      outlineVariant: const Color(0xFFEAD9D2),
    );
  }

  // Rallet — tema escuro em grafite quente + laranja.
  ColorScheme get themeDark {
    final ColorScheme generated = ColorScheme.fromSeed(
      seedColor: ralletOrange,
      brightness: Brightness.dark,
    );

    return generated.copyWith(
      primary: const Color(0xFFFF7A1A),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFF5C2800),
      onPrimaryContainer: const Color(0xFFFFDCC6),
      secondary: const Color(0xFFFFB074),
      onSecondary: const Color(0xFF3B1900),
      secondaryContainer: const Color(0xFF4B2A1A),
      onSecondaryContainer: const Color(0xFFFFDCC6),
      surface: ralletDarkBackground,
      surfaceContainerLowest: const Color(0xFF0F0D0C),
      surfaceContainerLow: const Color(0xFF1A1614),
      surfaceContainer: const Color(0xFF211C19),
      surfaceContainerHigh: const Color(0xFF29221F),
      surfaceContainerHighest: const Color(0xFF332A26),
      onSurface: const Color(0xFFFFF5F2),
      onSurfaceVariant: const Color(0xFFD8C6BE),
      outline: const Color(0xFF846F65),
      outlineVariant: const Color(0xFF4D403A),
    );
  }
}
