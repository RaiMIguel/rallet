import 'package:rallet/features/card_cash_advance/infra/models/card_cash_advance_plan_model.dart';
import 'package:rallet/shared/infra/data_sources/i_local_data_source.dart';

abstract interface class ICardCashAdvanceLocalDataSource
    implements ILocalDataSource<CardCashAdvancePlanModel> {}
