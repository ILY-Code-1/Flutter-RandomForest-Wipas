# DOC_REPORT — Dokumentasi teknis wipas-app

Laporan kerja prompt dokumentasi (`WIPAS_Prompt_3_Dokumentasi_Aplikasi.md`). Diperbarui setelah tiap langkah.

## Langkah 1 — Inventaris proyek (dibaca dari kode)

Sumber yang dibaca: `lib/` (seluruh layar, `core/domain`, `core/data`), `test/`, `firebase/` (rules, indeks, seed), `docs/firestore_schema.md`, `docs/rbac_matrix.md`, `docs/architecture.md`, `docs/design_parity.md`.

### (a) Aktor
| Aktor | Jenis | Dasar di kode |
|---|---|---|
| Admin (Shift Lead) | primer | `Role.admin` (`lib/core/domain/role.dart`); akses penuh di `AccessMatrix` + Export CSV |
| Manajer | primer | `Role.manajer`; Setujui/Sesuaikan (`AccessMatrix.canDecideManpower`), Konfigurasi, Evaluasi |
| Supervisor | primer | `Role.supervisor`; Input Actual; Manpower hanya baca; tanpa Evaluasi |
| Viewer (Tim DI) | primer | `Role.viewer`; hanya baca; tanpa Manpower, tanpa kolom keputusan |
| Script Batch Prediksi (Python) | sekunder (sistem) | Menulis `predictions`, `model_health*`, `batch_logs`, `dataset_status`, `notifications` lewat Admin SDK (rules: tulis klien `false`) |

IT Support tidak digambarkan sebagai aktor: akun dibuat di Firebase Console; aplikasi hanya menyarankan "Hubungi IT Support" setelah 3 kali gagal memuat (`WipasErrorState.itSupport`).

### (b) Fitur, layar, dan berkas
| Fitur | Layar / rute | Berkas utama | Logika |
|---|---|---|---|
| Login + sesi 24 jam | `LoginScreen` `/login`, `SplashScreen` `/splash` | `features/auth/login_screen.dart`, `splash_screen.dart` | `AuthController.signIn`, `isSessionExpired`, `expireSession` |
| Reset kata sandi | `ForgotPasswordScreen` `/login/lupa` | `features/auth/forgot_password_screen.dart` | `AuthController.sendPasswordReset` |
| Beranda per peran | `BerandaScreen` `/beranda` | `features/beranda/beranda_screen.dart` | `dashboardProvider`, `DeviationCalculator` |
| Prediksi H+1/H+2 | `PrediksiScreen` `/prediksi` | `features/prediksi/prediksi_screen.dart` | `prediksiHorizonProvider`, `AccessMatrix.canSeeFeatureDrivers` |
| Rekomendasi Manpower + Cara hitung | `ManpowerScreen` `/manpower` | `features/manpower/manpower_screen.dart` | `manpowerDataProvider` |
| Setujui rekomendasi | dialog di `ManpowerScreen` | idem (`_approve`) | `WipasRepository.addDecision` |
| Sesuaikan manual | `AdjustSheet` | idem (`_adjust`) | alasan wajib (`AdjustSheet.reasonRequired`) |
| Evaluasi model | `EvaluasiScreen` `/evaluasi` | `features/evaluasi/evaluasi_screen.dart` | `evaluasiDataProvider`, `weeklyProjectionEval` |
| Input Actual | `InputActualScreen` `/input-actual` | `features/input_actual/input_actual_screen.dart` | `ActualValidator`, `projectedRollingMae`, `WipasRepository.saveActual` |
| Konfigurasi kapasitas | `KonfigurasiScreen` `/konfigurasi` | `features/konfigurasi/konfigurasi_screen.dart` | `ConfigValidator`, `ManpowerCalculator`, `WipasRepository.saveConfig` (transaksi) |
| Riwayat & log keputusan | `RiwayatScreen` `/riwayat` | `features/riwayat/riwayat_screen.dart` | `riwayatDataProvider` |
| Export CSV | `RiwayatScreen` (Admin) | `features/riwayat/csv_export.dart` | `CsvExport.build`, `CsvSaver` |
| Notifikasi | `NotifikasiScreen` `/notifikasi` | `features/notifikasi/notifikasi_screen.dart` | `matchesFilter`, `WipasRepository.markRead` |
| Profil & keluar | `ProfilScreen` `/profil`, `LainnyaScreen` `/lainnya` | `features/profil/profil_screen.dart`, `features/lainnya/lainnya_screen.dart` | `AuthController.signOut` |
| Kendali akses | semua rute | `lib/router.dart`, `core/domain/access_matrix.dart` | `roleGuard`, `AccessMatrix` |
| State layar | semua layar inti | `core/state/view_state.dart`, `core/widgets/state_view.dart` | `toViewState`, `WipasStateView` |

