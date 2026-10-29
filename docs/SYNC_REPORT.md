# SYNC_REPORT — Sinkronisasi aplikasi dengan kontrak Firestore

**Acuan:** `docs/firestore_schema.md`, kontrak **v1.0 (2026-10-28)** dari repo `wipas-research` (sumber kebenaran).
**Tanggal sinkronisasi:** 29 Okt 2026.
**Cakupan yang dibandingkan:** model Dart & converter (`lib/core/data/models.dart`), repository (`lib/core/data/repository.dart`), layar yang menulis/membaca field terkait, seed emulator (`firebase/seed/seed_data.dart`), security rules (`firebase/firestore.rules`), indeks (`firebase/firestore.indexes.json`), rules test (`firebase/rules-tests/rules.test.mjs`), dan test Dart.

Semua perbaikan dilakukan di sisi aplikasi; kontrak tidak diubah.

## 1. Selisih yang ditemukan dan diperbaiki

### 1.1 Peran & pengguna (`users/{uid}`)
| # | Sebelum (aplikasi) | Kontrak | Perbaikan |
|---|---|---|---|
| 1 | Nilai role `manajer` | `manager` | `Role.manajer.id = 'manager'` (`lib/core/domain/role.dart`); rules, seed, rules test memakai `manager`. Akun dengan `role: "manajer"` kini ditolak (test). |
| 2 | Nama di `display_name` | `name` | `AppUser.fromDoc` membaca `name`. |
| 3 | `email`, `wh_id`, `job_title` di dokumen user | Tidak ada di kontrak | Email diambil dari Firebase Auth; `wh_id` default `WH-CKG-01` bila tidak ada; label chip role kini tetap per role (`Role.chipLabel`). Seed hanya menulis `role` dan `name`. |

### 1.2 `warehouses/{wh_id}`
| 4 | `name`, `city` | `name`, `code`, `timezone`, `created_at` | Seed menulis keempat field kontrak; `Warehouse` membaca `code`/`timezone`; `city` dihapus. |

### 1.3 `daily_data/{wh_id}_{YYYYMMDD}` (hanya seed; aplikasi tidak membaca)
| 5 | `day_of_week`, `month`, `is_campaign`/`is_holiday`/`is_payday` (bool), `actual_inbound_h1/h2` | `campaign`, `hari_libur`, `payday` (int 0/1), tanpa hari/bulan/actual H-1/H-2, + `actual_source`, `actual_synced_at`, `row_hash`, `imported_at` | Seed ditulis ulang sesuai kontrak. |

### 1.4 `predictions/pred_{wh_id}_{YYYYMMDD}`
| # | Sebelum | Kontrak | Perbaikan |
|---|---|---|---|
| 6 | Kunci `input_features`: `day_of_week`, `month`, `is_campaign`, `is_holiday`, `is_payday`, `actual_inbound_h2`, `actual_inbound_h1` | `hari`, `bulan`, `campaign`, `hari_libur`, `payday`, `actual_h2`, `actual_h1` | `InputFeatures.fromMap` dan `featureLabels` memakai kunci kontrak (dipakai juga untuk `feature_importance`). **Tanpa perbaikan ini kartu "Input model" dan "Faktor pendorong" akan kosong/berlabel mentah pada data nyata.** |
| 7 | `hari` 1 = Senin (asumsi) | 0 = Senin (contoh kontrak: 2026-10-01 Kamis → `hari: 3`) | Seed memakai `weekday − 1`; dokumentasi field diperbarui. |
| 8 | Flag boolean | int 0/1 | Converter menerima keduanya; seed menulis 0/1. |
| 9 | `status`: `normal`/`perlu_perhatian` | `"Normal"`/`"Perlu Perhatian"` | Seed + konstanta `PredictionStatus`. Aplikasi tetap menurunkan status dari `alert`/deviasi. |
| 10 | `deviation_pct` 1 desimal | 2 desimal, boleh `null`; `projection` boleh `null` | Seed 2 desimal; converter & UI sudah null-tolerant (ditambah test `projection: null`). |
| 11 | `manpower.config_snapshot` tanpa `rounding`/`source` | + `rounding`, `source` (`firestore`/`default`) | Seed menulis keduanya; `ManpowerRecommendation.snapshotSource` dibaca. |
| 12 | Tidak ada `is_dummy_data`, `notes`, `evaluated_at` | Wajib/opsional di kontrak | Dibaca di model; `notes` (mis. catatan fallback H-2) kini ditampilkan di kartu target Prediksi. Seed menulisnya. |
| 13 | Keputusan hanya di `decision_logs` | Field App `decision_status`, `decision_by`, `decision_at`, `decision_note`, `decision_manpower` di prediksi | `WipasRepository.addDecision` menulis `decision_logs` **dan** `decision_*` dalam satu batch. Beranda, Manpower, Riwayat, dan CSV membaca status dari `decision_*` (Riwayat tidak lagi meng-query log, kecuali Admin untuk nama di CSV). Rules mengizinkan admin/manager mengubah **hanya** `decision_*`. |
| 14 | `actual_input_by` selalu uid | Bisa `"backfill:excel"` | Aplikasi tidak memvalidasi isinya saat membaca; seed memakai `backfill:excel` untuk actual lama. |

