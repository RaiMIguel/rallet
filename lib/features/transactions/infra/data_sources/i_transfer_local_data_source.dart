import 'package:rallet/features/transactions/infra/models/transfer_model.dart';
import 'package:rallet/shared/infra/data_sources/i_local_data_source.dart';

abstract interface class ITransferLocalDataSource implements ILocalDataSource<TransferModel> {}
