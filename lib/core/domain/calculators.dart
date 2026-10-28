/// Pure business rules shared by screens and tests.
library;

/// Capacity configuration (`operational_configs/{wh}`).
class CapacityConfig {
  const CapacityConfig({
    required this.capacityRider,
    required this.capacityDriver,
    required this.capacityOpInbound,
    required this.capacityOpOutbound,
    required this.ratioRider,
    required this.ratioDriver,
  });

  static const defaults = CapacityConfig(
    capacityRider: 350,
    capacityDriver: 800,
    capacityOpInbound: 500,
    capacityOpOutbound: 600,
    ratioRider: 0.70,
    ratioDriver: 0.30,
  );

  final num capacityRider;
  final num capacityDriver;
  final num capacityOpInbound;
  final num capacityOpOutbound;
  final double ratioRider;
  final double ratioDriver;

  Map<String, Object> toMap() => {
        'capacity_rider': capacityRider,
        'capacity_driver': capacityDriver,
        'capacity_op_inbound': capacityOpInbound,
        'capacity_op_outbound': capacityOpOutbound,
        'ratio_rider': ratioRider,
        'ratio_driver': ratioDriver,
      };

  @override
  bool operator ==(Object other) =>
      other is CapacityConfig &&
      other.capacityRider == capacityRider &&
      other.capacityDriver == capacityDriver &&
      other.capacityOpInbound == capacityOpInbound &&
      other.capacityOpOutbound == capacityOpOutbound &&
      other.ratioRider == ratioRider &&
      other.ratioDriver == ratioDriver;

  @override
  int get hashCode =>
      Object.hash(capacityRider, capacityDriver, capacityOpInbound, capacityOpOutbound, ratioRider, ratioDriver);
}

/// Headcount per category.
class ManpowerCounts {
  const ManpowerCounts({required this.rider, required this.driver, required this.opInbound, required this.opOutbound});

  final int rider;
  final int driver;
  final int opInbound;
  final int opOutbound;

  int get total => rider + driver + opInbound + opOutbound;

  Map<String, int> toMap() => {'rider': rider, 'driver': driver, 'op_inbound': opInbound, 'op_outbound': opOutbound};

  ManpowerCounts copyWith({int? rider, int? driver, int? opInbound, int? opOutbound}) => ManpowerCounts(
        rider: rider ?? this.rider,
        driver: driver ?? this.driver,
        opInbound: opInbound ?? this.opInbound,
        opOutbound: opOutbound ?? this.opOutbound,
      );

  @override
  bool operator ==(Object other) =>
      other is ManpowerCounts &&
      other.rider == rider &&
      other.driver == driver &&
      other.opInbound == opInbound &&
      other.opOutbound == opOutbound;

  @override
  int get hashCode => Object.hash(rider, driver, opInbound, opOutbound);

  @override
  String toString() => 'ManpowerCounts($rider/$driver/$opInbound/$opOutbound)';
}

/// Manpower formula (always rounded up). Used in the app only for the
/// Konfigurasi impact preview; the stored recommendation comes from the script.
class ManpowerCalculator {
  ManpowerCalculator._();

  /// Small epsilon so that floating point noise (e.g. 350.00000000001)
  /// does not push an exact multiple to the next integer.
  static const _eps = 1e-9;

  static int _ceil(double v) => (v - _eps).ceil();

  static ManpowerCounts compute(num predicted, CapacityConfig c) {
    final p = predicted.toDouble();
    return ManpowerCounts(
      rider: _ceil(p * c.ratioRider / c.capacityRider),
      driver: _ceil(p * c.ratioDriver / c.capacityDriver),
      opInbound: _ceil(p / c.capacityOpInbound),
      opOutbound: _ceil(p / c.capacityOpOutbound),
    );
  }
}

/// Deviation of Predicted vs Projection (Tim DI).
class DeviationCalculator {
  DeviationCalculator._();

