import 'package:rallet/features/first_steps/domain/entities/first_steps_entity.dart';

abstract interface class IFirstStepsFind {
  Future<FirstStepsEntity?> find();
}