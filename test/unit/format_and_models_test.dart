import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wipas_app/core/data/models.dart';
import 'package:wipas_app/core/domain/calculators.dart';
import 'package:wipas_app/core/domain/role.dart';
import 'package:wipas_app/core/format/formatters.dart';
import 'package:wipas_app/features/evaluasi/evaluasi_screen.dart';
import 'package:wipas_app/features/input_actual/input_actual_screen.dart';
import 'package:wipas_app/features/riwayat/csv_export.dart';

void main() {
  group('Fmt (id-ID)', () {
    test('thousands dot, decimal comma, percent', () {
      expect(Fmt.number(18420), '18.420');
      expect(Fmt.number(1234567), '1.234.567');
      expect(Fmt.number(null), '—');
      expect(Fmt.percent(15.8), '15,8%');
      expect(Fmt.percent(15.849), '15,8%');
      expect(Fmt.signedPercent(15.849), '+15,8%');
      expect(Fmt.signedPercent(-3), '−3,0%');
      expect(Fmt.signedNumber(2520), '+2.520');
      expect(Fmt.decimal(0.7, digits: 2), '0,70');
    });

    test('dates', () {
      final d = DateTime.utc(2026, 10, 8);
      expect(Fmt.date(d), 'Kam, 8 Okt 2026');
      expect(Fmt.dateNoYear(DateTime.utc(2026, 10, 9)), 'Jum, 9 Okt');
      expect(Fmt.range(DateTime.utc(2026, 10, 3), DateTime.utc(2026, 10, 9)), '3 Okt – 9 Okt 2026');
      expect(Fmt.isoDate(d), '2026-10-08');
      expect(Fmt.dateKey(d), '20261008');
      expect(Fmt.parseIsoDate('2026-10-08'), d);
      expect(Fmt.parseIsoDate('08/10/2026'), isNull);
    });

    test('times are always WIB regardless of device zone', () {
      final instant = DateTime.utc(2026, 10, 8, 16, 2); // 23:02 WIB
      expect(Fmt.time(instant), '23:02 WIB');
      expect(Fmt.dateTimeWib(instant), 'Kam, 8 Okt 2026 23:02 WIB');
      expect(Fmt.logTime(DateTime.utc(2026, 10, 8, 23, 40)), '9 Okt 2026 06:40');
      expect(Fmt.time(instant.toLocal()), '23:02 WIB');
    });

    test('today in WIB crosses midnight correctly', () {
      expect(Fmt.todayWib(DateTime.utc(2026, 10, 8, 17, 30)), DateTime.utc(2026, 10, 9));
      expect(Fmt.todayWib(DateTime.utc(2026, 10, 8, 16, 59)), DateTime.utc(2026, 10, 8));
    });

    test('duration and parsing', () {
      expect(Fmt.duration(134), '2 mnt 14 dtk');
      expect(Fmt.duration(9), '9 dtk');
      expect(Fmt.parseInt('17.560'), 17560);
      expect(Fmt.parseDecimal('0,70'), 0.7);
      expect(Fmt.parseDecimal(''), isNull);
    });
  });

  group('Model converters tolerate missing fields', () {
    test('Prediction with only a target date', () {
      final p = Prediction.fromDoc('x', {'target_date': '2026-10-09'})!;
      expect(p.predicted, isNull);
      expect(p.deviation, isNull);
      expect(p.needsAttention, isFalse);
      expect(p.manpower, isNull);
      expect(p.inputFeatures.backlogH1, isNull);
      expect(p.isFallback, isFalse);
      expect(p.sourceLabel, 'H-1');
    });

    test('Prediction without target date or data is skipped', () {
      expect(Prediction.fromDoc('x', {'predicted': 1}), isNull);
      expect(Prediction.fromDoc('x', null), isNull);
    });

    test('Prediction with wrong types does not throw', () {
      final p = Prediction.fromDoc('x', {
        'target_date': '2026-10-09',
        'predicted': '18420',
        'projection': 15900.0,
        'manpower': 'oops',
        'input_features': {'is_campaign': 1, 'backlog_h1': 'n/a'},
        'generated_at': Timestamp.fromDate(DateTime.utc(2026, 10, 8, 16)),
        'data_status': 'incomplete_fallback_h2',
      })!;
      expect(p.predicted, 18420);
      expect(p.deviation, closeTo(15.849, 0.001));
      expect(p.needsAttention, isTrue);
      expect(p.manpower, isNull);
      expect(p.inputFeatures.isCampaign, isTrue);
      expect(p.inputFeatures.backlogH1, isNull);
      expect(p.isFallback, isTrue);
      expect(p.sourceLabel, 'H-2');
    });

    test('Manpower requires all four counts', () {
      expect(ManpowerRecommendation.fromMap({'rider': 1, 'driver': 1, 'op_inbound': 1}), isNull);
      final m = ManpowerRecommendation.fromMap({'rider': 37, 'driver': 7, 'op_inbound': 37, 'op_outbound': 31})!;
      expect(m.counts.total, 112);
    });

    test('OperationalConfig falls back to defaults', () {
      final c = OperationalConfig.fromMap({'capacity_rider': 400});
      expect(c.capacity.capacityRider, 400);
      expect(c.capacity.capacityDriver, 800);
      expect(c.capacity.ratioRider, 0.7);
    });

    test('ModelHealth threshold falls back to 1,15 × baseline', () {
      final h = ModelHealth.fromMap({'baseline_mae': 6.2, 'status': 'degraded'})!;
      expect(h.threshold, closeTo(7.13, 1e-9));
      expect(h.isDegraded, isTrue);
      expect(ModelHealth.fromMap(null), isNull);
    });

    test('AppUser needs a valid role', () {
      expect(AppUser.fromDoc('u', {'role': 'superuser'}), isNull);
      expect(AppUser.fromDoc('u', null), isNull);
      final u = AppUser.fromDoc('u', {'role': 'viewer', 'display_name': 'Dewi Lestari'}, fallbackEmail: 'd@x')!;
      expect(u.role, Role.viewer);
      expect(u.initials, 'DL');
      expect(u.email, 'd@x');
      expect(u.whId, 'WH-CKG-01');
      expect(AppUser.fromDoc('a', {'role': 'admin', 'display_name': 'Admin WIPAS · Shift Lead'})!.initials, 'AW');
    });

    test('Other converters', () {
      expect(DecisionLog.fromDoc('d', {'pred_id': 'p'}), isNull);
      expect(DecisionLog.fromDoc('d', {'decision': 'adjusted'})!.isAdjusted, isTrue);
      expect(BatchLog.fromMap({})!.status, 'unknown');
      expect(DatasetStatus.fromMap({'row_count': 646})!.rowCount, 646);
      expect(AppNotification.fromDoc('n', {'audience_roles': 'admin'})!.audienceRoles, isEmpty);
      expect(ModelHealthPoint.fromMap({'date': '2026-10-08'}), isNull);
      expect(ConfigHistoryEntry.fromDoc('h', {}).newValues, isEmpty);
    });
  });

  group('CSV export', () {
    final rows = [
      Prediction(
        id: 'pred_WH-CKG-01_20261009',
        whId: 'WH-CKG-01',
        targetDate: DateTime.utc(2026, 10, 9),
        predicted: 18420,
        projection: 15900,
      ),
      Prediction(
        id: 'pred_WH-CKG-01_20261008',
        whId: 'WH-CKG-01',
        targetDate: DateTime.utc(2026, 10, 8),
        predicted: 17200,
        projection: 16200,
        actualInbound: 17560,
      ),
    ];
    final decisions = {
      'pred_WH-CKG-01_20261008': DecisionLog(
        id: 'd',
        predId: 'pred_WH-CKG-01_20261008',
        whId: 'WH-CKG-01',
        decidedBy: 'u',
        decidedByName: 'Budi Santoso',
        decision: 'adjusted',
        manpowerFinal: const ManpowerCounts(rider: 40, driver: 7, opInbound: 37, opOutbound: 31),
        reason: 'antrean, "padat"',
        decidedAt: DateTime.utc(2026, 10, 7, 23, 40),
      ),
    };

    test('starts with UTF-8 BOM, comma separated, sorted ascending', () {
      final csv = CsvExport.build(rows, decisions);
      expect(csv.startsWith('﻿'), isTrue);
      final lines = csv.substring(1).trim().split('\r\n');
      expect(lines.first, CsvExport.header.join(','));
      expect(lines, hasLength(3));
      expect(lines[1].startsWith('2026-10-08,16200,17200,17560,6.2,tidak,complete,disesuaikan,40,7,37,31,'), isTrue);
      expect(lines[1], contains('"antrean, ""padat"""'));
      expect(lines[1].endsWith('2026-10-08 06:40'), isTrue);
      expect(lines[2].startsWith('2026-10-09,15900,18420,,15.8,ya,complete,menunggu'), isTrue);
    });

    test('file name contains the range', () {
      expect(CsvExport.fileName(DateTime.utc(2026, 10, 3), DateTime.utc(2026, 10, 9)),
          'riwayat_wipas_2026-10-03_2026-10-09.csv');
    });
  });

  group('Evaluation helpers', () {
    Prediction p(int day, int pred, int proj, int? act) => Prediction(
          id: '$day',
          whId: 'w',
          targetDate: DateTime.utc(2026, 10, day),
          predicted: pred,
          projection: proj,
          actualInbound: act,
        );

    test('weekly projection evaluation groups by Monday', () {
      // 5 Oct 2026 is a Monday.
      final rows = weeklyProjectionEval([p(4, 110, 100, 100), p(5, 100, 90, 100), p(6, 120, 100, 100), p(7, 1, 1, null)]);
      expect(rows, hasLength(2));
      expect(rows[0].days, 1);
      expect(rows[0].predMape, closeTo(10, 1e-9));
      expect(rows[1].days, 2);
      expect(rows[1].projMape, closeTo(5, 1e-9));
      expect(rows[1].predMape, closeTo(10, 1e-9));
      expect(rows[1].daysOver, 1); // 120 vs 100 = +20%
    });

    test('projected rolling MAE replaces the edited day', () {
      final window = [p(6, 110, 100, 100), p(7, 100, 100, 100), p(8, 100, 100, null), p(9, 1, 1, null)];
      // Day 8 with actual 80 → error 25%; mean(10, 0, 25) = 11,67
      expect(projectedRollingMae(window, DateTime.utc(2026, 10, 8), 80), closeTo(35 / 3, 1e-9));
    });
  });
}
