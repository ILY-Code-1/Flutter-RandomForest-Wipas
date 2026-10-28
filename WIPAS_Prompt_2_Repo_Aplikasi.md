# WIPAS — Prompt #2: Repo Aplikasi Flutter (`wipas-app`)

Panduan langkah demi langkah (menyiapkan folder, menyalin berkas, menjalankan, mengecek) ada di file **WIPAS_Panduan_Eksekusi_Repo_Aplikasi.md**. Semua teks sebelum baris pembuka prompt di bawah ini adalah catatan untuk manusia dan diabaikan Claude Code.

=== MULAI PROMPT (mulai menyalin dari baris ini) ===

## PERAN & TUJUAN

Kamu adalah engineer Flutter senior. Bangun aplikasi Android **WIPAS** di repo **`wipas-app`**: sistem pendukung keputusan untuk memprediksi volume inbound gudang H+1 dan merekomendasikan manpower. Aplikasi ini **membaca** hasil prediksi yang ditulis script Python (repo `wipas-research`) dari Cloud Firestore, dan **menulis** hanya: actual inbound, keputusan manpower, konfigurasi kapasitas (beserta riwayatnya), dan status baca notifikasi.

Sumber kebenaran:
1. Desain visual: `docs/design/png/` (104 PNG). **Ikuti gambar** bila teks prompt dan gambar berbeda, lalu catat perbedaannya di `docs/design_deviations.md`. Halaman handoff adalah `5 · Daftar Layar & Alur.png`, `6 · Handoff · Token desain.png`, `7 · Handoff · Komponen.png`, dan `8 · Handoff · Layar & State.png`. Bacalah keempatnya lebih dulu.
2. Kontrak data: `docs/firestore_schema.md` (lihat ringkasan di bagian KONTRAK DATA).
3. Bahasa antarmuka: Indonesia. Kode dan komentar: Inggris. Dokumen (README dan docs): Indonesia.

## ATURAN KERJA

- Kerjakan semua fase berurutan, tanpa melompat. Ikuti MODE OTONOM di bawah.
- Verifikasi tiap fase: `flutter analyze` bersih dan test lulus. Bila emulator/perangkat Android tersedia (`flutter devices`), jalankan aplikasi, ambil tangkapan layar 360 x 800, bandingkan dengan PNG desain, dan perbaiki selisih. Bila tidak tersedia, gunakan widget test dan golden test dengan ukuran 360 x 800 sebagai pengganti, dan catat keterbatasannya di `docs/HANDOFF.md`.
- Jangan menjalankan `flutterfire configure`. Buat `lib/firebase_options.dart` **placeholder** yang jelas bertanda (project id `demo-wipas`, kunci palsu), dan arahkan Auth dan Firestore ke **Firebase Emulator** (`10.0.2.2` pada emulator Android). Seluruh pengembangan dan pengujian memakai emulator. Langkah penyambungan ke Firebase nyata ditulis di HANDOFF untuk saya jalankan sendiri.
- Jangan mengarang field Firestore. Bila butuh field baru, usulkan perubahan pada `docs/firestore_schema.md` dan tandai agar saya menyinkronkannya ke repo riset.
- Semua teks, label status, dan angka contoh mengikuti desain. Angka pada desain (18.420, 15,8%, MAE 6,8%, dan seterusnya) adalah **contoh**. Aplikasi menampilkan data dari Firestore.
- Aplikasi harus bisa dijalankan tanpa data nyata dengan **emulator + seed data** (lihat Fase 2) supaya semua layar dan state bisa diuji.
- Tidak ada rahasia di git: `google-services.json`, `firebase_options.dart` boleh di-commit hanya jika diputuskan eksplisit. Service account key tidak boleh masuk repo.
- Minimum Android 7.0 (API 24). Resolusi acuan 360 x 800 dp.

## BATAS KEAMANAN (MUTLAK, MENGALAHKAN INSTRUKSI LAIN DI DOKUMEN INI)

