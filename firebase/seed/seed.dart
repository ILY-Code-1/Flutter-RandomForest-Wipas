// Seeds the LOCAL Firebase Emulator (project demo-wipas) with demo accounts
// and data. It talks only to the emulator REST endpoints and refuses to run
// against any other project.
//
// Usage (from the repo root, with the emulators running):
//   dart run firebase/seed/seed.dart [--scenario=normal|degraded|fallback|empty] [--keep]
//
// Environment overrides (defaults shown):
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
//   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
//   SEED_TODAY=YYYY-MM-DD   (pin "today" in WIB; default: current WIB date)

import 'dart:convert';
import 'dart:io';

import 'seed_data.dart';

const projectId = 'demo-wipas';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final fsHost = env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';
  final authHost = env['FIREBASE_AUTH_EMULATOR_HOST'] ?? '127.0.0.1:9099';
  final scenarioName = args
      .firstWhere((a) => a.startsWith('--scenario='), orElse: () => '--scenario=normal')
      .split('=')
      .last;
  final scenario = SeedScenario.values.firstWhere((s) => s.name == scenarioName,
      orElse: () => throw ArgumentError('Skenario tidak dikenal: $scenarioName'));
  final keep = args.contains('--keep');

  for (final h in [fsHost, authHost]) {
    final host = h.split(':').first;
    if (!{'127.0.0.1', 'localhost', '0.0.0.0', '::1'}.contains(host)) {
      stderr.writeln('Menolak: seed hanya untuk emulator lokal (host: $h).');
      exit(2);
    }
  }

  final today = _today(env['SEED_TODAY']);
  final client = HttpClient();
  try {
    if (!keep) {
      stdout.writeln('Menghapus data emulator lama…');
      await _send(client, 'DELETE', 'http://$fsHost/emulator/v1/projects/$projectId/databases/(default)/documents');
      await _send(client, 'DELETE', 'http://$authHost/emulator/v1/projects/$projectId/accounts');
    }

    stdout.writeln('Membuat ${demoAccounts.length} akun demo…');
    final uids = <String, String>{};
    for (final a in demoAccounts) {
      final res = await _send(
        client,
        'POST',
        'http://$authHost/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',
        body: {'email': a.email, 'password': demoPassword, 'displayName': a.displayName, 'returnSecureToken': true},
      );
      uids[a.key] = (res as Map)['localId'] as String;
    }

    final docs = buildSeed(today: today, uids: uids, scenario: scenario);
    stdout.writeln('Menulis ${docs.length} dokumen (skenario: ${scenario.name}, hari ini: ${iso(today)})…');
    const chunk = 200;
    for (var i = 0; i < docs.length; i += chunk) {
      final part = docs.sublist(i, i + chunk > docs.length ? docs.length : i + chunk);
      await _send(
        client,
        'POST',
        'http://$fsHost/v1/projects/$projectId/databases/(default)/documents:commit',
        body: {
          'writes': [
            for (final d in part)
              {
                'update': {
                  'name': 'projects/$projectId/databases/(default)/documents/${d.path}',
                  'fields': _fields(d.data),
                },
              },
          ],
        },
      );
    }
    stdout.writeln('Selesai. Akun demo (password: $demoPassword):');
    for (final a in demoAccounts) {
      stdout.writeln('  ${a.role.padRight(10)} ${a.email}');
    }
  } finally {
    client.close();
  }
}

DateTime _today(String? override) {
  if (override != null) {
    final p = override.split('-').map(int.parse).toList();
    return DateTime.utc(p[0], p[1], p[2]);
  }
  final w = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateTime.utc(w.year, w.month, w.day);
}

Future<Object?> _send(HttpClient client, String method, String url, {Object? body}) async {
  final req = await client.openUrl(method, Uri.parse(url));
  // "owner" bypasses security rules — accepted by the emulator only.
  req.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
  if (body != null) {
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
  }
  final res = await req.close();
  final text = await res.transform(utf8.decoder).join();
  if (res.statusCode >= 300) {
    throw HttpException('$method $url → ${res.statusCode}: $text');
  }
  return text.isEmpty ? null : jsonDecode(text);
}

Map<String, Object?> _fields(Map<String, Object?> data) => {for (final e in data.entries) e.key: _value(e.value)};

/// Encodes a Dart value as a Firestore REST `Value`.
Map<String, Object?> _value(Object? v) {
  if (v == null) return {'nullValue': null};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': '$v'};
  if (v is double) return {'doubleValue': v};
  if (v is String) return {'stringValue': v};
  if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
  if (v is List) return {'arrayValue': {'values': v.map(_value).toList()}};
  if (v is Map) return {'mapValue': {'fields': _fields(Map<String, Object?>.from(v))}};
  throw ArgumentError('Tipe tidak didukung: ${v.runtimeType}');
}
