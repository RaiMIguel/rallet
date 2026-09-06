import 'package:rallet/shared/infra/drivers/ad/i_ad_driver.dart';

/// Driver sem anúncios. Mantemos a interface para não alterar toda a arquitetura
/// que já depende de IAdDriver, mas nenhuma rede de publicidade é carregada.
class AdDriver implements IAdDriver {
  @override
  Future<void> loadInterstitialAd() async {}

  @override
  Future<void> showInterstitialAd({
    required void Function() onClose,
    required void Function() onError,
  }) async {
    onClose();
  }

  @override
  bool get hasInterstitialAd => false;
}
