import 'package:rallet/features/splash/presentation/ui/components/rallet_splash_brand.dart';
import 'package:rallet/shared/presentation/ui/app.dart';
import 'package:flutter/material.dart';

class InitialSplashPage extends StatelessWidget {
  const InitialSplashPage({
    super.key,
    this.onBrandVisible,
  });

  final VoidCallback? onBrandVisible;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
      ),
      home: _SplashPage(onBrandVisible: onBrandVisible),
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage({this.onBrandVisible});

  final VoidCallback? onBrandVisible;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ralletDarkBackground,
      body: SafeArea(
        child: Center(
          child: RalletSplashBrand(onVisible: onBrandVisible),
        ),
      ),
    );
  }
}