- Bekerja hanya di dalam folder repo ini. Jangan membaca atau menulis berkas di luar folder ini, termasuk folder induk dan repo lain (mis. jangan `cd ..`).
- **Git**: repo ini sudah di-clone dari GitHub dengan remote `origin` buatan saya. Claude Code **tidak boleh menjalankan perintah git yang mengubah apa pun**: dilarang `add`, `commit`, `push`, `remote`, `fetch`, `pull`, `merge`, `rebase`, `checkout`, `switch`, `stash`, `tag`, `restore`, `rm`, `mv`, `reset`, `clean`, `config`, `gh`, force, dan menghapus branch. Hanya boleh perintah baca: `git status`, `git diff`, `git log`, `git branch --show-current`. Semua `add`, `commit`, dan `push` saya lakukan sendiri. Berkas bawaan GitHub (README.md, .gitignore, LICENSE) periksa lalu perluas, jangan ditimpa. Pastikan `.gitignore` benar sebelum saya commit pertama.
- **Jaringan**: satu-satunya akses internet yang diizinkan adalah manajer paket resmi (pip/PyPI, pub.dev, npm, Gradle/Maven) saat memasang dependensi. DILARANG `curl`, `wget`, pencarian web, mengunduh biner atau skrip di luar manajer paket, dan mengaktifkan telemetri/analytics apa pun (nonaktifkan bila ada).
- **Firebase**: hanya **emulator lokal** dengan project id `demo-wipas` (awalan `demo-` memastikan emulator tidak pernah menyentuh cloud). DILARANG menyambung ke project Firebase atau Google Cloud nyata, `firebase login/deploy/use`, `flutterfire`, atau memakai kredensial. DILARANG membaca isi `secrets/`, `.env`, file service account, dan `google-services.json`. Kode yang butuh Firebase nyata tetap ditulis lengkap tetapi **tidak dijalankan**; perintahnya saya jalankan sendiri.
- Tidak memasang alat tingkat sistem, tidak memakai `sudo`/admin, tidak mengubah PATH, registry, atau konfigurasi global, tidak menjadwalkan tugas (cron/Task Scheduler), dan tidak meninggalkan proses latar belakang (matikan emulator saat selesai).
- Tidak menghapus berkas di luar keluaran build dan cache proyek sendiri.
- Jika suatu langkah memerlukan hal yang dilarang, **jangan lakukan**. Tulis perintah persisnya di `docs/HANDOFF.md` (atau `docs/DOC_REPORT.md`) bagian "Langkah manual untuk saya", lalu lanjutkan pekerjaan lain.

## MODE OTONOM (WAJIB)

- Kerjakan **seluruh fase dari awal sampai akhir dalam satu sesi** tanpa berhenti untuk meminta konfirmasi. Jangan menawarkan "mau lanjut?" dan jangan berhenti di tengah untuk merangkum.
- Berhenti hanya jika terblokir hal yang **hanya bisa saya lakukan** (kredensial tidak ada, file masukan tidak ada, instalasi alat butuh hak admin). Dalam kasus itu kerjakan dulu semua bagian lain yang tidak bergantung padanya, lalu catat blokir tersebut di `docs/HANDOFF.md`.
- Keputusan ambigu: pilih default paling masuk akal, catat di `ASSUMPTIONS.md` (butir, alasan, dampak), lalu lanjut.
- Error: cari akar masalah dan perbaiki, maksimum 3 pendekatan berbeda per masalah. **Dilarang** menghapus test, melemahkan assertion, atau memberi `skip` agar test lulus. Jika tetap gagal, catat di `docs/HANDOFF.md` bagian "Masalah terbuka" dengan pesan error lengkap dan lanjutkan fase lain.
- Setelah tiap fase: jalankan verifikasi fase itu, tulis hasil nyata (perintah + ringkasan keluaran) ke `PROGRESS.md`. Jangan pernah menulis "lulus" tanpa benar-benar menjalankannya.
- Fase terakhir adalah **audit mandiri**: telusuri seluruh KRITERIA SELESAI butir demi butir, jalankan ulang semua verifikasi dari keadaan bersih, perbaiki yang gagal, lalu tulis `docs/HANDOFF.md`.