### (c) Entitas data (Firestore → kelas Dart di `lib/core/data/models.dart`)
`users` → `AppUser`; `warehouses` → `Warehouse`; `predictions` → `Prediction` (+ embed `InputFeatures`, `ManpowerRecommendation`); `operational_configs` → `OperationalConfig` (`CapacityConfig`); `decision_logs` → `DecisionLog`; `config_history` → `ConfigHistoryEntry`; `model_health` → `ModelHealth`; `model_health_history` → `ModelHealthPoint`; `batch_logs` → `BatchLog`; `dataset_status` → `DatasetStatus`; `notifications` → `AppNotification`; `users/{uid}/notification_reads` (tanpa kelas; set id); `daily_data` (ditulis script, tidak dimodelkan di aplikasi).

### (d) Alur bisnis utama
1. **Masuk**: Splash → Login → `AuthController` memuat `users/{uid}.role` → Beranda sesuai peran (`roleGuard`).
2. **Batch harian (Script)**: impor Excel → prediksi RF → tulis `predictions` (+manpower), `model_health`, `batch_logs`, `notifications`.
3. **Keputusan alokasi (Admin/Manajer)**: Beranda → Prediksi (tinjau deviasi) → Manpower → Cara hitung → Setujui (dialog) atau Sesuaikan (alasan wajib) → `decision_logs`.
4. **Input Actual (Admin/Supervisor)**: Beranda → Input Actual → validasi → simpan `actual_*` → perbandingan & dampak Rolling MAE.
5. **Ubah kapasitas (Admin/Manajer)**: Lainnya → Konfigurasi → validasi rasio = 1,00 → pratinjau → dialog → transaksi `operational_configs` + `config_history`.
6. **Tinjau model (Admin/Manajer/Viewer)**: Evaluasi → Model Degraded → Lihat feature importance → retraining manual di luar aplikasi.
7. **Notifikasi**: lonceng → filter / tandai dibaca → layar terkait.
8. **Export (Admin)**: Lainnya → Riwayat & Export → menyiapkan → berhasil (bagikan) / gagal (Coba lagi).
Offline: semua aksi tulis nonaktif ("Tidak tersedia saat offline").

## Daftar use case (N = 15)
| ID | Nama | Aktor |
|---|---|---|
| UC01 | Login | Admin, Manajer, Supervisor, Viewer |
| UC02 | Reset Kata Sandi | Admin, Manajer, Supervisor, Viewer |
| UC03 | Melihat Beranda | Admin, Manajer, Supervisor, Viewer |
| UC04 | Melihat Prediksi H+1/H+2 | Admin, Manajer, Supervisor, Viewer |
| UC05 | Melihat Rekomendasi Manpower | Admin, Manajer, Supervisor |
| UC06 | Menyetujui Rekomendasi | Admin, Manajer |
| UC07 | Menyesuaikan Manpower Manual | Admin, Manajer |
| UC08 | Melihat Evaluasi Model | Admin, Manajer, Viewer |
| UC09 | Input Actual Inbound | Admin, Supervisor |
| UC10 | Mengatur Konfigurasi Kapasitas | Admin, Manajer |
| UC11 | Melihat Riwayat dan Log Keputusan | Admin, Manajer, Supervisor, Viewer |
| UC12 | Export CSV Riwayat | Admin |
| UC13 | Mengelola Notifikasi | Admin, Manajer, Supervisor, Viewer |
| UC14 | Melihat Profil dan Keluar | Admin, Manajer, Supervisor, Viewer |
| UC15 | Menjalankan Batch Prediksi | Script Batch Prediksi |

Relasi: UC06 dan UC07 `<<extend>>` UC05; UC12 `<<extend>>` UC11; UC03–UC14 memerlukan sesi dari UC01 (dinyatakan di narasi, tidak digambar sebagai include agar diagram terbaca).

