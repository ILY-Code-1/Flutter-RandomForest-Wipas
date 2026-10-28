# Asumsi & keputusan ambigu — wipas-app

Format: **butir** — alasan — dampak.

## Data & kontrak
1. **`docs/firestore_schema.md` dibuat di repo ini** dari tabel kontrak prompt — berkas belum ada saat pengerjaan — field bertanda [USULAN] perlu disinkronkan ke `wipas-research`.
2. **Tanggal kalender disimpan sebagai string `YYYY-MM-DD` (WIB)** — query rentang tanggal sederhana dan tidak bergeser karena zona waktu — script Python harus menulis format yang sama.
3. **`day_of_week` 1 = Senin … 7 = Minggu** (ISO) — konsisten dengan Dart `DateTime.weekday` — perlu disamakan di script.
4. **Field rinci `model_health_history`, `batch_logs`, `dataset_status`, `warehouses`, `users.job_title`** diusulkan sendiri — prompt hanya menyebut ID dokumen — lihat skema; aplikasi tetap aman bila field hilang (state kosong / "—").
5. **Persen disimpan dalam satuan persen** (15.8), `feature_importance` dalam pecahan 0–1 — sesuai contoh desain — script harus konsisten.
6. **Audiens notifikasi**: deviasi & incomplete → semua role; degraded → admin, manajer, viewer (Supervisor tidak memiliki Evaluasi); batch → admin, manajer — mengikuti layar "Notifikasi · Supervisor (hanya yang relevan)" — script menentukan nilai akhirnya.
7. **Data seed adalah sintetis** dan sengaja memuat angka skenario desain (18.420 / 15.900 / 15,8%) — prompt meminta seed konsisten dengan desain — bukan hasil model; Rolling MAE seed skenario normal ±1,6% (dihitung dari data seed), bukan 6,8%.

## Logika bisnis
8. **Deviasi tepat 15% bukan alert** (`> 15`, dibandingkan setelah dibulatkan 4 desimal untuk meredam galat float) — sesuai prompt "lebih dari 15%".
9. **Pembulatan manpower memakai epsilon 1e-9** sebelum `ceil` — mencegah 3 × 0,3 / 0,9 = 1,0000000002 menjadi 2 — hasil 18.420 → 37/7/37/31 tetap.
10. **Selisih di Input Actual = (Actual − Predicted) / Predicted** — cocok dengan contoh desain (+360 → +2,1% dari 17.200) — status "Normal" bila ≤ 15%.
11. **Dampak Rolling MAE di Input Actual dihitung aplikasi sebagai estimasi** (rata-rata error 7 hari terakhir dengan actual baru), diberi label "estimasi aplikasi, nilai resmi dihitung script" — prompt: nilai Model Health dihitung script.
12. **Pengingat "Actual hari ini belum diinput" (Supervisor)** muncul bila dokumen prediksi hari ini ada dan `actual_inbound` kosong — tidak ada definisi jam akhir shift di sumber.
13. **"Hari >15%" di Evaluasi Projection** = jumlah hari dengan deviasi Predicted vs Projection > 15% — mengikuti teks penjelas di desain.
14. **Target metrik validasi** MAE ≤ 10%, RMSE ≤ 15%, R² ≥ 0,85 — diambil dari desain.
15. **Input Actual hanya untuk 14 hari terakhir** dan hanya bila dokumen prediksi tanggal itu sudah ada (aplikasi tidak boleh membuat dokumen prediksi).
16. **Keputusan manpower mengikuti entri log terbaru**; setelah ada keputusan, tombol Setujui/Sesuaikan disembunyikan (log append-only, tidak bisa diubah).
17. **Rentang kustom Riwayat dibatasi 31 hari per query** — hemat kuota baca Spark.

## Akses & sesi
18. **`users/{uid}` hanya bisa dibaca pemiliknya**; nama pada log memakai field denormalisasi `*_by_name` — tidak perlu membaca profil orang lain.
19. **Viewer tidak pernah meng-query `decision_logs`** (rules menolaknya); kolom keputusan disembunyikan.
20. **Sesi 24 jam dihitung sejak login berhasil** (cap waktu di `shared_preferences`), diperiksa saat aplikasi dibuka dan kembali ke foreground.
21. **Panel "Demo prototipe · masuk sebagai" di Login hanya tampil pada build emulator** (`SHOW_DEMO_LOGIN`, default = `USE_EMULATOR`) — memakai password demo yang dibuat seed; tidak muncul di build produksi.
22. **Tap notifikasi** = tandai dibaca + buka layar terkait (Prediksi untuk deviasi/data; Evaluasi untuk model/batch bila role punya akses).
23. **Sakelar "Notifikasi di perangkat" di Profil** hanya preferensi lokal (tidak ada push notification pada rilis ini).

## Teknis
24. **`lib/firebase_options.dart` berisi placeholder `demo-wipas` dan boleh di-commit** — tidak berisi rahasia; keputusan eksplisit. Setelah `flutterfire configure` (nyata) berkas ini tertimpa: putuskan sendiri apakah di-commit (kunci API Firebase klien bukan rahasia, tetapi `google-services.json` di-ignore).
25. **Ikon memakai Material Icons bawaan Flutter** (bukan Material Symbols outlined) — tidak boleh mengunduh aset di luar manajer paket.
26. **Font Inter (OFL) diambil dari paket npm `inter-font@3.19.0`** (static 400/500/600/700) — prompt melarang unduhan runtime; npm termasuk manajer paket yang diizinkan.
27. **Riverpod 2.x (`StateProvider`/`StateNotifier`)** — versi yang terpasang lewat `flutter pub add`.

## Ketidakkonsistenan BRD (dicatat, tidak dipecahkan)
- BR6/FR4.8 menyebut ambang "15%", rumus yang dipakai 1,15 × baseline.
- Istilah MAE vs MAPE bercampur; aplikasi memakai "MAE (%)" untuk error model dan "MAPE" hanya pada label tabel Evaluasi Projection (mengikuti desain).
- Projection Tim DI dipakai sebagai fitur sekaligus pembanding — disengaja.