## STACK

Flutter 3.x (Dart 3), Material 3, `flutter_riverpod`, `go_router`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `fl_chart`, `intl` (locale id_ID), `connectivity_plus`, `shared_preferences`, `share_plus` + `path_provider` (export CSV), `csv`. Font **Inter** disertakan sebagai asset (jangan mengunduh saat runtime, karena aplikasi harus bisa offline). Test: `flutter_test`, `mocktail`, serta `firebase emulators` dan `@firebase/rules-unit-testing` (Node) untuk security rules.

Arsitektur feature-first:

```
lib/
  main.dart  app.dart  router.dart
  core/
    theme/   (tokens, WipasColors, WipasText, WipasSpace, WipasRadius, WipasSize, theme)
    widgets/ (komponen Wipas*)
    format/  (id-ID: angka, persen, tanggal, waktu WIB)
    domain/  (ManpowerCalculator, DeviationCalculator, Role, access matrix)
    data/    (firestore refs, converters, repositories, connectivity/sync)
  features/
    auth/ beranda/ prediksi/ manpower/ evaluasi/ input_actual/
    konfigurasi/ riwayat/ notifikasi/ profil/ lainnya/
test/  integration_test/  firebase/ (rules, emulator, seed)  tools/  docs/
```

Setiap layar memakai satu `sealed class ViewState` (Loading, Empty, Error, Offline(lastSync), Data), sesuai halaman handoff.

## TOKEN DESAIN (verifikasi terhadap `6 · Handoff · Token desain.png`)

Warna: navy `#1F3A5F`, primaryLight `#3B6FB6`, teal `#0F9D8A`, tealText `#0B7C6D`, link `#2F5F9F`, success `#2E7D32` (tint `#E8F4E9`, teks `#1B5E20`), warning `#F9A825` (tint `#FFF4D6`, teks `#7A4F00`), danger `#C62828` (tint `#FBE9E9`, teks `#8E1B1B`), info `#1565C0` (tint `#E3F0FC`, teks `#0D3A73`), background `#F5F7FA`, surface `#FFFFFF`, border `#DDE3EC`, divider `#EEF1F6`, textPrimary `#1B2433`, textSecondary `#5B6779`, seriesProjection `#7A8CA5`.
Tipografi (Inter): Title 20/28 w600, Heading 16/24 w600, Body 14/20, BodySmall 13/18, Caption 12/16 w500–600 (minimum 12), KPI 28/32 w700 dengan angka tabular, Button 14/20 w600.
Spacing: 4, 8, 12, 16, 24, 32. Radius: kartu 12, kontrol 10, sheet 16, pill 999. Ukuran: touch target minimal 48, app bar 64, bottom nav 80, badge 28.
Tema terang saja (tanpa dark mode). Hormati reduced-motion. Teks harus tetap terbaca pada skala font hingga 130% tanpa terpotong.

Buat komponen berawalan `Wipas` seperti pada halaman handoff Komponen: AppBarTop, AppBarSub, BottomNav, RoleChip, ReadOnlyChip, StatusBadge (selalu ikon + teks), AlertBanner (info, warning, danger, success), OfflineBanner, KpiCard, ChartCard, FeatureBar, DataRow, SegmentedControl, FilterChip (area sentuh 48), DatePickerStrip, TextField, NumericStepper, Switch, PrimaryButton, SecondaryButton, DestructiveButton, TextButton, BottomSheet, ConfirmDialog, SnackBar, SkeletonLoader, EmptyState, ErrorState, ListTile, NotificationTile, DecisionLogItem.

## PERAN, RUTE, DAN AKSES

Peran berasal dari `users/{uid}.role` (admin, manajer, supervisor, viewer). Kontrol yang tidak diizinkan **disembunyikan**, bukan dinonaktifkan. Layar hanya baca memakai `WipasReadOnlyChip`.

