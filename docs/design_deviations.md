# Selisih implementasi vs desain

Desain di `docs/design/png/` adalah acuan. Daftar ini mencatat perbedaan yang **disengaja** atau **belum terselesaikan**. Pembanding visual dilakukan dengan golden test 360 × 800 (`test/golden/goldens/`), bukan tangkapan layar perangkat (tidak ada emulator Android saat pengerjaan).

## Teks prompt vs gambar (gambar diikuti)
| # | Bagian | Prompt | Gambar / implementasi |
|---|---|---|---|
| 1 | Konfigurasi | "NumericStepper" | Gambar memakai text field berlabel `Capacity_*`/`Ratio_*` + satuan. Implementasi mengikuti gambar; `WipasNumericStepper` dipakai di sheet Sesuaikan manual (sesuai gambar). |
| 2 | Prediksi | SegmentedControl H+1/H+2 dan Tabel/Grafik | PNG Prediksi hanya menampilkan Tabel/Grafik dan chip 7/14/30 hari. H+1/H+2 diambil dari handoff 8 ("H+1/H+2") dan ditaruh di atas kartu target. Saat batch hanya menghasilkan H+1, pilihan H+2 menampilkan state kosong + "Kembali ke H+1". |
| 3 | Status awal Manpower | "Menunggu keputusan" | Gambar Manpower: "Menunggu persetujuan Manajer"; Beranda Manajer: "Menunggu persetujuan"; Riwayat: "Menunggu keputusan". Masing-masing mengikuti gambarnya. |

## Perbedaan visual yang disengaja
| # | Layar | Perbedaan | Alasan |
|---|---|---|---|
| 4 | Semua | Ikon Material Icons (filled/outlined bawaan), bukan Material Symbols outlined stroke 2. Ikon Rider memakai `pedal_bike`. | Tanpa unduhan aset di luar manajer paket. |
| 5 | Login | Panel "Demo prototipe" hanya pada build emulator. | Tidak pantas di produksi (lihat ASSUMPTIONS #21). |
| 6 | Notifikasi | Chip filter: Semua, Belum dibaca (n), Deviasi, Model, Data, Batch. Desain hanya memperlihatkan 3½ chip pertama. | Chip sisanya disimpulkan dari tipe notifikasi. |
| 7 | Export CSV · berhasil | Lembar bagikan Android dibuka otomatis + tombol "Bagikan" pada banner. | Prompt: "berhasil (bagikan)". |
| 8 | Profil | "WIPAS 1.0.0 (build 1)" | Build number nyata dari `pubspec.yaml`, bukan "build 12". |
| 9 | Prediksi tabel | Label "contoh" per baris tidak ditampilkan. | Data berasal dari Firestore, bukan ilustrasi. |
| 10 | Evaluasi / Riwayat | Catatan "Data harian contoh." / "Nilai contoh kecuali …" tidak ditampilkan. | Sama seperti #9. |
| 11 | Model Health Beranda | Kalimat status dibuat dari data ("Sehat, tetapi mendekati ambang drift (selisih x poin)" hanya bila selisih ≤ 0,5 poin). | Teks desain bergantung pada angka contoh. |
| 12 | Input Actual | Kotak "Dampak ke Rolling MAE" diberi keterangan "estimasi aplikasi, nilai resmi dihitung script". | ASSUMPTIONS #11. |
| 13 | App bar | Tinggi app bar bertambah mengikuti skala teks (hingga 130%). | Teks judul terpotong pada 130% saat diuji. |

## Belum diverifikasi di perangkat
- Rendering font, bayangan, dan ripple di Android asli; golden dibuat di Windows (renderer test Flutter).
- Date picker dan date range picker Material (locale id) dan lembar bagikan Android.
- Perilaku offline nyata (persistence Firestore) — di test disimulasikan dengan connectivity palsu.
