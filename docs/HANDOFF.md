# HANDOFF — wipas-app

_Status per 28 Okt 2026. Hasil verifikasi di bawah berasal dari perintah yang benar-benar dijalankan pada audit akhir (Fase 9); rinciannya juga di `PROGRESS.md`._

## Ringkasan
Aplikasi Android Flutter WIPAS selesai untuk seluruh 17 layar pada `docs/design/png/` (Splash, Login, Lupa password + konfirmasi, Beranda, Prediksi, Manpower + sheet Cara hitung / dialog Setujui / sheet Sesuaikan, Evaluasi, Input Actual, Lainnya, Konfigurasi, Riwayat & Export, Notifikasi, Profil) untuk empat peran, dengan state loading/kosong/galat/offline/data. Data dari Cloud Firestore; seluruh pengembangan dan test memakai Firebase Emulator / Firestore palsu dengan data seed (`demo-wipas`). Belum pernah disambungkan ke Firebase nyata.

### Hasil verifikasi (audit akhir, dari keadaan bersih)
| Perintah | Hasil nyata |
|---|---|
| `flutter clean` → `flutter pub get` | berhasil |
| `flutter analyze` | **No issues found!** |
| `flutter test` (unit 89 + widget 76 + golden 22) | **+187: All tests passed!** |
| `flutter test --reporter json` setelah Tahap 2 (ditambah 41 test whitebox + 2 test login) | **230 lulus, 0 gagal** (`docs/test_results.txt`); `flutter analyze` tetap bersih |
| `flutter build apk --release` | **√ Built `build/app/outputs/flutter-apk/app-release.apk` (56.1MB)** |
| Rules test (`firebase/rules-tests`, 111 kasus) | **Belum dijalankan** — butuh emulator Firestore (lihat Masalah terbuka #2) |
| Integration test (`integration_test/`) | **Belum dijalankan** — tidak ada perangkat/emulator Android |
| Pemindaian rahasia (kunci API, private key, service account, google-services.json, keystore) | tidak ditemukan |

Catatan audit: run pertama dari keadaan bersih menghasilkan 6 golden Beranda gagal (selisih 0,05–0,56%) karena header Beranda diubah setelah golden dibuat. Penyebab dipastikan (perbaikan chip peran), tata letak diperbaiki lagi (chip "Manajer Warehouse" sempat terpotong), golden dibuat ulang setelah diperiksa visual, lalu seluruh suite dijalankan ulang hingga hijau.

### KRITERIA SELESAI (prompt pengembangan)
| Kriteria | Status | Bukti |
|---|---|---|
| `flutter analyze` bersih | ✅ | tabel di atas |
| Semua test Dart hijau | ✅ | +187 passed |
| Rules test hijau | ⏳ belum dijalankan | ditulis lengkap; langkah manual #2 |
| `flutter build apk --release` berhasil | ✅ | APK 56,1 MB |
| Semua layar desain dapat dicapai & sesuai per peran/state (data seed) | ◐ | `docs/design_parity.md`; verifikasi via golden + widget test, belum di perangkat |
| Akses per peran sesuai tabel | ✅ | `domain_test.dart` (setiap sel), `roles_test.dart` |
| Rules menolak operasi tak diizinkan | ⏳ | `rules.test.mjs` belum dijalankan di emulator |
| Berjalan penuh di emulator dengan seed + langkah ke Firestore nyata | ◐ | seed & app ditulis untuk emulator; diuji dengan Firestore palsu berisi seed yang sama; langkah bernomor #6 |
| Offline: data tersimpan tampil, aksi tulis nonaktif | ✅ (simulasi) | `core_states_test` (offline), `flows_test` (offline Manpower/Input Actual) |


### Fase
| Fase | Status |
|---|---|
| 0 Scaffold & tema | Selesai (token, tema M3, 30 komponen `Wipas*`, galeri `/dev/gallery` debug) |
| 1 Auth, peran, navigasi | Selesai |
| 2 Data layer & seed | Selesai (seed 4 skenario) |
| 3 Beranda & Prediksi | Selesai |
| 4 Manpower & keputusan | Selesai |
| 5 Evaluasi & Notifikasi | Selesai |
| 6 Input Actual & Konfigurasi | Selesai |
| 7 Riwayat & Export | Selesai |
| 8 Penyelesaian | Selesai, kecuali verifikasi di perangkat (tidak ada emulator Android) |
| 9 Audit & handoff | Selesai (lihat hasil di atas) |

## Cara menjalankan
Lihat `README.md` dan `docs/setup_firebase.md`. Singkatnya:
```bash
flutter pub get
firebase emulators:start --only auth,firestore --project demo-wipas
dart run firebase/seed/seed.dart            # atau --scenario=degraded|fallback|empty
flutter run
```

## Akun demo
Password semua: `wipas-demo-123` (hanya di emulator, dibuat oleh seed).

| Role | Email | Nama tampil |
|---|---|---|
| Admin (Shift Lead) | admin.shift@wipas.example | Admin WIPAS · Shift Lead |
| Manajer | manajer@wipas.example | Budi Santoso |
| Supervisor | supervisor@wipas.example | Rina Putri |
| Viewer (Tim DI) | viewer@wipas.example | Dewi Lestari |

## Asumsi
Lihat `ASSUMPTIONS.md` (27 butir + catatan ketidakkonsistenan BRD). Yang paling berdampak ke repo riset:
- `docs/firestore_schema.md` **dibuat di repo ini**; field bertanda [USULAN] (`model_health_history`, `batch_logs`, `dataset_status`, `warehouses`, `users.job_title`, format tanggal `YYYY-MM-DD` WIB, `day_of_week` 1 = Senin) harus diterapkan juga di `wipas-research`.
- Selisih desain: `docs/design_deviations.md`; kesesuaian per layar: `docs/design_parity.md`.

## Masalah terbuka
1. **Tidak ada emulator/perangkat Android** di mesin pengerjaan (`flutter devices`: Windows, Chrome, Edge). Pembandingan visual memakai golden test 360 × 800, bukan tangkapan layar perangkat. Integration test (`integration_test/approve_flow_test.dart`) **belum dijalankan**.
2. **Rules test belum dijalankan terhadap emulator.** Firebase CLI tidak terpasang secara global dan emulator Firestore mengunduh JAR di luar manajer paket (dilarang dalam sesi ini). `npm install` di `firebase/rules-tests` berhasil, `node --check` lolos, modul `@firebase/rules-unit-testing`/`firebase` ter-resolve; tanpa emulator `npm test` menghasilkan 111 test yang dibatalkan (bukan gagal logika). Perintah ada di langkah manual.
3. **Skrip seed belum dijalankan terhadap emulator** (alasan sama). Isi seed diverifikasi lewat `test/unit/seed_data_test.dart` dan dipakai oleh semua widget/golden test melalui Firestore palsu.
4. **APK rilis ditandatangani kunci debug** (bawaan `flutter create`). Untuk distribusi, buat keystore sendiri (langkah manual).
5. **Golden dirender di Windows**; di OS lain bisa berbeda beberapa piksel. Perbarui dengan `flutter test --update-goldens test/golden` di mesin acuan.
6. Persistence offline Firestore, date picker, dan share sheet Android belum dicoba di perangkat (perilaku offline diuji dengan connectivity palsu).

## Langkah manual untuk saya
1. **Pasang Firebase CLI** (sekali): `npm install -g firebase-tools`
2. **Jalankan rules test di emulator:**
   ```bash
   cd firebase/rules-tests
   npm install
   npm run test:emulator
   cd ../..
   ```
   Harapan: `# pass 111`, `# fail 0`.
3. **Jalankan emulator + seed + aplikasi:**
   ```bash
   firebase emulators:start --only auth,firestore --project demo-wipas
   # terminal lain
   dart run firebase/seed/seed.dart
   flutter emulators                  # lihat AVD; buat di Android Studio bila belum ada (API 24+, 360×800 mis. Pixel 4a)
   flutter emulators --launch <nama_avd>
   flutter run
   ```
4. **Integration test:** dengan emulator Firebase + seed + AVD menyala: `flutter test integration_test`
5. **Uji tiap peran** dengan checklist di bawah; coba juga `--scenario=degraded`, `--scenario=fallback`, `--scenario=empty` (jalankan seed ulang lalu tarik-untuk-muat/restart aplikasi).
6. **Sambungkan ke Firebase nyata (Spark)** — urutan rinci di `docs/setup_firebase.md` bagian B:
   1. Buat project di https://console.firebase.google.com (paket Spark).
   2. Aktifkan Authentication → Email/Password.
   3. Buat Firestore (production mode, `asia-southeast2`).
   4. `firebase login`
   5. `dart pub global activate flutterfire_cli`
   6. `flutterfire configure --project=<project-id> --platforms=android` (menimpa `lib/firebase_options.dart`, membuat `android/app/google-services.json` — sudah di-ignore).
   7. `firebase deploy --only firestore:rules,firestore:indexes --project <project-id>`
   8. Console → Authentication → Add user (Shift Lead + akun demo). Catat UID.
   9. Console → Firestore: buat `users/<UID>` (`display_name`, `email`, `role`, `wh_id`=`WH-CKG-01`, `job_title` opsional), `warehouses/WH-CKG-01` (`name`=`Hub Cakung`), `operational_configs/WH-CKG-01` (350/800/500/600, 0.7/0.3, `rounding`=`ceil`).
   10. Sinkronkan `docs/firestore_schema.md` ke repo `wipas-research`, jalankan impor Excel + batch prediksi di sana agar `predictions`, `model_health`, `batch_logs`, `dataset_status`, `notifications` terisi.
   11. `flutter build apk --release --dart-define=USE_EMULATOR=false`
7. **(Opsional) kunci rilis:** `keytool -genkey -v -keystore %USERPROFILE%\wipas-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias wipas`, buat `android/key.properties` (di-ignore) dan konfigurasikan `signingConfigs` di `android/app/build.gradle.kts`.
8. **HP fisik ke emulator di laptop:** tambahkan IP LAN laptop sebagai `<domain>` di `android/app/src/main/res/xml/network_security_config.xml`, lalu `flutter run --dart-define=EMULATOR_HOST=<IP>`.
9. **Commit pertama:** periksa `git status` (`.gitignore` sudah mengecualikan build, rahasia, `google-services.json`, `node_modules`), lalu `git add`, `git commit`, `git push` sendiri.

## Checklist pengujian untuk saya
Login dengan tiap akun demo (seed `normal`, tanggal = hari ini).

### Admin (admin.shift@wipas.example)
- Terlihat: 5 tab (Beranda, Prediksi, Manpower, Evaluasi, Lainnya); chip "Admin"; lonceng dengan badge; banner deviasi "…diteruskan ke Manajer Warehouse"; tombol **Input Actual Inbound** dan **Konfigurasi Kapasitas**; 4 KPI; grafik tren 14 hari; kartu Rekomendasi Manpower + "Lihat detail"; kartu Model Health + "Lihat Evaluasi".
- Prediksi: chip "Hanya baca", H+1/H+2, Tabel/Grafik (7/14/30 hari), Input model, **Faktor pendorong**.
- Manpower: **Setujui rekomendasi** dan **Sesuaikan manual**; Cara hitung Rider = (18.420 × 0,70) ÷ 350 = 36,84 → 37.
- Input Actual: kosong → "Actual inbound wajib diisi."; `-5` → "Nilai tidak boleh negatif."; angka valid → perbandingan + dampak Rolling MAE + SnackBar.
- Konfigurasi: Ratio_Rider 0,60 → galat rasio, Simpan nonaktif; ubah Capacity_Rider 400 → pratinjau 33, dialog konfirmasi, riwayat baru.
- Lainnya → Riwayat & export: **Export CSV** (menyiapkan → berhasil + bagikan); berkas dibuka di spreadsheet dengan huruf benar (BOM UTF-8).
- Tersembunyi: kartu "Tinjau & Setujui Alokasi".

### Manajer (manajer@wipas.example)
- Terlihat: 5 tab; banner deviasi dengan Predicted/Projection/Selisih; kartu **Alokasi … Menunggu persetujuan** + "Tinjau & Setujui Alokasi"; Konfigurasi di Lainnya; Evaluasi penuh.
- Alur: Tinjau → Manpower → Setujui (dialog) → status "Disetujui" + log; atau Sesuaikan (alasan wajib) → "Disesuaikan manual".
- Tersembunyi: tombol Input Actual, Export CSV.

### Supervisor (supervisor@wipas.example)
- Terlihat: 4 tab (tanpa **Evaluasi**); tombol Input Actual; pengingat "Actual hari ini belum diinput" (seed `fallback`); Manpower dengan chip **Hanya baca** dan Cara hitung; Riwayat dengan status keputusan.
- Tersembunyi: Setujui/Sesuaikan, Konfigurasi (Beranda & Lainnya), Faktor pendorong di Prediksi, tautan "Lihat Evaluasi", Export CSV, notifikasi batch/degraded. Membuka `/evaluasi` atau `/konfigurasi` → kembali ke Beranda.

### Viewer (viewer@wipas.example)
- Terlihat: 4 tab (tanpa **Manpower**); chip "Viewer · Tim DI"; "Hanya baca · Dashboard tanpa akses ubah"; kartu Model Health & Evaluasi Projection; Evaluasi hanya baca; Prediksi dengan Faktor pendorong; Fallback H-2 (seed `fallback`).
- Tersembunyi: kartu/tautan Manpower, Input Actual, Konfigurasi, Export CSV, kolom keputusan di Riwayat.

### Semua peran
- Mode pesawat: banner "Mode offline · menampilkan data tersimpan" + "Terakhir disinkronkan: …"; aksi tulis nonaktif dengan "Tidak tersedia saat offline".
- Notifikasi: filter chip (Semua, Belum dibaca, Deviasi, …) memudar di tepi kanan; "Tandai semua dibaca"; seed `empty` → "Belum ada notifikasi".
- Profil → Keluar (dialog) → Login. Ubah jam perangkat +25 jam lalu buka aplikasi → Login dengan banner "Sesi berakhir".
- Pengaturan → ukuran font terbesar (≈130%): teks tidak terpotong.
- Seed `degraded`: banner/badge **Model Degraded**, tombol "Lihat feature importance" di Evaluasi.
- Seed `empty`: Beranda "Belum ada data batch", Prediksi "Belum ada prediksi", dst.