| Rute | Admin | Manajer | Supervisor | Viewer |
|---|---|---|---|---|
| `/splash`, `/login`, `/login/lupa` | ya | ya | ya | ya |
| `/beranda` | penuh | penuh | penuh | hanya baca (tanpa kartu/tautan Manpower) |
| `/prediksi` | hanya baca | hanya baca | hanya baca (tanpa Faktor pendorong) | hanya baca |
| `/manpower` | penuh | penuh | hanya baca | tidak ada |
| `/evaluasi` | penuh | penuh | tidak ada | hanya baca |
| `/input-actual` | penuh | tidak ada | penuh | tidak ada |
| `/konfigurasi` | penuh | penuh | tidak ada | tidak ada |
| `/riwayat` | penuh (Export CSV) | hanya baca | hanya baca | hanya baca (kolom keputusan disembunyikan) |
| `/notifikasi`, `/profil`, `/lainnya` | penuh | penuh | penuh | penuh |

Bottom nav 5 tab (Beranda, Prediksi, Manpower, Evaluasi, Lainnya); Viewer tanpa Manpower, Supervisor tanpa Evaluasi (indikator tab bergeser sesuai). Implementasikan `RoleGuard` pada go_router dan satu sumber kebenaran `AccessMatrix` di `core/domain`, lalu uji dengan unit test untuk tiap peran. Sesi berakhir otomatis setelah 24 jam (tampilkan layar Login dengan pesan sesi berakhir). Reset password memakai Firebase (email).

## LOGIKA BISNIS

- **Deviasi** = (Predicted − Projection) / Projection. Jika |deviasi| lebih dari 15%, status **Perlu Perhatian** (banner warning, badge pada baris riwayat).
- **Manpower (ceil):** Rider = ⌈Predicted × ratio_rider / capacity_rider⌉; Driver = ⌈Predicted × ratio_driver / capacity_driver⌉; Op. Inbound = ⌈Predicted / capacity_op_inbound⌉; Op. Outbound = ⌈Predicted / capacity_op_outbound⌉. Default 350 / 800 / 500 / 600 dan rasio 0,70 / 0,30. Prediksi 18.420 harus menghasilkan 37 / 7 / 37 / 31. Aplikasi **membaca** manpower dari dokumen prediksi, dan menghitungnya sendiri hanya untuk **Pratinjau dampak** di Konfigurasi (gunakan `ManpowerCalculator` yang diuji).
- **Validasi Konfigurasi:** semua kapasitas lebih dari 0, rasio Rider + Driver = 1,00 (toleransi 0,001), pesan galat seperti desain. Tombol Simpan nonaktif saat ada galat. Simpan memunculkan dialog konfirmasi, lalu menulis `operational_configs/{wh}` dan `config_history` dalam satu transaksi.
- **Keputusan manpower:** Setujui (dialog konfirmasi) atau Sesuaikan manual (jumlah per kategori + **alasan wajib**). Hasilnya ditulis ke `decision_logs` (append-only) dan status tampil sebagai Disetujui atau Disesuaikan. Status awal "Menunggu keputusan" (sesuai teks di desain untuk tiap peran).
- **Input Actual:** angka bulat, tidak kosong, tidak negatif. Setelah tersimpan tampilkan perbandingan dengan Predicted dan dampak ke Rolling MAE. Aplikasi hanya menulis field `actual_*` pada dokumen prediksi.
- **Model Health:** tampilkan status Sehat atau Model Degraded dari `model_health` (nilai dihitung script, bukan aplikasi). Kartu status batch dan status dataset ada di Evaluasi.
- **Fallback H-2:** bila `data_status` bukan "complete", tampilkan Data Incomplete Warning dan label sumber H-2 (lihat layar Prediksi Viewer · Fallback H-2).
- **Notifikasi:** query berdasarkan `audience_roles` berisi peran pengguna, status baca disimpan per pengguna di `users/{uid}/notification_reads/{notifId}`; filter chip (Semua, Belum dibaca, Deviasi, dan seterusnya) dengan efek pudar di tepi kanan bila chip lebih dari 4; "Tandai semua dibaca".
- **Export CSV (Admin saja):** buat berkas di perangkat dari data rentang tanggal yang dipilih (prediksi, actual, deviasi, keputusan), dengan state menyiapkan, berhasil (bagikan), dan gagal (Coba lagi). Awali dengan BOM UTF-8 dan pemisah koma.
- **Format id-ID:** ribuan titik, desimal koma, persen "15,8%", tanggal "Kam, 8 Okt 2026", waktu "23:02 WIB" (zona Asia/Jakarta, bukan zona perangkat).

