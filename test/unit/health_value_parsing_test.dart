import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthDataPoint parsing', () {
    test('parses numeric health data points', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.HEART_RATE,
        HealthFixtures.numericPoint(),
        null,
      );

      expect(point.type, HealthDataType.HEART_RATE);
      expect(point.value, isA<NumericHealthValue>());
      final value = point.value as NumericHealthValue;
      expect(value.numericValue, 72);
    });

    test('parses workout health data points', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.WORKOUT,
        HealthFixtures.workoutPoint(),
        HealthDataUnit.NO_UNIT.name,
      );

      expect(point.type, HealthDataType.WORKOUT);
      expect(point.value, isA<WorkoutHealthValue>());
      final value = point.value as WorkoutHealthValue;
      expect(value.workoutActivityType, HealthWorkoutActivityType.RUNNING);
      expect(value.totalEnergyBurned, 200);
      expect(value.totalDistance, 5000);
    });

    test('parses workout route health data points', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.WORKOUT_ROUTE,
        HealthFixtures.workoutRoutePoint(),
        HealthDataUnit.NO_UNIT.name,
      );

      expect(point.type, HealthDataType.WORKOUT_ROUTE);
      expect(point.value, isA<WorkoutRouteHealthValue>());
      final value = point.value as WorkoutRouteHealthValue;
      expect(value.locations, hasLength(1));
      expect(value.workoutUuid, 'workout-uuid-1');
      expect(value.locations.first.latitude, 37.3349);
    });

    for (final type in [
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    ]) {
      test('parses body position and measurement location for ${type.name}', () {
        final point = HealthDataPoint.fromHealthDataPoint(
          type,
          {
            ...HealthFixtures.numericPoint(value: 120),
            'body_position': 3,
            'measurement_location': 2,
          },
          HealthDataUnit.MILLIMETER_OF_MERCURY.name,
        );

        expect(point.value, isA<BloodPressureHealthValue>());
        final value = point.value as BloodPressureHealthValue;
        expect(value.numericValue, 120);
        expect(value.bodyPosition, BloodPressureBodyPosition.lyingDown);
        expect(value.measurementLocation,
            BloodPressureMeasurementLocation.rightWrist);
      });
    }

    test('parses missing blood pressure context as unknown', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthFixtures.numericPoint(value: 120),
        HealthDataUnit.MILLIMETER_OF_MERCURY.name,
      );

      final value = point.value as BloodPressureHealthValue;
      expect(value.bodyPosition, BloodPressureBodyPosition.unknown);
      expect(value.measurementLocation,
          BloodPressureMeasurementLocation.unknown);
    });

    test('blood pressure value survives a JSON round trip', () {
      final value = BloodPressureHealthValue(
        numericValue: 80,
        bodyPosition: BloodPressureBodyPosition.reclining,
        measurementLocation: BloodPressureMeasurementLocation.rightUpperArm,
      );

      expect(BloodPressureHealthValue.fromJson(value.toJson()), value);
    });
  });

  group('Blood pressure enums', () {
    test('body position maps to and from Android values', () {
      const expected = {
        BloodPressureBodyPosition.unknown: 0,
        BloodPressureBodyPosition.standingUp: 1,
        BloodPressureBodyPosition.sittingDown: 2,
        BloodPressureBodyPosition.lyingDown: 3,
        BloodPressureBodyPosition.reclining: 4,
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(key.toAndroidValue(), value);
        expect(BloodPressureBodyPosition.fromAndroidValue(value), key);
      }
      expect(BloodPressureBodyPosition.fromAndroidValue(99),
          BloodPressureBodyPosition.unknown);
      expect(BloodPressureBodyPosition.fromAndroidValue(null),
          BloodPressureBodyPosition.unknown);
    });

    test('measurement location maps to and from Android values', () {
      const expected = {
        BloodPressureMeasurementLocation.unknown: 0,
        BloodPressureMeasurementLocation.leftWrist: 1,
        BloodPressureMeasurementLocation.rightWrist: 2,
        BloodPressureMeasurementLocation.leftUpperArm: 3,
        BloodPressureMeasurementLocation.rightUpperArm: 4,
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(key.toAndroidValue(), value);
        expect(BloodPressureMeasurementLocation.fromAndroidValue(value), key);
      }
      expect(BloodPressureMeasurementLocation.fromAndroidValue(99),
          BloodPressureMeasurementLocation.unknown);
    });
  });
}
