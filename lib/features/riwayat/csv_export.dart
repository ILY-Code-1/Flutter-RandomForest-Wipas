import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/models.dart';
import '../../core/format/formatters.dart';

/// Builds the history CSV: UTF-8 BOM, comma separator, CRLF line endings.
/// Numbers are written plain (no thousands separator) so spreadsheets parse
/// them; decimals use a dot.
class CsvExport {
  CsvExport._();

  static const bom = '﻿';
  static const header = [
    'tanggal',
    'projection',
    'predicted',
    'actual',
    'deviasi_pct',
    'perlu_perhatian',
    'data_status',
    'keputusan',
    'rider_final',
    'driver_final',
    'op_inbound_final',
    'op_outbound_final',
    'alasan',
    'diputuskan_oleh',
    'waktu_keputusan_wib',
  ];

  static String _cell(Object? v) {
    if (v == null) return '';
    final s = v.toString();
    if (s.contains(RegExp(r'[",\r\n]'))) return '"${s.replaceAll('"', '""')}"';
    return s;
  }

  static String _wib(DateTime t) {
    final w = Fmt.toWib(t);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${Fmt.isoDate(w)} ${two(w.hour)}:${two(w.minute)}';
  }

  /// [rows] newest first or any order; output is sorted by date ascending.
  /// [decisions] maps pred_id → latest decision (omit for no decision columns).
  static String build(List<Prediction> rows, Map<String, DecisionLog> decisions) {
    final sorted = [...rows]..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    final lines = <String>[header.map(_cell).join(',')];
    for (final p in sorted) {
      final d = decisions[p.id];
      final m = d?.manpowerFinal;
      lines.add([
        Fmt.isoDate(p.targetDate),
        p.projection,
        p.predicted,
        p.actualInbound,
        p.deviation?.toStringAsFixed(1),
        p.needsAttention ? 'ya' : 'tidak',
        p.dataStatus,
        d == null ? 'menunggu' : (d.isAdjusted ? 'disesuaikan' : 'disetujui'),
        m?.rider,
        m?.driver,
        m?.opInbound,
        m?.opOutbound,
        d?.reason,
        d?.decidedByName,
        d?.decidedAt == null ? null : _wib(d!.decidedAt!),
      ].map(_cell).join(','));
    }
    return '$bom${lines.join('\r\n')}\r\n';
  }

  static String fileName(DateTime start, DateTime end) =>
      'riwayat_wipas_${Fmt.isoDate(start)}_${Fmt.isoDate(end)}.csv';
}

/// Writes CSV files and opens the share sheet (overridable in tests).
class CsvSaver {
  const CsvSaver();

  Future<File> write(String name, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    return file.writeAsBytes(utf8.encode(content), flush: true);
  }

  Future<void> share(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], subject: 'Riwayat WIPAS'));
  }
}