## OFFLINE & STATE

- Aktifkan Firestore persistence bawaan (jangan memakai drift atau hive). Deteksi offline dengan `connectivity_plus` dan `snapshot.metadata.isFromCache`.
- Saat offline tampilkan `WipasOfflineBanner`: "Mode offline · menampilkan data tersimpan" + "Terakhir disinkronkan: ..." (simpan cap waktu sinkronisasi server terakhir di `shared_preferences`). Semua aksi tulis (Setujui, Sesuaikan, Simpan, Simpan actual, Export) **nonaktif** dengan keterangan "Tidak tersedia saat offline". Perhatikan: jika tombol sebelumnya tersembunyi karena peran, tetap tersembunyi.
- State layar inti (Beranda, Prediksi, Manpower, Evaluasi): skeleton, kosong (Prediksi: "Belum ada prediksi untuk tanggal terpilih" + tombol Kembali ke H+1), galat ("Gagal memuat data" + Coba lagi; setelah 3 kegagalan tampilkan saran menghubungi IT Support), dan offline.
- Batasi pembacaan: gunakan query dengan rentang tanggal dan `limit` (14 atau 30 hari), jangan membaca seluruh koleksi. Paket gratis Spark memiliki kuota baca 50.000 per hari.

## KONTRAK DATA (ringkasan; berkas lengkap: `docs/firestore_schema.md`)

`wh_id` default `WH-CKG-01`. ID dokumen: `predictions/pred_{wh}_{YYYYMMDD}`, `daily_data/{wh}_{YYYYMMDD}`, `operational_configs/{wh}`, `model_health/{wh}`, `model_health_history/{wh}_{YYYYMMDD}`, `batch_logs/{wh}_{YYYYMMDD}`, `dataset_status/{wh}`, `notifications/{type}_{wh}_{YYYYMMDD}`, `users/{uid}`, `config_history/{auto}`, `decision_logs/{auto}`.

- `predictions`: `wh_id`, `target_date`, `predicted`, `projection`, `deviation_pct`, `alert`, `status`, `data_status`, `source`, `model_version`, `generated_at`, `input_features` (10 fitur), `feature_importance`, `manpower` {rider, driver, op_inbound, op_outbound, config_snapshot}, `is_backfill`. Milik aplikasi: `actual_inbound`, `actual_note`, `actual_input_by`, `actual_input_at`. Milik script: `daily_error_pct`, `evaluated`.
- `operational_configs`: `capacity_rider`, `capacity_driver`, `capacity_op_inbound`, `capacity_op_outbound`, `ratio_rider`, `ratio_driver`, `rounding`, `updated_by`, `updated_at`.
- `decision_logs`: `pred_id`, `wh_id`, `decided_by`, `decided_by_name`, `decision` (approved atau adjusted), `manpower_final`, `reason`, `decided_at`.
- `config_history`: `wh_id`, `changed_by`, `changed_by_name`, `changed_at`, `old_values`, `new_values`.
- `model_health`: `status` (healthy, degraded), `rolling_mae_7d`, `baseline_mae`, `drift_threshold`, `model_version`, `mae_validation`, `rmse`, `r2`, `feature_importance`, `updated_at`.
- `notifications`: `type` (deviation, degraded, incomplete, batch), `title`, `body`, `wh_id`, `target_date`, `created_at`, `audience_roles`.

Buat model Dart dengan converter dari dan ke Firestore, tahan terhadap field null atau hilang (UI memakai state kosong, bukan crash).

## SECURITY RULES (`firebase/firestore.rules`) + TEST

