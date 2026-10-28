import 'package:flutter_test/flutter_test.dart';
import 'package:wipas_app/core/domain/access_matrix.dart';
import 'package:wipas_app/core/domain/calculators.dart';
import 'package:wipas_app/core/domain/role.dart';
import 'package:wipas_app/features/auth/auth_controller.dart';
import 'package:wipas_app/core/data/models.dart';
import 'package:wipas_app/router.dart';

void main() {
  group('ManpowerCalculator', () {
    const d = CapacityConfig.defaults;

    test('18.420 → 37 / 7 / 37 / 31 (design example)', () {
      final r = ManpowerCalculator.compute(18420, d);
      expect(r, const ManpowerCounts(rider: 37, driver: 7, opInbound: 37, opOutbound: 31));
    });

    test('exact multiples are not rounded up', () {
      // 500 × 0.70 / 350 = 1; 800 × ... driver: 8000 × 0.30 / 800 = 3
      expect(ManpowerCalculator.compute(500, d).rider, 1);
      expect(ManpowerCalculator.compute(8000, d).driver, 3);
      expect(ManpowerCalculator.compute(500, d).opInbound, 1);
      expect(ManpowerCalculator.compute(600, d).opOutbound, 1);
    });

    test('one parcel above a multiple rounds up', () {
      expect(ManpowerCalculator.compute(501, d).opInbound, 2);
      expect(ManpowerCalculator.compute(601, d).opOutbound, 2);
      expect(ManpowerCalculator.compute(501, d).rider, 2); // 350.7 / 350
    });

    test('float noise does not push an exact result up (0.3 × 3 case)', () {
      const c = CapacityConfig(
          capacityRider: 0.7, capacityDriver: 0.9, capacityOpInbound: 1, capacityOpOutbound: 1, ratioRider: 0.7, ratioDriver: 0.3);
      // 3 × 0.3 = 0.8999999999999999 → / 0.9 ≈ 0.999… → must be 1, not 2.
      expect(ManpowerCalculator.compute(3, c).driver, 1);
      // 1 × 0.7 / 0.7 = 1 exactly.
      expect(ManpowerCalculator.compute(1, c).rider, 1);
    });

    test('zero predicted needs zero people', () {
      expect(ManpowerCalculator.compute(0, d).total, 0);
    });

    test('impact preview with changed capacities (design: 33 / 7 / 37 / 29)', () {
      const c = CapacityConfig(
          capacityRider: 400, capacityDriver: 800, capacityOpInbound: 500, capacityOpOutbound: 650, ratioRider: 0.7, ratioDriver: 0.3);
      expect(ManpowerCalculator.compute(18420, c), const ManpowerCounts(rider: 33, driver: 7, opInbound: 37, opOutbound: 29));
    });
  });

  group('DeviationCalculator', () {
    test('18.420 vs 15.900 → +15,8% → Perlu Perhatian', () {
      final dev = DeviationCalculator.percent(18420, 15900)!;
      expect(dev, closeTo(15.849, 0.001));
      expect(DeviationCalculator.needsAttention(dev), isTrue);
    });

    test('exactly 15% is NOT an alert', () {
      final dev = DeviationCalculator.percent(17250, 15000)!;
      expect(dev, closeTo(15.0, 1e-9));
      expect(DeviationCalculator.needsAttention(dev), isFalse);
    });

    test('just above 15% and negative deviations alert', () {
      expect(DeviationCalculator.needsAttention(15.01), isTrue);
      expect(DeviationCalculator.needsAttention(-15.01), isTrue);
      expect(DeviationCalculator.needsAttention(-15.0), isFalse);
    });

    test('missing or zero projection gives null', () {
      expect(DeviationCalculator.percent(100, 0), isNull);
      expect(DeviationCalculator.percent(null, 100), isNull);
      expect(DeviationCalculator.needsAttention(null), isFalse);
    });
  });

  group('ErrorMetrics', () {
    test('daily error = |P − A| / A × 100', () {
      expect(ErrorMetrics.dailyErrorPct(17200, 17560), closeTo(2.0501, 0.0001));
      expect(ErrorMetrics.dailyErrorPct(100, 0), isNull);
    });

    test('rolling MAE uses the last 7 values', () {
      expect(ErrorMetrics.rollingMae([100, 1, 1, 1, 1, 1, 1, 1]), 1);
      expect(ErrorMetrics.rollingMae([2, 4]), 3);
      expect(ErrorMetrics.rollingMae([]), isNull);
    });

    test('drift threshold = 1,15 × baseline', () {
      expect(ErrorMetrics.driftThreshold(6.2), closeTo(7.13, 1e-9));
    });
  });

  group('ConfigValidator', () {
    Map<String, num?> values({num? rider = 350, double rr = 0.7, double rd = 0.3}) => {
          'capacity_rider': rider,
          'capacity_driver': 800,
          'capacity_op_inbound': 500,
          'capacity_op_outbound': 600,
          'ratio_rider': rr,
          'ratio_driver': rd,
        };

    test('defaults are valid', () => expect(ConfigValidator.validate(values()).isValid, isTrue));

    test('ratio sum 1,05 is rejected with the design message', () {
      final v = ConfigValidator.validate(values(rr: 0.75));
      expect(v.isValid, isFalse);
      expect(v.ratioError, 'Ratio_Rider + Ratio_Driver harus = 1,00 (saat ini 1,05).');
    });

    test('ratio within 0,001 tolerance is accepted', () {
      expect(ConfigValidator.validate(values(rr: 0.7005)).isValid, isTrue);
      expect(ConfigValidator.validate(values(rr: 0.702)).isValid, isFalse);
    });

    test('capacity ≤ 0 and empty values are rejected', () {
      expect(ConfigValidator.validate(values(rider: 0)).fieldErrors['capacity_rider'], ConfigValidator.msgPositive);
      expect(ConfigValidator.validate(values(rider: -1)).fieldErrors['capacity_rider'], ConfigValidator.msgPositive);
      expect(ConfigValidator.validate(values(rider: null)).fieldErrors['capacity_rider'], ConfigValidator.msgEmpty);
    });
  });

  group('ActualValidator', () {
    test('empty / negative / non-integer', () {
      expect(ActualValidator.validate(''), ActualValidator.msgEmpty);
      expect(ActualValidator.validate('  '), ActualValidator.msgEmpty);
      expect(ActualValidator.validate('-500'), ActualValidator.msgNegative);
      expect(ActualValidator.validate('17,5'), ActualValidator.msgNotInteger);
      expect(ActualValidator.validate('abc'), ActualValidator.msgNotInteger);
    });

    test('valid integers (with id-ID thousands dots)', () {
      expect(ActualValidator.validate('17560'), isNull);
      expect(ActualValidator.validate('17.560'), isNull);
      expect(ActualValidator.validate('0'), isNull);
    });
  });

  group('AccessMatrix', () {
    test('tabs per role', () {
      expect(AccessMatrix.tabsFor(Role.admin), ['/beranda', '/prediksi', '/manpower', '/evaluasi', '/lainnya']);
      expect(AccessMatrix.tabsFor(Role.manajer), ['/beranda', '/prediksi', '/manpower', '/evaluasi', '/lainnya']);
      expect(AccessMatrix.tabsFor(Role.supervisor), ['/beranda', '/prediksi', '/manpower', '/lainnya']);
      expect(AccessMatrix.tabsFor(Role.viewer), ['/beranda', '/prediksi', '/evaluasi', '/lainnya']);
    });

    // Full table from the prompt (f = full, r = read-only, - = none).
    const table = {
      '/beranda': 'fffr',
      '/prediksi': 'rrrr',
      '/manpower': 'ffr-',
      '/evaluasi': 'ff-r',
      '/input-actual': 'f-f-',
      '/konfigurasi': 'ff--',
      '/riwayat': 'frrr',
      '/notifikasi': 'ffff',
      '/profil': 'ffff',
      '/lainnya': 'ffff',
    };
    const roles = [Role.admin, Role.manajer, Role.supervisor, Role.viewer];
    table.forEach((path, codes) {
      for (var i = 0; i < roles.length; i++) {
        final expected = switch (codes[i]) { 'f' => Access.full, 'r' => Access.readOnly, _ => Access.none };
        test('${roles[i].id} on $path is $expected', () {
          expect(AccessMatrix.accessFor(roles[i], path), expected);
        });
      }
    });

    test('public routes are open, unknown routes are denied', () {
      for (final r in roles) {
        expect(AccessMatrix.accessFor(r, '/login'), Access.full);
        expect(AccessMatrix.accessFor(r, '/admin-secret'), Access.none);
      }
    });

    test('capabilities', () {
      expect(AccessMatrix.canExportCsv(Role.admin), isTrue);
      for (final r in [Role.manajer, Role.supervisor, Role.viewer]) {
        expect(AccessMatrix.canExportCsv(r), isFalse);
      }
      expect(AccessMatrix.canDecideManpower(Role.supervisor), isFalse);
      expect(AccessMatrix.canDecideManpower(Role.manajer), isTrue);
      expect(AccessMatrix.canSeeFeatureDrivers(Role.supervisor), isFalse);
      expect(AccessMatrix.canSeeDecisions(Role.viewer), isFalse);
    });
  });

  group('RoleGuard', () {
    AuthState signedIn(Role r) => AuthState(
          status: AuthStatus.signedIn,
          user: AppUser(uid: 'u', role: r, displayName: 'n', email: 'e', whId: 'WH-CKG-01'),
        );

    test('unknown session goes to splash', () {
      expect(roleGuard(const AuthState.unknown(), Uri.parse('/beranda')), '/splash');
    });

    test('signed out is sent to login (with expired flag)', () {
      expect(roleGuard(const AuthState(status: AuthStatus.signedOut), Uri.parse('/beranda')), '/login');
      expect(roleGuard(const AuthState(status: AuthStatus.signedOut, sessionExpired: true), Uri.parse('/prediksi')),
          '/login?expired=1');
      expect(roleGuard(const AuthState(status: AuthStatus.signedOut), Uri.parse('/login/lupa')), isNull);
    });

    test('forbidden routes redirect to beranda', () {
      expect(roleGuard(signedIn(Role.viewer), Uri.parse('/manpower')), '/beranda');
      expect(roleGuard(signedIn(Role.supervisor), Uri.parse('/evaluasi')), '/beranda');
      expect(roleGuard(signedIn(Role.manajer), Uri.parse('/input-actual')), '/beranda');
      expect(roleGuard(signedIn(Role.viewer), Uri.parse('/konfigurasi')), '/beranda');
      expect(roleGuard(signedIn(Role.admin), Uri.parse('/konfigurasi')), isNull);
      expect(roleGuard(signedIn(Role.admin), Uri.parse('/login')), '/beranda');
    });
  });
}
