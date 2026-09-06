import 'package:rallet/features/credit_card/infra/models/credit_card_model.dart';
import 'package:rallet/shared/infra/data_sources/i_local_data_source.dart';

abstract interface class ICreditCardLocalDataSource implements ILocalDataSource<CreditCardModel> {}