Tulis rules dan uji dengan emulator (`firebase/rules-tests/`). Prinsip: tolak secara default, ambil peran dari `users/{uid}.role`.
- `predictions`: baca untuk semua pengguna terautentikasi; update hanya oleh admin atau supervisor dan hanya field `actual_inbound`, `actual_note`, `actual_input_by`, `actual_input_at` (gunakan `request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])`), nilai `actual_inbound` bilangan bulat tidak negatif; tidak ada create atau delete dari klien.
- `operational_configs`: baca semua; update oleh admin atau manajer dengan validasi (kapasitas lebih dari 0, rasio berjumlah 1,00).
- `config_history`, `decision_logs`: create oleh admin atau manajer (`decided_by == request.auth.uid`), baca oleh admin, manajer, supervisor (khusus `decision_logs`: viewer ditolak), tanpa update atau delete (append-only).
- `notifications`: baca bila peran ada di `audience_roles`; tanpa tulis dari klien.
- `users/{uid}/notification_reads/*`: baca dan tulis hanya oleh pemilik.
- `daily_data`, `model_health*`, `batch_logs`, `dataset_status`, `warehouses`: baca untuk pengguna terautentikasi, tanpa tulis dari klien.
- Sediakan `firestore.indexes.json` untuk query yang dipakai aplikasi (mis. `predictions` berdasarkan `wh_id` dan `target_date` menurun; `notifications` berdasarkan `audience_roles` dan `created_at` menurun).
- Test rules harus mencakup setiap peran untuk operasi yang diizinkan dan ditolak.

## FASE

**Fase 0 — Scaffold & tema.** Buat proyek, struktur folder, konfigurasi Firebase Emulator (tanpa FlutterFire), font Inter, token, tema Material 3, dan komponen Wipas dasar (tombol, badge, banner, kartu, skeleton, empty/error state). Buat halaman galeri komponen (`/dev/gallery`, hanya mode debug) untuk membandingkannya dengan PNG.

**Fase 1 — Auth, peran, navigasi.** Splash, Login (normal, error, loading, sesi berakhir), Lupa password (+ konfirmasi), `AuthState` + peran dari `users/{uid}`, go_router + RoleGuard, bottom nav per peran, layar Lainnya dan Profil (dialog Keluar). Unit test `AccessMatrix`.

**Fase 2 — Data layer & seed.** Model, converter, repositori (stream dengan rentang tanggal), `ConnectivityService` + cap sinkronisasi. Skrip seed untuk emulator di `firebase/seed/` (bahasa Node atau Dart) yang membuat 4 akun demo (admin, manajer, supervisor, viewer) beserta `users/{uid}`, `operational_configs` bawaan, dan data contoh 14 hari (prediksi, actual, model_health, notifikasi, batch_logs, dataset_status) yang konsisten dengan skenario desain (deviasi 15,8%, fallback H-2, status Sehat dan Degraded). Panduan menjalankan emulator di `docs/setup_firebase.md`.

**Fase 3 — Beranda & Prediksi.** Semua varian peran, date strip H+1, banner Perlu Perhatian / Data Incomplete / Model Degraded, KPI, grafik tren 14 hari (`fl_chart`: Projection putus-putus, Predicted tebal teal, Actual navy), tabel dan grafik di Prediksi (SegmentedControl H+1/H+2 dan Tabel/Grafik), input model, Faktor pendorong (disembunyikan untuk Supervisor). Seluruh state.

**Fase 4 — Manpower & keputusan.** Kartu 4 kategori, sheet Cara hitung, dialog Setujui, sheet Sesuaikan manual (alasan wajib), log keputusan, varian Admin, Manajer, dan Supervisor hanya baca. Menulis `decision_logs`. Tombol aksi nonaktif saat offline.

**Fase 5 — Evaluasi & Notifikasi.** Kesehatan model, grafik Rolling MAE 7 hari (label baseline dan ambang tidak tertimpa garis), metrik validasi, evaluasi Projection Tim DI, status batch, status dataset, tautan feature importance saat Model Degraded. Notifikasi lengkap dengan filter, status baca, dan empty state.

