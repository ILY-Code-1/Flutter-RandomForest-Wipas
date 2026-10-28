# Kesesuaian desain — 17 layar × peran

Acuan: `docs/design/png/5 · Daftar Layar & Alur.png` (17 baris layar) dan PNG per layar/state.
Metode: **tidak ada emulator Android** saat pengerjaan (`flutter devices` hanya Windows/Chrome/Edge), sehingga pembanding visual memakai **golden test 360 × 800** (`test/golden/goldens/*.png`, dibandingkan manual dengan PNG desain) dan **widget test** untuk keberadaan/ketiadaan elemen per peran. Kolom "Bukti" menunjuk berkas golden dan/atau test.

Legenda: ✅ sesuai · ◐ sesuai dengan selisih tercatat (nomor = `docs/design_deviations.md`) · — peran tidak punya akses (diverifikasi diarahkan ke Beranda) · ⏳ belum diverifikasi visual (hanya widget test).

| # | Layar | Admin | Manajer | Supervisor | Viewer | State yang dicek | Bukti |
|---|---|---|---|---|---|---|---|
| 1 | Splash | ⏳ | ⏳ | ⏳ | ⏳ | normal | dibuka di setiap widget test (1,5 dtk) |
| 2 | Login | ◐ 5 | ◐ 5 | ◐ 5 | ◐ 5 | normal, error kredensial, loading, sesi berakhir | `login.png`; flows_test (Auth) |
| 3 | Lupa password | ✅ | ✅ | ✅ | ✅ | normal, error email, terkirim | flows_test "forgot password" |
| 4 | Konfirmasi reset | ✅ | ✅ | ✅ | ✅ | normal | flows_test "forgot password" |
| 5 | Beranda | ✅ | ✅ | ✅ | ✅ | normal, loading, kosong, galat, offline, Perlu Perhatian, Model Degraded, Data Incomplete | `beranda_*.png`; core_states_test; roles_test |
| 6 | Prediksi | ◐ 2, 9 | ◐ 2 | ◐ 2 (tanpa Faktor pendorong) | ◐ 2 | normal, loading, kosong, galat, offline, H+1/H+2, Tabel/Grafik, fallback H-2 | `prediksi_*.png`; core_states_test; roles_test |
| 7 | Rekomendasi Manpower | ✅ | ✅ | ✅ (hanya baca) | — | normal, loading, kosong, galat, offline, belum diputuskan, disetujui, disesuaikan | `manpower_*.png`; flows_test; roles_test |
| 8 | ↳ Sheet Cara hitung | ✅ | ✅ | ✅ | — | normal | flows_test "Cara hitung" |
| 9 | ↳ Dialog Setujui | ✅ | ✅ | — | — | normal, batal, offline (nonaktif) | flows_test |
| 10 | ↳ Sheet Sesuaikan manual | ✅ | ✅ | — | — | normal, alasan kosong | flows_test |
| 11 | Evaluasi & Model Health | ◐ 10 | ◐ 10 | — | ◐ 10 (hanya baca) | normal, loading, kosong, galat, offline, sehat, degraded | `evaluasi_*.png`; core_states_test |
| 12 | Input Actual Inbound | ◐ 12 | — | ◐ 12 | — | kosong, terisi + perbandingan, error kosong, error negatif, sukses, offline, pengingat | `input_actual_supervisor.png`; flows_test |
| 13 | Lainnya | ✅ | ✅ | ✅ | ✅ | normal (menu per peran) | `lainnya_admin.png`; roles_test |
| 14 | Konfigurasi Kapasitas | ◐ 1 | ◐ 1 | — | — | normal, diubah + pratinjau, error rasio, error nilai, dialog, tersimpan + riwayat | `konfigurasi_admin.png`; flows_test |
| 15 | Riwayat (Export CSV Admin) | ◐ 7, 10 | ✅ | ✅ | ✅ (tanpa keputusan) | normal, 7/14 hari, menyiapkan, berhasil, gagal, offline | `riwayat_admin.png`; flows_test; roles_test |
| 16 | Notifikasi | ◐ 6 | ◐ 6 | ◐ 6 (hanya relevan) | ◐ 6 | normal, filter aktif, kosong, degraded | `notifikasi_admin.png`; flows_test; roles_test |
| 17 | Profil & Pengaturan | ◐ 8 | ◐ 8 | ◐ 8 | ◐ 8 | normal, dialog Keluar | `profil_admin.png`; flows_test "logout" |

## Catatan per layar (yang masih berbeda)
- **Splash**: tidak ada golden (animasi progres tak tentu); tampilan diperiksa manual terhadap kode, belum di perangkat.
- **Golden peran lain** (mis. Notifikasi Viewer, Profil Supervisor) tidak dibuat terpisah karena tata letaknya identik dengan Admin; perbedaan isi per peran diuji di widget test.
- **Angka**: golden memakai data seed (mis. Rolling MAE 1,6% di skenario normal), bukan angka contoh desain (6,8%). Ini disengaja (ASSUMPTIONS #7).
- **Belum di perangkat Android**: date picker, share sheet, ripple, persistence offline nyata — lihat HANDOFF "Checklist pengujian untuk saya".