## Langkah 2–10 — Keluaran
| Langkah | Berkas | Hasil |
|---|---|---|
| 2 | `docs/use_case.txt` | N = 15 use case, 5 aktor (+ aktor abstrak *Pengguna* untuk 7 use case bersama), 3 relasi `<<extend>>` |
| 3 | `docs/activity.txt` | 15 diagram (sintaks baru, swimlane, ≤ 8 aktivitas) |
| 4 | `docs/sequence.txt` | 15 diagram (actor/boundary/control/entity, ≤ 4 lifeline, ≤ 10 pesan) |
| 5 | `docs/class.txt` | 8 kelas domain |
| 6 | `docs/database_design.html` | 13 koleksi/sub-koleksi, 105 field, object diagram |
| 7 | `docs/database_design_v2.html` | 17 tabel, 22 relasi; ERD, transformasi, LRS final, spesifikasi per tabel |
| 8 | `docs/blackbox_testing.html` | 48 skenario: **46 Lulus** (test otomatis), **2 Belum diuji** (UC15, script di repo riset) |
| 9 | `docs/whitebox_testing.html` | 8 fungsi, 42 basis path: **41 Lulus**, **1 Belum diuji** (WB-RG-P2) |
| 10 | `docs/uat.html` | 24 skenario, semua **Belum diuji** (untuk diisi manual) |
| 11 | `tools/check_docs.py`, `docs/index.html`, `docs/img/` | 127/127 pemeriksaan lulus; 52 PNG |

Generator (dapat dijalankan ulang): `tools/gen_db_docs.py` (dari `tools/docs_db_model.py`), `tools/gen_test_docs.py` (dari hasil `flutter test --reporter json`), `tools/gen_index.py`. Daftar use case baku: `tools/docs_uc.py`.

## Pemilihan 8 kelas domain (class.txt)
`Warehouse`, `AppUser`, `Prediction`, `ManpowerRecommendation`, `OperationalConfig`, `DecisionLog`, `ModelHealth`, `AppNotification` — semuanya kelas nyata di `lib/core/data/models.dart` (kecuali `OperationalConfig` yang memuat `CapacityConfig`). Dipilih karena membawa aturan bisnis inti: deviasi & Perlu Perhatian (`Prediction`), rumus manpower (`OperationalConfig` → `ManpowerRecommendation`), keputusan append-only (`DecisionLog`), drift (`ModelHealth`), audiens notifikasi (`AppNotification`), dan RBAC (`AppUser.role`). Tidak dipilih: `DailyData` (tidak dimodelkan di aplikasi), `ConfigHistoryEntry`, `ModelHealthPoint`, `BatchLog`, `DatasetStatus` (data pendukung tanpa perilaku domain). Metode `rasioValid()`, `hitungManpower()`, `untukRole()` adalah representasi domain dari `ConfigValidator`, `ManpowerCalculator`, dan filter `audience_roles`.

## Asumsi
1. Use case UC03–UC14 memerlukan sesi (UC01); tidak digambar sebagai `<<include>>` agar diagram terbaca.
2. Aktor abstrak **Pengguna** (generalisasi Admin, Manajer, Supervisor, Viewer) dipakai untuk 7 use case yang dimiliki semua peran; hak khusus tetap digambar per peran sesuai `AccessMatrix`.
3. Boundary/control/entity UC15 mengikuti prompt (`wipas predict`, modul `predict`, Firestore) karena kodenya ada di repo `wipas-research`.
4. Entity pada sequence memakai nama koleksi Firestore (`predictions`, `decision_logs`, `users`, …) atau layanan (`Firebase Auth`, `Berkas CSV`).
5. Model relasional v2 menambah tabel hasil normalisasi (`ConfigHistoryDetail`, `NotificationAudience`) dan tidak membuat tabel `ModelVersion` (skema hanya menyimpan label teks `model_version`).
6. Object diagram v1 memakai nilai ilustrasi skenario desain (18.420/15.900), bukan hasil model.
7. Blackbox "Lulus" bila semua test yang dirujuk lulus pada run JSON; satu test boleh membuktikan beberapa skenario (dicatat di Keterangan).