  /// Threshold in percent; strictly greater than this is "Perlu Perhatian".
  static const thresholdPct = 15.0;

  /// (Predicted − Projection) / Projection × 100, or null if projection ≤ 0.
  static double? percent(num? predicted, num? projection) {
    if (predicted == null || projection == null || projection <= 0) return null;
    return (predicted - projection) / projection * 100;
  }

  static bool needsAttention(double? deviationPct) {
    if (deviationPct == null) return false;
    // Round to 4 decimals to avoid flagging 15.000000001 caused by float math.
    final v = (deviationPct.abs() * 10000).roundToDouble() / 10000;
    return v > thresholdPct;
  }
}

/// Daily absolute percentage error and rolling MAE (in percent).
class ErrorMetrics {
  ErrorMetrics._();

  /// |predicted − actual| / actual × 100, or null if actual ≤ 0.
  static double? dailyErrorPct(num? predicted, num? actual) {
    if (predicted == null || actual == null || actual <= 0) return null;
    return (predicted - actual).abs() / actual * 100;
  }

  /// Mean of the most recent [window] daily errors (input oldest → newest).
  static double? rollingMae(List<double> dailyErrors, {int window = 7}) {
    if (dailyErrors.isEmpty) return null;
    final slice = dailyErrors.length > window ? dailyErrors.sublist(dailyErrors.length - window) : dailyErrors;
    return slice.reduce((a, b) => a + b) / slice.length;
  }

  /// Drift threshold = 1.15 × baseline.
  static double driftThreshold(double baselineMae) => baselineMae * 1.15;
}

/// Validation result for the Konfigurasi form.
class ConfigValidation {
  const ConfigValidation(this.fieldErrors, this.ratioError);

  final Map<String, String> fieldErrors;
  final String? ratioError;

  bool get isValid => fieldErrors.isEmpty && ratioError == null;
}

class ConfigValidator {
  ConfigValidator._();

  static const ratioTolerance = 0.001;
  static const msgPositive = 'Nilai harus lebih dari 0.';
  static const msgEmpty = 'Wajib diisi dengan angka.';

  static String msgRatio(double sum) {
    final s = sum.toStringAsFixed(2).replaceAll('.', ',');
    return 'Ratio_Rider + Ratio_Driver harus = 1,00 (saat ini $s).';
  }

  /// [values] keys: capacity_rider, capacity_driver, capacity_op_inbound,
  /// capacity_op_outbound, ratio_rider, ratio_driver. A null value means the
  /// field is empty or not a number.
  static ConfigValidation validate(Map<String, num?> values) {
    final errors = <String, String>{};
    values.forEach((key, v) {
      if (v == null) {
        errors[key] = msgEmpty;
      } else if (v <= 0) {
        errors[key] = msgPositive;
      }
    });
    String? ratioError;
    final rr = values['ratio_rider'];
    final rd = values['ratio_driver'];
    if (rr != null && rd != null) {
      final sum = rr + rd;
      if ((sum - 1.0).abs() > ratioTolerance) ratioError = msgRatio(sum.toDouble());
    }
    return ConfigValidation(errors, ratioError);
  }
}

/// Validation for the Input Actual form.
class ActualValidator {
  ActualValidator._();

  static const msgEmpty = 'Actual inbound wajib diisi.';
  static const msgNegative = 'Nilai tidak boleh negatif.';
  static const msgNotInteger = 'Masukkan angka bulat (contoh 17560).';

  /// Returns an error message or null if [text] is a valid non-negative int.
  static String? validate(String text) {
    final t = text.trim();
    if (t.isEmpty) return msgEmpty;
    if (t.startsWith('-') || t.startsWith('−')) return msgNegative;
    if (!RegExp(r'^[0-9.]+$').hasMatch(t)) return msgNotInteger;
    final cleaned = t.replaceAll('.', '');
    if (cleaned.isEmpty || int.tryParse(cleaned) == null) return msgNotInteger;
    return null;
  }
}