### 1.5 `operational_configs` dan riwayat
| 15 | Tidak ada `wh_id` di dokumen | `wh_id` wajib | `saveConfig` menulis `wh_id`; rules mewajibkan `wh_id == {whId}` dan mengizinkannya di `hasOnly`. |
| 16 | Riwayat di koleksi top-level `config_history` dengan `old_values`/`new_values` | Sub-koleksi `operational_configs/{wh_id}/history/{auto}`: salinan field konfigurasi + `changed_by`, `changed_at`, `note` | Transaksi menulis ke sub-koleksi; ringkasan "lama → baru" disimpan di `note`; layar Konfigurasi menampilkan `note`. Query riwayat memakai sub-koleksi; indeks `config_history` dihapus. |
| 17 | `updated_by` selalu uid | Bisa `"wipas-research:seed-config"` | Tidak ada asumsi uid saat membaca. |

### 1.6 `model_health`, `model_health_history`
| 18 | Field `rolling_window_days`, `n_points`, `last_evaluated_date`, `drift_factor`, `mae_validation_paket`, `rmse_paket`, `trained_at`, `is_dummy_data` tidak dikenal | Wajib | Dibaca di `ModelHealth`; ambang cadangan memakai `drift_factor` bila `drift_threshold` hilang. Seed menulis semuanya (+ `n_points`, `model_version`, `updated_at` di history), `drift_threshold` dibulatkan 4 desimal. |
| 19 | Query riwayat `date` ASC | Indeks kontrak `wh_id` ASC, `date` DESC | Query diubah ke `date` DESC + `limit`, lalu dibalik di klien; indeks disamakan. |

### 1.7 `batch_logs`
| 20 | `duration_sec`, `retry_count`, `run_date` | `duration_s` (number), `retries`, tanpa `run_date`; + `data_status`, `model_version`, `predicted`, `evaluated_dates`, `error`, `dry_run` | `BatchLog.fromMap` membaca field kontrak; `error` ditampilkan di Evaluasi. |
| 21 | Status `success`/`failed` | + `skipped` | Label "Dilewati (prediksi sudah ada)", tidak dianggap gagal. |
| 22 | ID memakai tanggal eksekusi | `{wh_id}_{YYYYMMDD}` (+ `_run2`…) | Seed memakai tanggal **target** (lihat asumsi A1). Aplikasi mengambil batch terbaru via `started_at` sehingga tidak bergantung pada ID. |

### 1.8 `dataset_status`
| 23 | Hanya `last_import_at`, `range_*`, `row_count`, `source_file` | + `labeled_count`, `last_actual_date`, `target_dates`, `missing_dates`, `is_dummy_data`, `last_import_written_rows`, `last_batch_*` | Dibaca di `DatasetStatus`; "Baris dengan actual" dan "Actual terakhir" ditampilkan di Evaluasi. Seed menulis semuanya. |

### 1.9 `notifications`
| 24 | Status baca di `users/{uid}/notification_reads/{notifId}` | Array `read_by` (uid) di dokumen notifikasi, `arrayUnion` | `markRead` memakai `FieldValue.arrayUnion`; badge/filter "Belum dibaca" memakai `read_by`. Provider `readIdsProvider` dan sub-koleksi dihapus. Rules: penerima (role ∈ `audience_roles`) hanya boleh **menambahkan uid sendiri** ke `read_by` dan tidak mengubah field lain. |
| 25 | Audiens: deviasi & incomplete → semua role; batch → admin, manajer | deviation: admin, manager, supervisor · degraded: admin, manager, viewer · incomplete: admin, supervisor · batch: admin | Seed mengikuti kontrak. Dampak UI: Viewer tidak lagi menerima notifikasi deviasi; Manajer tidak menerima notifikasi batch. |
| 26 | Tidak ada `severity`, `updated_at`, `batch_status`, `batch_log_id`, `deviation_pct`, `rolling_mae_7d`, `drift_threshold` | Ada | Dibaca (`severity`) / ditulis seed. |
| 27 | Indeks hanya `audience_roles` + `created_at` | + `wh_id` ASC, `created_at` DESC | Indeks ditambahkan. |