## Keterbatasan
- UAT belum dijalankan (butuh perangkat Android + pengguna).
- WB-RG-P2 (`/dev/gallery` pada build rilis) tidak dapat dieksekusi oleh `flutter test` karena `kDebugMode` konstanta kompilasi.
- UC15 tidak dapat diuji dari repo ini; kontrak datanya hanya diverifikasi tidak langsung lewat `test/unit/seed_data_test.dart`.
- Golden test sebagai bukti visual dibuat di Windows (tanpa emulator Android).

## Test yang ditambahkan untuk dokumentasi
- `test/unit/whitebox_test.dart` — 41 test basis path (`WB-MP`, `WB-DP`, `WB-DN`, `WB-CV`, `WB-AV`, `WB-RG`, `WB-CS`, `WB-VS`).
- `test/widget/flows_test.dart` — 2 test: login sukses lewat form; akun tanpa role valid ditolak.
- Tidak ada kode aplikasi yang diubah pada Tahap 2.
- Hasil run: `flutter test --reporter json` → **230 lulus, 0 gagal** (`docs/test_results.txt`).

## Keluaran check_docs
```
[OK ] Use case: jumlah 14–20 — N = 15
[OK ] Use case: nama & urutan = daftar baku (docs_uc.py)
[OK ] Use case: tanpa elemen 'participant'
[OK ] Use case: tanpa elemen 'database'
[OK ] Use case: tanpa elemen 'class'
[OK ] Use case: tanpa elemen 'lifeline'
[OK ] Use case: aktor manusia = role aplikasi — ['Admin', 'Manajer', 'Supervisor', 'Viewer']
[OK ] Activity: jumlah diagram = N — 15 vs N=15
[OK ] Activity: judul & urutan = use case
[OK ] Activity 'UC01 Login': ≤ 8 aktivitas — 6
[OK ] Activity 'UC01 Login': sintaks baru (start/stop)
[OK ] Activity 'UC02 Reset Kata Sandi': ≤ 8 aktivitas — 6
[OK ] Activity 'UC02 Reset Kata Sandi': sintaks baru (start/stop)
[OK ] Activity 'UC03 Melihat Beranda': ≤ 8 aktivitas — 6
[OK ] Activity 'UC03 Melihat Beranda': sintaks baru (start/stop)
[OK ] Activity 'UC04 Melihat Prediksi H+1/H+2': ≤ 8 aktivitas — 6
[OK ] Activity 'UC04 Melihat Prediksi H+1/H+2': sintaks baru (start/stop)
[OK ] Activity 'UC05 Melihat Rekomendasi Manpower': ≤ 8 aktivitas — 5
[OK ] Activity 'UC05 Melihat Rekomendasi Manpower': sintaks baru (start/stop)
[OK ] Activity 'UC06 Menyetujui Rekomendasi': ≤ 8 aktivitas — 5
[OK ] Activity 'UC06 Menyetujui Rekomendasi': sintaks baru (start/stop)
[OK ] Activity 'UC07 Menyesuaikan Manpower Manual': ≤ 8 aktivitas — 6
[OK ] Activity 'UC07 Menyesuaikan Manpower Manual': sintaks baru (start/stop)
[OK ] Activity 'UC08 Melihat Evaluasi Model': ≤ 8 aktivitas — 6
[OK ] Activity 'UC08 Melihat Evaluasi Model': sintaks baru (start/stop)
[OK ] Activity 'UC09 Input Actual Inbound': ≤ 8 aktivitas — 7
[OK ] Activity 'UC09 Input Actual Inbound': sintaks baru (start/stop)
[OK ] Activity 'UC10 Mengatur Konfigurasi Kapasitas': ≤ 8 aktivitas — 6
[OK ] Activity 'UC10 Mengatur Konfigurasi Kapasitas': sintaks baru (start/stop)
[OK ] Activity 'UC11 Melihat Riwayat dan Log Keputusan': ≤ 8 aktivitas — 6
[OK ] Activity 'UC11 Melihat Riwayat dan Log Keputusan': sintaks baru (start/stop)
[OK ] Activity 'UC12 Export CSV Riwayat': ≤ 8 aktivitas — 6
[OK ] Activity 'UC12 Export CSV Riwayat': sintaks baru (start/stop)
[OK ] Activity 'UC13 Mengelola Notifikasi': ≤ 8 aktivitas — 6
[OK ] Activity 'UC13 Mengelola Notifikasi': sintaks baru (start/stop)
[OK ] Activity 'UC14 Melihat Profil dan Keluar': ≤ 8 aktivitas — 5
[OK ] Activity 'UC14 Melihat Profil dan Keluar': sintaks baru (start/stop)
[OK ] Activity 'UC15 Menjalankan Batch Prediksi': ≤ 8 aktivitas — 6
[OK ] Activity 'UC15 Menjalankan Batch Prediksi': sintaks baru (start/stop)
[OK ] Sequence: jumlah diagram = N — 15 vs N=15
[OK ] Sequence: judul & urutan = use case
[OK ] Sequence: tanpa kata kunci 'participant'
[OK ] Sequence: tanpa kata kunci 'database'
[OK ] Sequence: tanpa kata kunci 'queue'
[OK ] Sequence 'UC01 Login': ≤ 4 lifeline — 4
[OK ] Sequence 'UC01 Login': ≤ 10 pesan — 8
[OK ] Sequence 'UC01 Login': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC02 Reset Kata Sandi': ≤ 4 lifeline — 4
[OK ] Sequence 'UC02 Reset Kata Sandi': ≤ 10 pesan — 7
[OK ] Sequence 'UC02 Reset Kata Sandi': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC03 Melihat Beranda': ≤ 4 lifeline — 4
[OK ] Sequence 'UC03 Melihat Beranda': ≤ 10 pesan — 7
[OK ] Sequence 'UC03 Melihat Beranda': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC04 Melihat Prediksi H+1/H+2': ≤ 4 lifeline — 4
[OK ] Sequence 'UC04 Melihat Prediksi H+1/H+2': ≤ 10 pesan — 7
[OK ] Sequence 'UC04 Melihat Prediksi H+1/H+2': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC05 Melihat Rekomendasi Manpower': ≤ 4 lifeline — 4
[OK ] Sequence 'UC05 Melihat Rekomendasi Manpower': ≤ 10 pesan — 7
[OK ] Sequence 'UC05 Melihat Rekomendasi Manpower': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC06 Menyetujui Rekomendasi': ≤ 4 lifeline — 4
[OK ] Sequence 'UC06 Menyetujui Rekomendasi': ≤ 10 pesan — 9
[OK ] Sequence 'UC06 Menyetujui Rekomendasi': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC07 Menyesuaikan Manpower Manual': ≤ 4 lifeline — 4
[OK ] Sequence 'UC07 Menyesuaikan Manpower Manual': ≤ 10 pesan — 7
[OK ] Sequence 'UC07 Menyesuaikan Manpower Manual': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC08 Melihat Evaluasi Model': ≤ 4 lifeline — 4
[OK ] Sequence 'UC08 Melihat Evaluasi Model': ≤ 10 pesan — 7
[OK ] Sequence 'UC08 Melihat Evaluasi Model': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC09 Input Actual Inbound': ≤ 4 lifeline — 4
[OK ] Sequence 'UC09 Input Actual Inbound': ≤ 10 pesan — 7
[OK ] Sequence 'UC09 Input Actual Inbound': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC10 Mengatur Konfigurasi Kapasitas': ≤ 4 lifeline — 4
[OK ] Sequence 'UC10 Mengatur Konfigurasi Kapasitas': ≤ 10 pesan — 7
[OK ] Sequence 'UC10 Mengatur Konfigurasi Kapasitas': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC11 Melihat Riwayat dan Log Keputusan': ≤ 4 lifeline — 4
[OK ] Sequence 'UC11 Melihat Riwayat dan Log Keputusan': ≤ 10 pesan — 6
[OK ] Sequence 'UC11 Melihat Riwayat dan Log Keputusan': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC12 Export CSV Riwayat': ≤ 4 lifeline — 4
[OK ] Sequence 'UC12 Export CSV Riwayat': ≤ 10 pesan — 8
[OK ] Sequence 'UC12 Export CSV Riwayat': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC13 Mengelola Notifikasi': ≤ 4 lifeline — 4
[OK ] Sequence 'UC13 Mengelola Notifikasi': ≤ 10 pesan — 9
[OK ] Sequence 'UC13 Mengelola Notifikasi': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC14 Melihat Profil dan Keluar': ≤ 4 lifeline — 4
[OK ] Sequence 'UC14 Melihat Profil dan Keluar': ≤ 10 pesan — 9
[OK ] Sequence 'UC14 Melihat Profil dan Keluar': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Sequence 'UC15 Menjalankan Batch Prediksi': ≤ 4 lifeline — 4
[OK ] Sequence 'UC15 Menjalankan Batch Prediksi': ≤ 10 pesan — 8
[OK ] Sequence 'UC15 Menjalankan Batch Prediksi': actor+boundary+control+entity — ['actor', 'boundary', 'control', 'entity']
[OK ] Class: ≤ 8 kelas — 8: Warehouse, AppUser, Prediction, ManpowerRecommendation, OperationalConfig, DecisionLog, ModelHealth, AppNotification
[OK ] Class: hanya entitas domain
[OK ] DB v2: entitas ERD = tabel LRS transformasi = LRS final = spesifikasi — ERD 17, LRS 17, spek 17
[OK ] DB v2: diagram ada di <pre class="plantuml">
[OK ] DB v2: catatan relasional konseptual
[OK ] DB v1: object diagram di <pre class="plantuml">
[OK ] Blackbox: setiap use case punya grup — 15
[OK ] Blackbox UC01: ≥ 2 skenario — 4
[OK ] Blackbox UC02: ≥ 2 skenario — 2
[OK ] Blackbox UC03: ≥ 2 skenario — 5
[OK ] Blackbox UC04: ≥ 2 skenario — 4
[OK ] Blackbox UC05: ≥ 2 skenario — 3
[OK ] Blackbox UC06: ≥ 2 skenario — 3
[OK ] Blackbox UC07: ≥ 2 skenario — 2
[OK ] Blackbox UC08: ≥ 2 skenario — 4
[OK ] Blackbox UC09: ≥ 2 skenario — 5
[OK ] Blackbox UC10: ≥ 2 skenario — 4
[OK ] Blackbox UC11: ≥ 2 skenario — 2
[OK ] Blackbox UC12: ≥ 2 skenario — 3
[OK ] Blackbox UC13: ≥ 2 skenario — 3
[OK ] Blackbox UC14: ≥ 2 skenario — 2
[OK ] Blackbox UC15: ≥ 2 skenario — 2
[OK ] UAT: role penguji = aktor manusia use case — ['Admin', 'Manajer', 'Supervisor', 'Viewer']
[OK ] Fitur: blackbox = UAT = use case — UAT tanpa: []
[OK ] UAT: status awal 'Belum diuji'
[OK ] Blackbox: setiap 'Lulus' menyebut test — 46 baris Lulus
[OK ] Render: semua PNG ada di docs/img
[OK ] Berkas ada: docs/use_case.txt
[OK ] Berkas ada: docs/activity.txt
[OK ] Berkas ada: docs/sequence.txt
[OK ] Berkas ada: docs/class.txt
[OK ] Berkas ada: docs/database_design.html
[OK ] Berkas ada: docs/database_design_v2.html
[OK ] Berkas ada: docs/blackbox_testing.html
[OK ] Berkas ada: docs/whitebox_testing.html
[OK ] Berkas ada: docs/uat.html
[OK ] Berkas ada: docs/index.html
[OK ] Berkas ada: docs/DOC_REPORT.md

127/127 pemeriksaan lulus.
```

## Langkah manual untuk saya
1. Jalankan UAT di perangkat Android (lihat `docs/HANDOFF.md` untuk emulator + seed), isi kolom Status (Pass/Fail), Tanggal, Penguji di `docs/uat.html`.
2. Verifikasi WB-RG-P2: pasang APK rilis, buka tautan `/dev/gallery` (mis. lewat deep link atau ubah rute sementara) → harus diarahkan ke Splash. Isi hasilnya di `docs/whitebox_testing.html`.
3. Uji UC15 di repo `wipas-research` (jalankan `wipas predict` normal dan saat actual H-1 kosong), lalu isi dua baris UC15 di blackbox.
4. Bila kode/test berubah, perbarui dokumen:
   ```bash
   flutter test --reporter json > build/test_results.json
   python tools/gen_test_docs.py build/test_results.json
   python tools/gen_db_docs.py
   python tools/gen_index.py
   java -jar tools/plantuml.jar -tpng -o img docs/use_case.txt docs/activity.txt docs/sequence.txt docs/class.txt
   java -jar tools/plantuml.jar -tpng docs/img/*.puml
   python tools/check_docs.py
   ```
   (Di Windows set `PYTHONIOENCODING=utf-8` bila konsol menolak karakter Unicode.)
