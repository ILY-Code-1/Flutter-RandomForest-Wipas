# Matriks akses per peran (RBAC)

Sumber kebenaran di kode: `lib/core/domain/access_matrix.dart` (`AccessMatrix`), dipakai oleh `roleGuard` di `lib/router.dart` dan oleh layar untuk menyembunyikan kontrol. Peran dibaca dari `users/{uid}.role`. Kontrol yang tidak diizinkan **disembunyikan**, bukan dinonaktifkan. Diuji di `test/unit/domain_test.dart` (setiap sel tabel) dan `test/widget/roles_test.dart`.

**Penuh** = melihat & bertindak · **Baca** = hanya melihat (`WipasReadOnlyChip`) · **—** = rute/tab tidak ada (diarahkan ke Beranda).

| Rute | Admin | Manajer | Supervisor | Viewer |
|---|---|---|---|---|
| `/splash`, `/login`, `/login/lupa` | Penuh | Penuh | Penuh | Penuh |
| `/beranda` | Penuh | Penuh | Penuh | Baca (tanpa kartu/tautan Manpower) |
| `/prediksi` | Baca | Baca | Baca (tanpa Faktor pendorong) | Baca |
| `/manpower` | Penuh | Penuh | Baca | — |
| `/evaluasi` | Penuh | Penuh | — | Baca |
| `/input-actual` | Penuh | — | Penuh | — |
| `/konfigurasi` | Penuh | Penuh | — | — |
| `/riwayat` | Penuh (Export CSV) | Baca | Baca | Baca (kolom keputusan disembunyikan) |
| `/notifikasi`, `/profil`, `/lainnya` | Penuh | Penuh | Penuh | Penuh |

Bottom nav: Admin & Manajer 5 tab; Supervisor tanpa Evaluasi; Viewer tanpa Manpower.

## Kontrol per peran
| Kontrol | Admin | Manajer | Supervisor | Viewer |
|---|---|---|---|---|
| Tombol Input Actual (Beranda) | ✓ | — | ✓ | — |
| Tombol Konfigurasi Kapasitas (Beranda) | ✓ | — | — | — |
| Kartu "Tinjau & Setujui Alokasi" (Beranda) | — | ✓ | — | — |
| Kartu Rekomendasi Manpower (Beranda) | ✓ | ✓ | ✓ (Hanya baca) | — |
| Kartu Model Health / Evaluasi Projection (Beranda) | Model Health | Model Health | Model Health (tanpa tautan) | 2 kartu ringkas |
| Setujui / Sesuaikan manual | ✓ | ✓ | — | — |
| Faktor pendorong (Prediksi) | ✓ | ✓ | — | ✓ |
| Export CSV | ✓ | — | — | — |
| Status keputusan di Riwayat | ✓ | ✓ | ✓ | — |
| Menu Konfigurasi (Lainnya) | ✓ | ✓ | — | — |

## Lapisan data (security rules)
`firebase/firestore.rules` menegakkan hal yang sama di server — lihat ringkasan di `docs/architecture.md` dan test di `firebase/rules-tests/rules.test.mjs`:
- `predictions`: baca semua user login; update hanya Admin/Supervisor dan hanya `actual_*` (int ≥ 0, `actual_input_by` = uid sendiri).
- `operational_configs`: update Admin/Manajer dengan validasi kapasitas > 0 dan rasio = 1,00.
- `predictions` (`decision_*`): update Admin/Manajer, hanya field `decision_*`, `decision_by` = uid sendiri, catatan wajib bila `adjusted`.
- `decision_logs`, `operational_configs/{wh}/history`: create Admin/Manajer (atas nama sendiri), baca Admin/Manajer/Supervisor, tanpa update/delete.
- `notifications`: baca bila role ada di `audience_roles`; tanpa create/delete; update hanya `read_by`.
- `users/{uid}`: baca dokumen sendiri. `notifications.read_by`: penerima (role ∈ `audience_roles`) hanya boleh menambahkan uid sendiri.
- Nilai role di Firestore: `admin`, `manager`, `supervisor`, `viewer` (enum Dart `Role.manajer` ↔ `manager`).
- Koleksi milik script: baca saja.
