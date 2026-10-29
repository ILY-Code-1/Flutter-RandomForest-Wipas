# Arsitektur wipas-app

## Gambaran
```
 wipas-research (Python, Admin SDK)            wipas-app (Flutter, Android)
 ─ impor Excel → daily_data                    ─ membaca: predictions, model_health*,
 ─ batch RF → predictions (+manpower)             batch_logs, dataset_status, notifications,
 ─ evaluasi → model_health(_history)              operational_configs(+/history), decision_logs
 ─ batch_logs, dataset_status, notifications   ─ menulis: actual_*, decision_logs,
                 │                                 operational_configs + /history, decision_* di predictions,
                 ▼                                 notifications.read_by
          Cloud Firestore (Spark) ◄──────────── security rules (firebase/firestore.rules)
```
Tidak ada Cloud Functions; tidak ada push. Selama pengembangan semuanya berjalan di Firebase Emulator (`demo-wipas`).

## Struktur folder (feature-first)
```
lib/
  main.dart            init Firebase (placeholder options), emulator, persistence, ProviderScope
  app.dart             MaterialApp.router, tema, locale id-ID, batas skala teks 130%, cek sesi saat resume
  router.dart          go_router + roleGuard (redirect) + StatefulShellRoute (5 tab)
  firebase_options.dart  PLACEHOLDER demo-wipas (bukan dari flutterfire)
  core/
    config/   AppConfig (dart-define: USE_EMULATOR, EMULATOR_HOST, SHOW_DEMO_LOGIN)
    theme/    tokens.dart (WipasColors/Text/Space/Radius/Size/Elevation/Motion), theme.dart
    widgets/  komponen Wipas* (app bar, bottom nav, badge, banner, kartu, input, dialog, state)
    format/   Fmt: angka/persen/tanggal id-ID, waktu WIB (UTC+7, tidak bergantung zona perangkat)
    domain/   Role, AccessMatrix, ManpowerCalculator, DeviationCalculator, ErrorMetrics, validator
    data/     models.dart (converter null-tolerant), repository.dart (query berbatas),
              providers.dart (Riverpod), connectivity_service.dart (+ SyncClock)
    state/    ViewState sealed: Loading, Empty, Error, Offline(lastSync), Data
  features/
    auth/ beranda/ prediksi/ manpower/ evaluasi/ input_actual/ konfigurasi/
    riwayat/ (csv_export.dart) notifikasi/ profil/ lainnya/ shell/ common/ dev/ (galeri)
firebase/   firestore.rules, firestore.indexes.json, seed/ (seed_data.dart, seed.dart), rules-tests/
test/       unit/, widget/, golden/ (+ goldens/*.png), support/harness.dart
integration_test/  approve_flow_test.dart (perangkat + emulator)
```

## Aliran data
1. `repositoryProvider` membuat `WipasRepository(firestore, wh_id user)`.
2. Repository mengembalikan `Stream<Snap<T>>` dengan `includeMetadataChanges: true`; `Snap.fromCache` diteruskan ke `SyncClock` — hanya snapshot dari server yang memperbarui "Terakhir disinkronkan" (disimpan di `shared_preferences`).
3. Provider layar (mis. `dashboardProvider`) menggabungkan beberapa stream dengan `combineAsync`.
4. `toViewState()` memetakan `AsyncValue` + `isOfflineProvider` (connectivity_plus) → `ViewState`; `WipasStateView` merender skeleton/kosong/galat/offline+data/data.
5. Galat: tombol "Coba lagi" meng-invalidate provider dan menaikkan `retryCountProvider`; setelah 3 kali muncul saran menghubungi IT Support.

## Offline
- Persistence Firestore bawaan (`Settings(persistenceEnabled: true)`), tanpa drift/hive.
- Offline terdeteksi via `connectivity_plus`; data cache tetap tampil dengan `WipasOfflineBanner`.
- Semua aksi tulis (Setujui, Sesuaikan, Simpan actual, Simpan konfigurasi, Export) nonaktif dengan keterangan "Tidak tersedia saat offline". Kontrol yang tersembunyi karena peran tetap tersembunyi.

## Batas baca (Spark 50.000/hari)
Semua daftar memakai rentang tanggal + `limit`: prediksi ≤ 31 dokumen, riwayat model 30, notifikasi 30, keputusan 60, riwayat konfigurasi 10, batch terbaru 1. Perkiraan satu sesi membuka semua layar: ±150 dokumen.

## Sesi & auth
`AuthController` mendengarkan `authStateChanges`, memuat `users/{uid}`; role tidak valid → keluar dengan pesan. Cap waktu login di `shared_preferences`; ≥ 24 jam → `signOut` + Login dengan banner "Sesi berakhir". Reset password memakai `sendPasswordResetEmail` (Firebase Auth).

## Security rules (ringkas)
Tolak secara default, role dari `users/{uid}.role` (lihat `docs/rbac_matrix.md`). Script Python menulis dengan Admin SDK sehingga koleksi milik script read-only bagi klien.
