import 'package:rallet/features/ad/domain/repositories/i_ad_access_repository.dart';
import 'package:rallet/features/ad/domain/use_cases/i_ad_access.dart';

/// Mantido apenas para compatibilidade com os casos de uso existentes.
/// O Rallet não exibe anúncios e não limita ações por quantidade de usos.
class AdAccess implements IAdAccess {
  AdAccess({required IAdAccessRepository repository});

  @override
  Future<void> consumeUse() async {}

  @override
  bool canShowAd() => false;

  @override
  Future<void> saveUsesRemaining() async {}
}
