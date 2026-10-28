# Pengujian

| Jenis | Lokasi | Perintah | Butuh |
|---|---|---|---|
| Analisis statis | — | `flutter analyze` | Flutter |
| Unit | `test/unit/` | `flutter test test/unit` | Flutter |
| Widget | `test/widget/` | `flutter test test/widget` | Flutter |
| Golden 360×800 | `test/golden/` | `flutter test test/golden` (perbarui: `--update-goldens`) | Flutter |
| Security rules | `firebase/rules-tests/` | `cd firebase/rules-tests && npm install && npm run test:emulator` | Node, Java, firebase-tools (unduh emulator) |
| Integration | `integration_test/` | `flutter test integration_test` | Emulator/perangkat Android + Firebase Emulator + seed |

Semua test Dart memakai `FakeFirebaseFirestore` + `MockFirebaseAuth` yang diisi dari **seed yang sama** dengan emulator (`firebase/seed/seed_data.dart`), dengan "sekarang" dipatok ke Kam, 8 Okt 2026 20:00 WIB (`test/support/harness.dart`). Tidak ada akses jaringan.

## Cakupan
**Unit** (`domain_test`, `format_and_models_test`, `seed_data_test`)
- `ManpowerCalculator`: 18.420 → 37/7/37/31, kelipatan tepat, +1 paket, galat float, pratinjau desain 33/7/37/29.
- `DeviationCalculator`: 15,8% alert; tepat 15% bukan alert; negatif; projection 0.
- `ErrorMetrics`, `ConfigValidator` (rasio 1,05, toleransi 0,001, kapasitas ≤ 0, kosong), `ActualValidator`.
- `AccessMatrix`: setiap sel tabel RBAC × 4 peran; `roleGuard`.
- Formatter id-ID (angka, persen, tanggal, WIB terlepas zona perangkat, pergantian hari WIB).
- Converter model dengan field hilang / tipe salah.
- CSV: BOM UTF-8, koma, CRLF, escaping, urutan.
- Konsistensi seed (manpower = rumus, skenario degraded/fallback/empty).

**Widget** (`core_states_test`, `roles_test`, `flows_test`)
- Beranda, Prediksi, Manpower, Evaluasi × 5 state (loading, kosong, galat + saran IT Support setelah 3 kali, offline, data).
- Per peran: tab bottom nav, kontrol tersembunyi vs terlihat, guard rute, Faktor pendorong, Riwayat (export/keputusan), Lainnya, notifikasi per audiens.
- Alur: Setujui (menulis `decision_logs`), Batal, Sesuaikan (alasan wajib), offline menonaktifkan aksi, Cara hitung, Input Actual (kosong/negatif/simpan), Konfigurasi (galat rasio, pratinjau, transaksi + riwayat), Notifikasi (filter, tandai semua), Export CSV (berhasil/gagal), login salah, sesi > 24 jam, keluar, lupa password.
- Skala teks 130% tanpa overflow.

**Golden**: 22 layar/state pada 360×800 (Login; Beranda 4 peran + offline + kosong + loading; Prediksi admin/manajer grafik/viewer fallback/galat; Manpower manajer/supervisor; Evaluasi sehat/degraded; Input Actual; Konfigurasi; Riwayat; Notifikasi; Lainnya; Profil). Golden dirender di Windows; bila dijalankan di OS lain bisa berbeda beberapa piksel karena rasterisasi font — perbarui dengan `--update-goldens` di mesin acuan.

**Rules** (`rules.test.mjs`, 111 kasus): setiap peran × operasi diizinkan/ditolak untuk semua koleksi.

**Integration**: login Manajer → Tinjau & Setujui → dialog → status Disetujui → dokumen `decision_logs` ada.

## Menjalankan rules test
```bash
npm install -g firebase-tools          # sekali
cd firebase/rules-tests
npm install
npm run test:emulator                  # = firebase emulators:exec --only firestore ... "npm test"
```

## Menjalankan integration test
```bash
firebase emulators:start --only auth,firestore --project demo-wipas
dart run firebase/seed/seed.dart
flutter emulators --launch <nama_avd>   # atau colok HP (EMULATOR_HOST=<IP LAN>)
flutter test integration_test
```
