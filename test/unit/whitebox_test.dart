// Basis-path tests for docs/whitebox_testing.html. Test names start with the
// path id (e.g. "WB-CV-P1") so the documentation can map paths to results.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wipas_app/core/data/models.dart';
import 'package:wipas_app/core/domain/calculators.dart';
import 'package:wipas_app/core/domain/role.dart';
import 'package:wipas_app/core/state/view_state.dart';
import 'package:wipas_app/features/auth/auth_controller.dart';
import 'package:wipas_app/features/riwayat/csv_export.dart';
import 'package:wipas_app/router.dart';

AuthState _in(Role r) => AuthState(
      status: AuthStatus.signedIn,
      user: AppUser(uid: 'u', role: r, displayName: 'n', email: 'e', whId: 'WH-CKG-01'),
    );
const _out = AuthState(status: AuthStatus.signedOut);

Prediction _p({int? actual, String? note}) => Prediction(
      id: 'pred_WH-CKG-01_20261008',
      whId: 'WH-CKG-01',
      targetDate: DateTime.utc(2026, 10, 8),
      predicted: 17200,
      projection: 16200,
      actualInbound: actual,
      actualNote: note,
    );

void main() {
  group('ManpowerCalculator.compute', () {
    test('WB-MP-P1 sequential path: 18.420 → 37/7/37/31', () {
      expect(ManpowerCalculator.compute(18420, CapacityConfig.defaults),
          const ManpowerCounts(rider: 37, driver: 7, opInbound: 37, opOutbound: 31));
    });
  });

  group('DeviationCalculator.percent', () {
    test('WB-DP-P1 predicted null → null', () => expect(DeviationCalculator.percent(null, 15900), isNull));
    test('WB-DP-P2 projection null → null', () => expect(DeviationCalculator.percent(18420, null), isNull));
    test('WB-DP-P3 projection ≤ 0 → null', () => expect(DeviationCalculator.percent(18420, 0), isNull));
    test('WB-DP-P4 valid → 15,85', () => expect(DeviationCalculator.percent(18420, 15900), closeTo(15.849, 0.001)));
  });

  group('DeviationCalculator.needsAttention', () {
    test('WB-DN-P1 null → false', () => expect(DeviationCalculator.needsAttention(null), isFalse));
    test('WB-DN-P2 exactly 15 → false', () => expect(DeviationCalculator.needsAttention(15.0), isFalse));
    test('WB-DN-P3 15,8 → true', () => expect(DeviationCalculator.needsAttention(15.8), isTrue));
  });

  group('ConfigValidator.validate', () {
    const full = {
      'capacity_rider': 350,
      'capacity_driver': 800,
      'capacity_op_inbound': 500,
      'capacity_op_outbound': 600,
      'ratio_rider': 0.7,
      'ratio_driver': 0.3,
    };
    test('WB-CV-P1 empty map: loop skipped, no ratio → valid', () {
      expect(ConfigValidator.validate({}).isValid, isTrue);
    });
    test('WB-CV-P2 null value → "Wajib diisi"', () {
      expect(ConfigValidator.validate({'capacity_rider': null}).fieldErrors['capacity_rider'], ConfigValidator.msgEmpty);
    });
    test('WB-CV-P3 value ≤ 0 → "Nilai harus lebih dari 0."', () {
      expect(ConfigValidator.validate({'capacity_rider': 0}).fieldErrors['capacity_rider'], ConfigValidator.msgPositive);
    });
    test('WB-CV-P4 positive value, ratio_rider missing → valid', () {
      expect(ConfigValidator.validate({'capacity_rider': 350}).isValid, isTrue);
    });
    test('WB-CV-P5 ratio_rider present, ratio_driver missing → no ratio check', () {
      expect(ConfigValidator.validate({'ratio_rider': 0.7}).ratioError, isNull);
    });
    test('WB-CV-P6 ratios sum to 1,00 → valid', () {
      expect(ConfigValidator.validate(full).isValid, isTrue);
    });
    test('WB-CV-P7 ratios 0,60 + 0,30 → ratio error', () {
      final v = ConfigValidator.validate({...full, 'ratio_rider': 0.6});
      expect(v.ratioError, 'Ratio_Rider + Ratio_Driver harus = 1,00 (saat ini 0,90).');
    });
  });

  group('ActualValidator.validate', () {
    test('WB-AV-P1 empty → wajib diisi', () => expect(ActualValidator.validate(' '), ActualValidator.msgEmpty));
    test('WB-AV-P2 "-5" → negatif', () => expect(ActualValidator.validate('-5'), ActualValidator.msgNegative));
    test('WB-AV-P3 "−5" (minus sign) → negatif', () => expect(ActualValidator.validate('−5'), ActualValidator.msgNegative));
    test('WB-AV-P4 "17,5" → bukan angka bulat', () => expect(ActualValidator.validate('17,5'), ActualValidator.msgNotInteger));
    test('WB-AV-P5 "." → kosong setelah dibersihkan', () => expect(ActualValidator.validate('.'), ActualValidator.msgNotInteger));
    test('WB-AV-P6 angka melampaui int64 → bukan angka bulat', () {
      expect(ActualValidator.validate('99999999999999999999999'), ActualValidator.msgNotInteger);
    });
    test('WB-AV-P7 "17.560" → valid', () => expect(ActualValidator.validate('17.560'), isNull));
  });

  group('roleGuard', () {
    test('WB-RG-P1 /dev/gallery in debug → allowed', () {
      expect(roleGuard(const AuthState.unknown(), Uri.parse('/dev/gallery')), isNull);
    });
    test('WB-RG-P3 /splash → allowed', () => expect(roleGuard(_out, Uri.parse('/splash')), isNull));
    test('WB-RG-P4 unknown session → /splash', () {
      expect(roleGuard(const AuthState.unknown(), Uri.parse('/beranda')), '/splash');
    });
    test('WB-RG-P5 signed out on public route → allowed', () => expect(roleGuard(_out, Uri.parse('/login')), isNull));
    test('WB-RG-P6 signed out, session expired → /login?expired=1', () {
      expect(roleGuard(const AuthState(status: AuthStatus.signedOut, sessionExpired: true), Uri.parse('/beranda')),
          '/login?expired=1');
    });
    test('WB-RG-P7 signed out → /login', () => expect(roleGuard(_out, Uri.parse('/manpower')), '/login'));
    test('WB-RG-P8 signed in on /login → /beranda', () => expect(roleGuard(_in(Role.admin), Uri.parse('/login')), '/beranda'));
    test('WB-RG-P9 signed in on /login/lupa → /beranda', () {
      expect(roleGuard(_in(Role.viewer), Uri.parse('/login/lupa')), '/beranda');
    });
    test('WB-RG-P10 allowed route → null', () => expect(roleGuard(_in(Role.manajer), Uri.parse('/konfigurasi')), isNull));
    test('WB-RG-P11 Viewer on /manpower → /beranda', () {
      expect(roleGuard(_in(Role.viewer), Uri.parse('/manpower')), '/beranda');
    });
  });

  group('CsvExport._cell (via build)', () {
    String row(Prediction p) => CsvExport.build([p], const {}).substring(1).trim().split('\r\n')[1];
    test('WB-CS-P1 null value → empty cell', () {
      expect(row(_p()).split(',')[3], '');
    });
    test('WB-CS-P2 plain value → unchanged', () {
      expect(row(_p(actual: 17560)).split(',')[3], '17560');
    });
    test('WB-CS-P3 value with comma/quote → quoted and escaped', () {
      final decisions = {
        'pred_WH-CKG-01_20261008': DecisionLog(
          id: 'd',
          predId: 'pred_WH-CKG-01_20261008',
          whId: 'WH-CKG-01',
          decidedBy: 'u',
          decidedByName: 'Budi',
          decision: 'adjusted',
          manpowerFinal: null,
          reason: 'rute "padat", hujan',
        ),
      };
      final line = CsvExport.build([_p()], decisions);
      expect(line, contains('"rute ""padat"", hujan"'));
    });
  });

  group('toViewState', () {
    bool empty(List<int> d) => d.isEmpty;
    test('WB-VS-P1 loading', () {
      expect(toViewState<List<int>>(const AsyncLoading(), offline: false), isA<ViewLoading<List<int>>>());
    });
    test('WB-VS-P2 error', () {
      expect(toViewState<List<int>>(AsyncError(StateError('x'), StackTrace.empty), offline: false),
          isA<ViewError<List<int>>>());
    });
    test('WB-VS-P3 data without isEmpty callback, online', () {
      expect(toViewState<List<int>>(const AsyncData([]), offline: false), isA<ViewData<List<int>>>());
    });
    test('WB-VS-P4 data judged empty', () {
      expect(toViewState<List<int>>(const AsyncData([]), offline: true, isEmpty: empty), isA<ViewEmpty<List<int>>>());
    });
    test('WB-VS-P5 data, offline → Offline with lastSync', () {
      final t = DateTime.utc(2026, 10, 8, 16, 2);
      final s = toViewState<List<int>>(const AsyncData([1]), offline: true, lastSync: t, isEmpty: empty);
      expect(s, isA<ViewOffline<List<int>>>());
      expect((s as ViewOffline<List<int>>).lastSync, t);
    });
    test('WB-VS-P6 data, online, not empty → Data', () {
      expect(toViewState<List<int>>(const AsyncData([1]), offline: false, isEmpty: empty), isA<ViewData<List<int>>>());
    });
  });
}
