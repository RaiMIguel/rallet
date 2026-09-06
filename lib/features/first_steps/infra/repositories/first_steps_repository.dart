import 'package:rallet/features/first_steps/domain/entities/first_steps_entity.dart';
import 'package:rallet/features/first_steps/domain/repositories/i_first_steps_repository.dart';
import 'package:rallet/features/first_steps/helpers/first_steps_factory.dart';
import 'package:rallet/features/first_steps/infra/data_sources/i_first_steps_local_data_source.dart';
import 'package:rallet/features/first_steps/infra/models/first_steps_model.dart';

class FirstStepsRepository implements IFirstStepsRepository {
  final IFirstStepsLocalDataSource _dataSource;

  FirstStepsRepository({required IFirstStepsLocalDataSource dataSource}) : _dataSource = dataSource;

  @override
  Future<FirstStepsEntity?> find() async {
    final FirstStepsModel? model = await _dataSource.findOne();

    return model != null ? FirstStepsFactory.toEntity(model: model) : null;
  }

  @override
  Future<FirstStepsEntity> save(FirstStepsEntity entity) async {
    final FirstStepsModel model = await _dataSource.upsert(FirstStepsFactory.fromEntity(entity));

    return FirstStepsFactory.toEntity(model: model);
  }
}