### 1.10 `decision_logs` (milik App, field "saran" kontrak)
| 28 | `pred_id`, `decision`, `manpower_final`, `reason` | `prediction_id`, `decision_status`, `final`, `note`, + `target_date`, `recommended` | Repository, model, seed, rules, dan indeks (`prediction_id` + `decided_at`) diganti. |

### 1.11 Indeks (`firebase/firestore.indexes.json`)
| 29 | — | `predictions` (`wh_id`, `evaluated`, `target_date` DESC) untuk `evaluate` Python | Ditambahkan. |

Indeks akhir: semua 6 indeks kontrak + 2 indeks App untuk `decision_logs`.

## 2. Ekstensi App yang dipertahankan (bukan selisih, perlu dicatat ke kontrak)
| Field | Koleksi | Alasan |
|---|---|---|
| `decided_by_name` | `decision_logs` | Rules hanya mengizinkan membaca profil sendiri; nama ditampilkan di Log keputusan. Kontrak menyebut field `decision_logs` sebagai "saran". |
| `changed_by_name` | `operational_configs/{wh_id}/history` | Sama: nama pengubah di "Riwayat perubahan". |

**Usulan untuk repo riset:** tambahkan kedua field ini ke tabel kontrak sebagai field App opsional.

## 3. Asumsi
- **A1:** `batch_logs` memakai `{YYYYMMDD}` = tanggal target, karena kontrak menulis "`{wh_id}_{YYYYMMDD}` lalu `_run2`" dengan field `target_date`.
- **A2:** Pada fallback H-2, `input_features.actual_h1` di seed bernilai `null`. Kontrak hanya menyebut "pakai actual hari sebelumnya", sehingga isi persis snapshot dari Python belum pasti. UI menampilkan "Belum diterima" bila `null`, dan angka bila diisi.
- **A3:** `hari` 0 = Senin disimpulkan dari contoh kontrak (2026-10-01 → 3).

## 4. Verifikasi (dijalankan)
| Perintah | Hasil |
|---|---|
| `flutter analyze` | No issues found! |
| `flutter test` | **+241: All tests passed!** (sebelumnya 230) |
| `test/unit/contract_test.dart` (baru) | Untuk keempat skenario seed: setiap dokumen hanya memakai field kontrak dan memuat field wajib. Juga memeriksa map bersarang (`input_features`, `feature_importance`, `manpower.config_snapshot`, `decision_manpower`), enum, format tanggal/ID, audiens, dan `deviation_pct` 2 desimal. |
| Test baru/diperbarui lain | Converter kunci kontrak, `role: manager`, `read_by`, `duration_s`/`retries`/`skipped`, `decision_*` pada prediksi (alur Setujui/Sesuaikan), sub-koleksi history + `note`, `read_by` setelah "Tandai semua dibaca". |
| Golden | 4 golden diregenerasi setelah diperiksa visual: `beranda_manajer` dan `beranda_viewer` (jumlah badge lonceng mengikuti audiens baru), `prediksi_viewer_fallback` (catatan `notes`), `evaluasi_admin` (baris dataset baru). |
| `firebase/rules-tests` | Diperbarui (role `manager`, `decision_*`, `read_by`, history), 49 blok `test()` × peran. `node --check` OK. **Belum dijalankan terhadap emulator** (alasan sama seperti di HANDOFF). |
| Dokumentasi turunan | `database_design*.html`, `class.txt`, `sequence.txt`, dan dokumen uji diregenerasi; `python tools/check_docs.py` → 127/127. Semua `.puml` lolos `plantuml -checkonly`. |

## 5. Langkah manual
1. Jalankan rules test di emulator: `cd firebase/rules-tests && npm install && npm run test:emulator`.
2. Bila memakai project nyata, deploy rules & indeks baru: `firebase deploy --only firestore:rules,firestore:indexes --project <project-id>`.
3. Di Firebase Console, ubah `users/<uid>` lama: `display_name` → `name`, `role: "manajer"` → `"manager"`.
4. Uji silang end-to-end: jalankan rantai `wipas-research` (import → seed-config → predict) ke emulator `demo-wipas` yang sama, lalu buka aplikasi dan ikuti checklist di `docs/HANDOFF.md`. Ini membuktikan aplikasi membaca dokumen yang benar-benar ditulis Python, bukan hanya seed aplikasi.
5. Usulkan ke repo riset: tambahkan `decided_by_name` dan `changed_by_name` sebagai field App opsional di kontrak (bagian 2).
