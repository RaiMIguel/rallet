import 'package:rallet/features/transactions/domain/entities/transfer_entity.dart';

abstract interface class ITransferSave {
  Future<TransferEntity> save(TransferEntity entity);
}
