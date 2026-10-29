# PROGRESS — wipas-app

Log kemajuan sesi otonom. Hanya hasil yang benar-benar dijalankan yang dicatat.

## Tahap 0 — Konteks
- Branch: `main` (`git branch --show-current`).
- Dibaca: `WIPAS_KONTEKS_Untuk_Claude_Code.md`, `WIPAS_Prompt_2_Repo_Aplikasi.md`, PNG handoff 5–8 dan layar kunci.
- Alat: Flutter 3.41.6 / Dart 3.11.4, Android SDK 35, Node 22.12, Java 22. Firebase CLI **tidak terpasang**. Tidak ada emulator/perangkat Android (`flutter devices`: Windows, Chrome, Edge saja).

## Tahap 1 — Pengembangan

### Fase 0 — Scaffold & tema
- `flutter create --org id.wipas --project-name wipas_app --platforms android .`
- Dependensi via `flutter pub add`; font Inter (OFL) diambil dari paket npm `inter-font@3.19.0` (`npm pack`) → `assets/fonts/`.
- Token (`lib/core/theme/tokens.dart`), tema M3, komponen `Wipas*` (`lib/core/widgets/`), galeri `/dev/gallery` (debug).

### Fase 1–7 — Layar & data (kode ditulis)
- Auth (Splash, Login, Lupa password), AccessMatrix + RoleGuard, shell bottom-nav per role.
- Model + converter null-tolerant, repository (query berbatas tanggal + limit), ConnectivityService + SyncClock.
- Layar: Beranda, Prediksi, Manpower, Evaluasi, Input Actual, Konfigurasi, Riwayat & Export, Notifikasi, Lainnya, Profil.
- Verifikasi: `flutter analyze` → **No issues found!**

### Fase 2 — Data layer & seed
- `firebase/seed/seed_data.dart` (data deterministik, 4 skenario: normal, degraded, fallback, empty) + `firebase/seed/seed.dart` (REST ke emulator lokal saja, menolak host non-lokal).
- `firebase.json`, `.firebaserc` (demo-wipas), `firebase/firestore.rules`, `firebase/firestore.indexes.json`.
- Rules test: `firebase/rules-tests/rules.test.mjs` (111 kasus). `npm install` berhasil; `node --check` OK; import modul OK. **Belum dijalankan terhadap emulator**: Firebase CLI tidak terpasang secara global, dan menjalankan emulator Firestore membutuhkan unduhan JAR emulator oleh firebase-tools (di luar manajer paket) → dicatat sebagai langkah manual. `node_modules` dihapus lagi (berat, memperlambat analyzer).

### Verifikasi test Dart (sesi ini)
- `flutter test test/unit` → **+89, All tests passed!**
- `flutter test test/widget` → **+76, All tests passed!** (5 state × 4 layar inti, per peran, alur tulis, auth, export CSV, skala teks 130%)
- `flutter test --update-goldens test/golden` → 22 golden 360×800 dibuat (perlu dibuat ulang setelah perubahan app bar).
- Perbaikan dari test: app bar terpotong pada skala teks 130% (tinggi kini mengikuti skala teks); layar crash saat user null ketika keluar (guard ditambahkan).

### Fase 8 — Penyelesaian (sebagian)
- `integration_test/approve_flow_test.dart` ditulis (butuh perangkat + emulator → manual).
- `.gitignore` diperluas (rahasia, google-services.json, artefak emulator, node_modules); `dart_test.yaml` (tag golden).
- Golden dibuat ulang (`flutter test --update-goldens test/golden` → +22 passed). Chip role Viewer tidak lagi terpotong.
- Android manifest: izin INTERNET/ACCESS_NETWORK_STATE (sebelumnya hanya di debug → APK rilis tak bisa online), network security config (HTTP hanya ke host emulator), label "WIPAS", potret.
- Dokumen: `docs/firestore_schema.md`, `ASSUMPTIONS.md`, `docs/design_deviations.md`, `docs/rbac_matrix.md`, `docs/architecture.md`, `docs/setup_firebase.md`, `docs/testing.md`, `docs/design_parity.md`, README diperluas.
- Berikutnya: hasil `flutter build apk --release`, lalu Fase 9 (audit dari keadaan bersih) dan `docs/HANDOFF.md`.

### Build APK rilis
- Percobaan 1: gagal — `firebase-auth 25` dikompilasi Kotlin 2.4, plugin proyek 2.2.20.
- Perbaikan: plugin Kotlin → 2.4.0 (`android/settings.gradle.kts`), `kotlinOptions` → `kotlin { compilerOptions }`, signing rilis via `android/key.properties` bila ada (selain itu kunci debug), TODO template dihapus.
- Percobaan 3: `flutter build apk --release` → **√ Built build\app\outputs\flutter-apk\app-release.apk (56.1MB)**.
- Fase 9 (audit bersih) dijalankan: clean → pub get → analyze → test → build.

### Fase 9 — Audit mandiri (selesai)
- `flutter clean` → `flutter pub get` → `flutter analyze`: **No issues found!**
- `flutter test` run 1: +181 −6 (golden Beranda usang setelah perubahan header) → header diperbaiki, golden diregenerasi & diperiksa → run ulang: **+187: All tests passed!**; analyze ulang: No issues found!
- `flutter build apk --release` (kode final): **√ Built app-release.apk (56.1MB)**.
- Pemindaian rahasia: bersih.
- Rules test & integration test: belum dijalankan (butuh emulator) → HANDOFF langkah manual.
- `docs/HANDOFF.md` ditulis lengkap.

## TAHAP 1 SELESAI (test Dart hijau). Lanjut Tahap 2 — Dokumentasi.

## TAHAP 2 — Dokumentasi (selesai)
- Langkah 1–11 dikerjakan; rincian di `docs/DOC_REPORT.md`.
- PlantUML 1.2026.9 (`tools/plantuml.jar`): semua diagram `-checkonly` exit 0; 52 PNG di `docs/img/`.
- Test tambahan: `test/unit/whitebox_test.dart` (41), 2 test login di `flows_test.dart` → `flutter test --reporter json`: **230 lulus, 0 gagal**; `flutter analyze`: No issues found!
- `python tools/check_docs.py` → **127/127 pemeriksaan lulus** (uji negatif: menyisipkan `participant` membuat pemeriksa gagal, lalu dipulihkan).
- Blackbox 48 skenario (46 Lulus, 2 Belum diuji); whitebox 42 basis path (41 Lulus, 1 Belum diuji); UAT 24 (Belum diuji).

## TAHAP 3 — Penutup: laporan akhir diberikan di chat.

## Sinkronisasi kontrak Firestore v1.0 (29 Okt 2026)
- Sumber: `docs/firestore_schema.md` dari repo riset. 29 selisih diperbaiki di sisi aplikasi; rincian di `docs/SYNC_REPORT.md`.
- `flutter analyze`: No issues found! · `flutter test`: +241 All tests passed! · `tools/check_docs.py`: 127/127.