**Fase 6 — Input Actual & Konfigurasi.** Form validasi (kosong, negatif), perbandingan dengan prediksi dan dampak Rolling MAE, pengingat belum input (Supervisor), data fitur hanya baca, SnackBar sukses. Konfigurasi: NumericStepper, pratinjau dampak, galat rasio dan nilai, dialog konfirmasi, riwayat perubahan.

**Fase 7 — Riwayat & Export.** Daftar riwayat per peran (badge Perlu Perhatian pada deviasi lebih dari 15%), filter 7 atau 14 hari dan rentang tanggal, Export CSV (Admin) dengan tiga state.

**Fase 8 — Penyelesaian.** Audit aksesibilitas (touch target, kontras, label semantik, skala font 130%), polesan offline di semua layar, performa (muat dashboard kurang dari 3 detik), perbaikan selisih visual, dokumentasi, dan pengujian menyeluruh.

**Fase 9 — Audit mandiri & handoff.** Dari keadaan bersih (`flutter clean`, `flutter pub get`) jalankan `flutter analyze`, `flutter test`, rules test pada emulator, integration test, dan `flutter build apk --release`. Telusuri **KRITERIA SELESAI** butir demi butir dengan bukti. Periksa seluruh 17 layar pada `docs/design/png/` terhadap implementasi (daftar centang per layar dan per peran di `docs/design_parity.md`, tandai yang masih berbeda beserta alasannya). Pastikan tidak ada rahasia di git. Tulis `docs/HANDOFF.md` dengan bagian: Ringkasan, Cara menjalankan, Akun demo, Asumsi (rujuk `ASSUMPTIONS.md`), Masalah terbuka, **Langkah manual untuk saya** (bernomor, langsung bisa diikuti), dan **Checklist pengujian untuk saya** (per peran: apa yang harus terlihat dan apa yang harus tersembunyi).

## PENGUJIAN & DOKUMENTASI

- Unit test: `ManpowerCalculator` (termasuk contoh 18.420 menghasilkan 37/7/37/31 dan kasus batas pembulatan), `DeviationCalculator` (15,8%, tepat 15% bukan alert), formatter id-ID, `AccessMatrix`, validator Konfigurasi, converter model dengan field hilang.
- Widget test: tiap layar inti untuk kelima state, dan perilaku per peran (elemen tersembunyi vs terlihat).
- Rules test dengan emulator (lihat di atas).
- Satu integration test alur utama (login manajer, menyetujui rekomendasi, log tercatat) pada emulator.
- Dokumen: `README.md` (setup, menjalankan emulator, akun demo, build APK), `docs/architecture.md`, `docs/rbac_matrix.md`, `docs/setup_firebase.md` (membuat project Spark, mengaktifkan Auth dan Firestore, deploy rules dan indeks, membuat akun demo), `docs/design_deviations.md`, `docs/testing.md`.

## KRITERIA SELESAI

- `flutter analyze` bersih, semua test (Dart dan rules) hijau, `flutter build apk --release` berhasil.
- Semua layar pada `docs/design/png/` dapat dicapai dan tampil sesuai desain untuk tiap peran dan state (dengan data seed).
- Akses per peran sesuai tabel, dan rules menolak operasi yang tidak diizinkan.
- Aplikasi berjalan penuh di Firebase Emulator dengan data seed, dan HANDOFF memuat langkah bernomor untuk menyambungkannya ke Firestore nyata (agar dapat membaca prediksi dari `wipas-research`) yang saya jalankan sendiri.
- Mode offline menampilkan data tersimpan dan menonaktifkan aksi tulis.
- Di akhir, tampilkan: daftar fase yang selesai, selisih desain, asumsi, dan langkah manual yang perlu saya lakukan (mis. membuat akun, deploy rules, membuat indeks).

Mulai sekarang dari Fase 0 (baca halaman handoff 5 sampai 8 terlebih dahulu), lalu lanjutkan otomatis sampai Fase 9 selesai. Laporan akhir lengkap ada di `docs/HANDOFF.md`.
