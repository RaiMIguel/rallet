import 'package:rallet/features/purchase_planning/infra/models/planned_purchase_model.dart';
import 'package:rallet/shared/infra/data_sources/i_local_data_source.dart';

abstract interface class IPurchasePlanningLocalDataSource
    implements ILocalDataSource<PlannedPurchaseModel> {}
