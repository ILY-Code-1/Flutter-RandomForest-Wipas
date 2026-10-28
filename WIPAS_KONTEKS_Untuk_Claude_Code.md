# WIPAS — Konteks Proyek untuk Claude Code

Berkas ini adalah latar belakang. Instruksi kerja ada di dua berkas prompt `WIPAS_Prompt_*.md` di root repo (prompt pengembangan dan prompt dokumentasi). Bila ada konflik antar sumber, ikuti urutan prioritas ini lalu catat konfliknya di `ASSUMPTIONS.md`:

1. Dua berkas `WIPAS_Prompt_*.md` (instruksi kerja)
2. Desain UI di `docs/design/png/` (hanya untuk tampilan, repo aplikasi)
3. `docs/firestore_schema.md` (kontrak data antar dua repo)
4. Berkas ini
5. BRD di `docs/referensi/BRD.html` (referensi; **besar**, jangan dibaca utuh, cari bagian yang perlu dengan `grep`)

## Tentang proyek

WIPAS (Warehouse Inbound Prediction & Allocation System) adalah aplikasi pendukung keputusan untuk skripsi. Ia memprediksi volume inbound gudang esok hari (H+1) dengan Random Forest, lalu mengubahnya menjadi rekomendasi manpower (Rider, Driver, Op. Inbound, Op. Outbound). Ada dua repo terpisah:

- `wipas-research` (Python): melatih model, mengimpor Excel, menjalankan batch prediksi, memantau drift, menulis ke Firestore.
- `wipas-app` (Flutter): membaca hasil dari Firestore dan menulis hanya actual inbound, keputusan manpower, konfigurasi kapasitas (beserta riwayat), dan status baca notifikasi.

Pemilik proyek adalah Shift Lead di bidang logistik. Bahasa antarmuka dan dokumen: Indonesia. Kode dan komentar: Inggris.

## Keputusan implementasi yang SENGAJA berbeda dari BRD (jangan "memperbaiki" ke arah BRD)

- Peran Admin dipegang Shift Lead. Akun Manajer, Supervisor, dan Viewer adalah akun demo. Tidak ada layar registrasi atau manajemen pengguna (akun dibuat lewat Firebase Console).
- Fitur prediktor diimpor dari Excel oleh script Python. Aplikasi **hanya** menginput Actual Inbound. Excel harus memuat baris tanggal target dengan fitur terisi dan actual kosong.
- Prediksi dijalankan manual lewat script yang idempotent dan bisa dijadwalkan. Tidak ada Cloud Functions, tidak ada paket Blaze, hanya Firebase Spark (gratis).
- Notifikasi hanya di dalam aplikasi (tanpa push).
- Offline memakai Firestore offline persistence bawaan, bukan drift atau hive.
- Retraining model tidak otomatis; dijalankan manual lewat CLI.
- Tidak ada: iOS, dark mode, web, registrasi, push notification.

## Definisi yang dipakai (konsisten di dua repo)

- `daily_error_pct = |predicted − actual| / actual × 100`. MAE dalam persen.
- `Baseline_MAE` = MAE validasi (%) dari model aktif. Drift bila `Rolling_MAE_7d > 1,15 × Baseline_MAE`.
- Deviasi = (Predicted − Projection) / Projection; di atas 15% (nilai mutlak) berstatus **Perlu Perhatian**.
- Manpower (dibulatkan ke atas): Rider = ⌈P×0,70/350⌉, Driver = ⌈P×0,30/800⌉, Op. Inbound = ⌈P/500⌉, Op. Outbound = ⌈P/600⌉. Prediksi 18.420 harus menghasilkan 37 / 7 / 37 / 31.
- 10 fitur: hari, bulan, campaign, hari libur, payday, pickup request H-1, projection inbound, backlog H-1, actual H-2, actual H-1. Target: Actual Inbound.
- Fallback H-2: bila actual terbaru belum ada, pakai actual hari sebelumnya, tandai `incomplete_fallback_h2`, dan buat notifikasi.

## Angka yang BUKAN hasil nyata

Angka pada desain dan contoh (MAE 6,8%, baseline 6,2%, RMSE 9,4%, R² 0,89, prediksi 18.420, projection 15.900, deviasi 15,8%) hanya contoh tampilan. Metrik asli harus berasal dari data dan model yang benar-benar dijalankan. Jangan memaksakan hasil model mendekati angka itu.

## Ketidakkonsistenan di BRD (jangan dipecahkan sendiri, cukup catat)

- BR6/FR4.8 menyebut ambang "15%", sedangkan rumus yang dipakai adalah 1,15 × baseline.
- Istilah MAE vs MAPE bercampur; repo ini memakai MAE dalam persen seperti didefinisikan di atas.
- Definisi "H-1" bisa ambigu; ikuti definisi pada prompt pengembangan.
- Projection Tim DI dipakai sebagai fitur sekaligus sebagai pembanding (benchmark). Ini disengaja, dibahas di metodologi.

## Kesalahan yang sering terjadi (hindari)

- Membuat subfolder pembungkus (mis. `wipas-app/wipas-app/`). Root folder git adalah root proyek.
- Menghapus atau memindahkan berkas `WIPAS_*.md`, `docs/referensi/`, `tools/plantuml.jar`, atau `.claude/`.
- Mengarang data pelatihan atau field Firestore di luar kontrak.
- Mengubah rumus manpower, ambang drift, atau peran akses tanpa dasar di berkas ini.
- Menandai test "lulus" tanpa menjalankannya, atau melemahkan test agar lulus.
- Menyentuh Firebase nyata, GitHub, atau jaringan di luar manajer paket.
- Menjalankan git yang mengubah apa pun (add, commit, push, checkout, dan sebagainya) atau mengubah remote `origin`. Repo sudah di-clone dari GitHub; Claude Code hanya menulis berkas, dan saya sendiri yang melakukan add, commit, dan push.
- Membaca atau menulis di luar folder repo ini (termasuk repo satunya lagi). Pertukaran berkas antar repo saya lakukan manual.
