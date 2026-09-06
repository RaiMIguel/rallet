import 'package:flutter/material.dart';
import 'package:rallet/shared/presentation/ui/app.dart';

/// Identidade visual compartilhada das telas de inicialização do Rallet.
///
/// A marca inteira só fica visível depois que a imagem da raposa está pronta.
/// O callback [onVisible] é disparado somente quando o fade terminou, permitindo
/// que o startup conte o tempo mínimo a partir do momento em que logo, nome
/// e assinatura realmente estão visíveis na tela.
class RalletSplashBrand extends StatefulWidget {
  const RalletSplashBrand({
    super.key,
    this.onVisible,
  });

  final VoidCallback? onVisible;

  @override
  State<RalletSplashBrand> createState() => _RalletSplashBrandState();
}

class _RalletSplashBrandState extends State<RalletSplashBrand> {
  static const AssetImage _logo = AssetImage('assets/images/rallet_logo.png');

  bool _precacheStarted = false;
  bool _ready = false;
  bool _visibleNotified = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_precacheStarted) return;
    _precacheStarted = true;

    precacheImage(_logo, context).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  void _handleOpacityEnd() {
    if (!_ready || _visibleNotified) return;
    _visibleNotified = true;
    widget.onVisible?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 370,
      child: AnimatedOpacity(
        opacity: _ready ? 1 : 0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        onEnd: _handleOpacityEnd,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: _logo,
              width: 220,
            ),
            SizedBox(height: 16),
            Text(
              'Rallet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFF5ECE6),
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                height: 1,
              ),
            ),
            SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'by ',
                    style: TextStyle(
                      color: Color(0xFFB8AAA4),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.25,
                    ),
                  ),
                  TextSpan(
                    text: 'Rotecº',
                    style: TextStyle(
                      color: ralletOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.25,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
