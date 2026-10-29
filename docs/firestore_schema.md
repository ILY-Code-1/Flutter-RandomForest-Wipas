# Skema Firestore WIPAS — Kontrak `wipas-research` ↔ `wipas-app`

Versi kontrak: **1.0** (2026-10-28). Dokumen ini adalah satu-satunya acuan struktur data antara
repo Python (`wipas-research`, penulis utama) dan aplikasi Flutter (`wipas-app`, pembaca + penulis
terbatas). Nama field, tipe, dan pemilik field di bawah **dicocokkan otomatis** dengan dokumen yang
benar-benar ditulis kode oleh `scripts/check_schema_contract.py` (lihat bagian terakhir).

## Konvensi umum

| Hal | Aturan |
|---|---|
| Contoh `wh_id` | `WH-CKG-01` |
| Tanggal kalender | string `YYYY-MM-DD` (mis. `"2026-10-01"`), logika harian memakai zona **Asia/Jakarta** |
| Waktu kejadian | Firestore `Timestamp` (UTC); tampilkan di aplikasi dalam Asia/Jakarta |
| ID tanggal | `YYYYMMDD` tanpa pemisah (mis. `20261001`) |
| Angka paket | `int`; persen (`*_pct`, `rolling_mae_7d`, `baseline_mae`, `mae_validation`, `rmse`) dalam **persen** (`6.8` berarti 6,8%) |
| Penulisan Python | selalu `set(..., merge=True)` (batched write); ID deterministik → menjalankan ulang tidak menggandakan dokumen |
| Nilai kosong | `null` (mis. `actual_inbound` sebelum diinput) |
| Peran (`audience_roles`, `users.role`) | `admin` (Shift Lead), `manager`, `supervisor`, `viewer` |

**Pemilik field.** Kolom *Penulis* pada tiap tabel: `Python` = ditulis `wipas-research`;
`Python (evaluate)` = ditulis langkah evaluate; `App` = ditulis aplikasi. Python **tidak pernah**
menimpa field milik App (`actual_*`, `decision_*`, `read_by`, `operational_configs` setelah dibuat).
Satu-satunya pengecualian: `backfill` mengisi `actual_inbound`, `actual_input_by = "backfill:excel"`,
`actual_input_at` pada dokumen backfill **yang belum punya actual** (riwayat dari Excel).

**Security rules.** Python memakai Admin SDK (service account) sehingga **mem-bypass security rules**.
Rules ditulis di repo aplikasi dan harus membatasi aplikasi hanya ke field App di bawah.

## Ringkasan koleksi

| Koleksi | ID dokumen | Penulis | Isi utama |
|---|---|---|---|
| `warehouses` | `{wh_id}` | Python (`seed-config`) | identitas gudang |
| `daily_data` | `{wh_id}_{YYYYMMDD}` | Python (`import-data`, `evaluate`) | fitur Excel + actual |
| `predictions` | `pred_{wh_id}_{YYYYMMDD}` | Python + App (field actual/decision) | prediksi H+1, deviasi, manpower |
| `operational_configs` | `{wh_id}` | Python (`seed-config`, hanya bila belum ada), lalu App | kapasitas & rasio manpower |
| `operational_configs/{wh_id}/history` | auto ID | App | riwayat perubahan konfigurasi |
| `model_health` | `{wh_id}` | Python | status drift & metrik model aktif |
| `model_health_history` | `{wh_id}_{YYYYMMDD}` | Python | Rolling MAE harian |
| `batch_logs` | `{wh_id}_{YYYYMMDD}` lalu `_run2`, `_run3`, … | Python | log tiap eksekusi `predict` |
| `dataset_status` | `{wh_id}` | Python | status impor & batch terakhir |
| `notifications` | `{type}_{wh_id}_{YYYYMMDD}` | Python (+ App: `read_by`) | notifikasi dalam aplikasi |
| `decision_logs` | auto ID | App | keputusan manpower (milik aplikasi) |
| `users` | `{uid}` | App / Firebase Console | profil & peran |

---

## `warehouses/{wh_id}`

| Field | Tipe | Penulis | Wajib | Keterangan |
|---|---|---|---|---|
| `name` | string | Python | ya | Nama gudang (`project.wh_name` di config) |
| `code` | string | Python | ya | Sama dengan `wh_id` |
| `timezone` | string | Python | ya | `Asia/Jakarta` |
| `created_at` | timestamp | Python | ya | Waktu seed |

```json
{ "name": "Warehouse CKG-01", "code": "WH-CKG-01", "timezone": "Asia/Jakarta", "created_at": "<Timestamp>" }
```

## `daily_data/{wh_id}_{YYYYMMDD}`

Satu dokumen per hari. Baris tanggal target (masa depan) berisi fitur dengan `actual_inbound = null`.

| Field | Tipe | Penulis | Wajib | Keterangan |
|---|---|---|---|---|
| `wh_id` | string | Python | ya | |
| `date` | string | Python | ya | `YYYY-MM-DD` |
| `campaign` | int (0/1) | Python | ya | null bila kosong di Excel |
| `hari_libur` | int (0/1) | Python | ya | |
| `payday` | int (0/1) | Python | ya | |
| `pickup_request_h1` | int | Python | ya | Pickup request H-1 relatif terhadap `date` |
| `projection_inbound` | int | Python | ya | Projection Tim DI untuk `date` |
| `backlog_h1` | int | Python | ya | Backlog H-1 relatif terhadap `date` |
| `actual_inbound` | int \| null | Python | ya | Dari Excel, atau disalin `evaluate` dari input aplikasi |
| `actual_source` | string | Python | tidak | `"excel"` atau `"app"`; nilai `"app"` tidak pernah ditimpa Excel |
| `actual_synced_at` | timestamp | Python (evaluate) | tidak | Saat actual dari aplikasi disalin |
| `row_hash` | string | Python | ya* | SHA-1 isi baris Excel; impor ulang melewati baris yang sama (*tidak ada bila dokumen hanya dibuat oleh evaluate) |
| `source_file` | string | Python | ya* | Nama file Excel |
| `imported_at` | timestamp | Python | ya* | |

```json
{ "wh_id": "WH-CKG-01", "date": "2026-10-01", "campaign": 0, "hari_libur": 0, "payday": 1,
  "pickup_request_h1": 13629, "projection_inbound": 18812, "backlog_h1": 1864, "actual_inbound": null,
  "row_hash": "3f1c…", "source_file": "data_historis_DUMMY_sep2026.xlsx", "imported_at": "<Timestamp>" }
```

## `predictions/pred_{wh_id}_{YYYYMMDD}`

| Field | Tipe | Penulis | Wajib | Keterangan |
|---|---|---|---|---|
| `wh_id` | string | Python | ya | |
| `target_date` | string | Python | ya | Tanggal yang diprediksi (H+1) |
| `predicted` | int | Python | ya | Prediksi RF dibulatkan ke paket utuh |
| `projection` | int \| null | Python | ya | Projection Tim DI untuk `target_date` |
| `deviation_pct` | number \| null | Python | ya | `(predicted − projection) / projection × 100`, 2 desimal |
| `alert` | bool | Python | ya | `abs(deviation_pct) > 15` |
| `status` | string | Python | ya | `"Perlu Perhatian"` bila alert, selain itu `"Normal"` |
| `data_status` | string | Python | ya | `"complete"` atau `"incomplete_fallback_h2"` |
| `source` | string | Python | ya | `"H-1"` atau `"H-2"` (fallback) |
| `model_version` | string | Python | ya | mis. `"v1.0"` |
| `generated_at` | timestamp | Python | ya | |
| `input_features` | map<string, number> | Python | ya | Snapshot 10 fitur: `hari`, `bulan`, `campaign`, `hari_libur`, `payday`, `pickup_request_h1`, `projection_inbound`, `backlog_h1`, `actual_h2`, `actual_h1` |
| `feature_importance` | map<string, number> | Python | ya | Importance model (10 fitur, jumlah ≈ 1) |
| `manpower` | map | Python | ya | Rekomendasi tenaga kerja |
| `manpower.rider` | int | Python | ya | `ceil(P × ratio_rider / capacity_rider)` |
| `manpower.driver` | int | Python | ya | `ceil(P × ratio_driver / capacity_driver)` |
| `manpower.op_inbound` | int | Python | ya | `ceil(P / capacity_op_inbound)` |
| `manpower.op_outbound` | int | Python | ya | `ceil(P / capacity_op_outbound)` |
| `manpower.config_snapshot` | map | Python | ya | Konfigurasi yang dipakai |
| `manpower.config_snapshot.capacity_rider` | number | Python | ya | |
| `manpower.config_snapshot.capacity_driver` | number | Python | ya | |
| `manpower.config_snapshot.capacity_op_inbound` | number | Python | ya | |
| `manpower.config_snapshot.capacity_op_outbound` | number | Python | ya | |
| `manpower.config_snapshot.ratio_rider` | number | Python | ya | |
| `manpower.config_snapshot.ratio_driver` | number | Python | ya | |
| `manpower.config_snapshot.rounding` | string | Python | ya | `"ceil"` |
| `manpower.config_snapshot.source` | string | Python | ya | `"firestore"` (dari `operational_configs`) atau `"default"` (fallback config.yaml) |
| `is_backfill` | bool | Python | ya | `true` = estimasi historis walk-forward, bukan hasil batch nyata |
| `is_dummy_data` | bool | Python | ya | `true` selama memakai Excel dummy |
| `notes` | array<string> | Python | ya | Catatan (fallback, imputasi, backfill) |
| `evaluated` | bool | Python (evaluate) | ya | `false` saat dibuat; `true` setelah dievaluasi |
| `daily_error_pct` | number \| null | Python (evaluate) | tidak | `abs(predicted − actual) / actual × 100` |
| `evaluated_at` | timestamp | Python (evaluate) | tidak | |
| `actual_inbound` | int | App | tidak | Input actual oleh pengguna (backfill: dari Excel) |
| `actual_note` | string | App | tidak | |
| `actual_input_by` | string | App | tidak | uid penginput (backfill: `"backfill:excel"`) |
| `actual_input_at` | timestamp | App | tidak | |
| `decision_status` | string | App | tidak | mis. `"approved"`, `"adjusted"` |
| `decision_by` | string | App | tidak | uid |
| `decision_at` | timestamp | App | tidak | |
| `decision_note` | string | App | tidak | |
| `decision_manpower` | map | App | tidak | Manpower final yang disetujui (`rider`, `driver`, `op_inbound`, `op_outbound`) |

Aturan idempotensi `predict`: dokumen yang sudah ada **tidak dihitung ulang** tanpa `--force`, kecuali
dokumen lama berstatus `incomplete_fallback_h2` dan actual H-1 kini tersedia (otomatis di-upgrade).
Dokumen yang sudah `evaluated: true` tidak pernah dihitung ulang. Field App dan `evaluated` tidak pernah
ditulis oleh `predict` (kecuali `evaluated: false` saat dokumen pertama kali dibuat).

```json
{ "wh_id": "WH-CKG-01", "target_date": "2026-10-01", "predicted": 17219, "projection": 18812,
  "deviation_pct": -8.47, "alert": false, "status": "Normal", "data_status": "complete", "source": "H-1",
  "model_version": "v1.0", "generated_at": "<Timestamp>",
  "input_features": { "hari": 3, "bulan": 10, "campaign": 0, "hari_libur": 0, "payday": 1,
                      "pickup_request_h1": 13629, "projection_inbound": 18812, "backlog_h1": 1864,
                      "actual_h2": 17325, "actual_h1": 16111 },
  "feature_importance": { "projection_inbound": 0.8112, "hari": 0.078, "…": 0.0 },
  "manpower": { "rider": 35, "driver": 7, "op_inbound": 35, "op_outbound": 29,
                "config_snapshot": { "capacity_rider": 350, "capacity_driver": 800, "capacity_op_inbound": 500,
                                     "capacity_op_outbound": 600, "ratio_rider": 0.7, "ratio_driver": 0.3,
                                     "rounding": "ceil", "source": "firestore" } },
  "is_backfill": false, "is_dummy_data": true, "notes": [], "evaluated": false }
```
(Angka contoh di atas berasal dari model DATA DUMMY.)

## `operational_configs/{wh_id}`

Dibuat sekali oleh `seed-config` (tidak pernah ditimpa); setelah itu diubah aplikasi. Batch membaca
dokumen ini setiap run; bila tidak ada/tidak valid (rasio tidak berjumlah 1, kapasitas ≤ 0) batch memakai
default `config.yaml` dan menandai `config_snapshot.source = "default"`.

| Field | Tipe | Penulis | Wajib | Keterangan |
|---|---|---|---|---|
| `wh_id` | string | Python | ya | |
| `capacity_rider` | number | Python → App | ya | default 350 paket/rider |
| `capacity_driver` | number | Python → App | ya | default 800 |
| `capacity_op_inbound` | number | Python → App | ya | default 500 |
| `capacity_op_outbound` | number | Python → App | ya | default 600 |
| `ratio_rider` | number | Python → App | ya | default 0,70; `ratio_rider + ratio_driver = 1,00` |
| `ratio_driver` | number | Python → App | ya | default 0,30 |
| `rounding` | string | Python → App | ya | `"ceil"` |
| `updated_by` | string | Python → App | ya | `"wipas-research:seed-config"` atau uid |
| `updated_at` | timestamp | Python → App | ya | |

Subkoleksi `operational_configs/{wh_id}/history/{auto}` (App): salinan field di atas + `changed_by`,
`changed_at`, `note`. Python tidak membaca maupun menulis subkoleksi ini.

```json
{ "wh_id": "WH-CKG-01", "capacity_rider": 350, "capacity_driver": 800, "capacity_op_inbound": 500,
  "capacity_op_outbound": 600, "ratio_rider": 0.7, "ratio_driver": 0.3, "rounding": "ceil",
  "updated_by": "wipas-research:seed-config", "updated_at": "<Timestamp>" }
```

## `model_health/{wh_id}`

| Field | Tipe | Penulis | Wajib | Keterangan |
|---|---|---|---|---|
| `wh_id` | string | Python | ya | |
| `status` | string | Python | ya | `"healthy"` atau `"degraded"` |
| `rolling_mae_7d` | number | Python | ya | Rata-rata `daily_error_pct` 7 hari terakhir yang sudah dievaluasi (%) |
| `rolling_window_days` | int | Python | ya | 7 |
| `n_points` | int | Python | ya | Jumlah hari dalam jendela (status tetap healthy bila < 7) |
| `last_evaluated_date` | string | Python | ya | |
| `baseline_mae` | number | Python | ya | MAE validasi (%) model aktif |
| `drift_threshold` | number | Python | ya | `round(1.15 × baseline_mae, 4)` |
| `drift_factor` | number | Python | ya | 1,15 |
| `model_version` | string | Python | ya | |
| `mae_validation` | number | Python | ya | MAE validasi TimeSeriesSplit (%) |
| `mae_validation_paket` | number | Python | ya | MAE validasi (paket) |
| `rmse` | number | Python | ya | RMSE validasi dalam **% dari rata-rata actual** |
| `rmse_paket` | number | Python | ya | RMSE validasi (paket) |
| `r2` | number | Python | ya | R² validasi (pooled out-of-fold) |
| `feature_importance` | map<string, number> | Python | ya | |
| `trained_at` | string | Python | ya | ISO-8601 waktu pelatihan model aktif |
| `is_dummy_data` | bool | Python | ya | |
| `updated_at` | timestamp | Python | ya | |

```json
{ "wh_id": "WH-CKG-01", "status": "healthy", "rolling_mae_7d": 7.6422, "rolling_window_days": 7, "n_points": 7,
  "last_evaluated_date": "2026-09-30", "baseline_mae": 8.1103, "drift_threshold": 9.3269, "drift_factor": 1.15,
  "model_version": "v1.0", "mae_validation": 8.1103, "mae_validation_paket": 1218.36, "rmse": 11.1481,
  "rmse_paket": 1767.88, "r2": 0.736, "feature_importance": { "projection_inbound": 0.8112, "…": 0.0 },
  "trained_at": "2026-10-28T02:41:00+00:00", "is_dummy_data": true, "updated_at": "<Timestamp>" }
```

## `model_health_history/{wh_id}_{YYYYMMDD}`

`YYYYMMDD` = tanggal data (target_date terakhir yang dievaluasi), bukan tanggal eksekusi.

| Field | Tipe | Penulis | Wajib | Keterangan |
|---|---|---|---|---|
| `wh_id` | string | Python | ya | |
| `date` | string | Python | ya | |
| `rolling_mae_7d` | number | Python | ya | |
| `status` | string | Python | ya | |
| `baseline_mae` | number | Python | ya | |
| `drift_threshold` | number | Python | ya | |
| `n_points` | int | Python | ya | |
| `model_version` | string | Python | ya | |
| `updated_at` | timestamp | Python | ya | |

## `batch_logs/{wh_id}_{YYYYMMDD}` (run berikutnya: `_run2`, `_run3`, …)

| Field | Tipe | Penulis | Wajib | Keterangan |
|---|---|---|---|---|
| `wh_id` | string | Python | ya | |
| `target_date` | string | Python | ya | |
| `started_at` | timestamp | Python | ya | |
| `finished_at` | timestamp | Python | ya | |
| `duration_s` | number | Python | ya | |
| `status` | string | Python | ya | `"success"`, `"skipped"` (prediksi sudah ada), `"failed"` |
| `message` | string | Python | ya | |
| `retries` | int | Python | ya | Jumlah retry exponential backoff (maks 3 per operasi) |
| `source` | string \| null | Python | ya | `"H-1"`/`"H-2"` |
| `data_status` | string \| null | Python | ya | |
| `model_version` | string \| null | Python | ya | |
| `predicted` | int \| null | Python | ya | |
| `evaluated_dates` | array<string> | Python | ya | Actual yang dievaluasi di awal batch |
| `error` | string \| null | Python | ya | Pesan galat bila gagal |
| `dry_run` | bool | Python | ya | |

## `dataset_status/{wh_id}`

| Field | Tipe | Penulis | Wajib | Keterangan |
|---|---|---|---|---|
| `wh_id` | string | Python | ya | |
| `last_import_at` | timestamp | Python | ya | |
| `range_start` | string | Python | ya | Tanggal pertama di Excel |
| `range_end` | string | Python | ya | Tanggal terakhir di Excel |
| `row_count` | int | Python | ya | |
| `labeled_count` | int | Python | ya | Baris dengan actual |
| `last_actual_date` | string \| null | Python | ya | |
| `target_dates` | array<string> | Python | ya | Baris masa depan (actual kosong) |
| `missing_dates` | array<string> | Python | ya | Celah tanggal di Excel |
| `source_file` | string | Python | ya | |
| `is_dummy_data` | bool | Python | ya | |
| `last_import_written_rows` | int | Python | ya | Baris `daily_data` yang ditulis pada impor terakhir |
| `last_batch_at` | timestamp | Python | tidak | Ditulis `predict` |
| `last_batch_status` | string | Python | tidak | |
| `last_batch_target_date` | string | Python | tidak | |

## `notifications/{type}_{wh_id}_{YYYYMMDD}`

`YYYYMMDD` = tanggal target (untuk `degraded`: tanggal data terakhir yang dievaluasi). ID deterministik
mencegah notifikasi ganda: `deviation`, `incomplete`, dan `degraded` hanya dibuat bila belum ada;
`degraded` hanya dibuat saat status berubah `healthy → degraded`. `batch` memakai ID yang sama per
tanggal dan isinya diperbarui oleh run terakhir (`created_at` dan `read_by` tidak disentuh).

| Field | Tipe | Penulis | Wajib | Keterangan |
|---|---|---|---|---|
| `type` | string | Python | ya | `deviation`, `degraded`, `incomplete`, `batch` |
| `title` | string | Python | ya | |
| `body` | string | Python | ya | |
| `severity` | string | Python | ya | `info`, `warning`, `error` |
| `wh_id` | string | Python | ya | |
| `target_date` | string | Python | ya | |
| `created_at` | timestamp | Python | ya | |
| `audience_roles` | array<string> | Python | ya | deviation: admin, manager, supervisor · degraded: admin, manager, viewer · incomplete: admin, supervisor · batch: admin |
| `updated_at` | timestamp | Python | tidak | Hanya `batch` yang diperbarui |
| `batch_status` | string | Python | tidak | `batch`: `success`/`failed` |
| `batch_log_id` | string | Python | tidak | `batch` |
| `deviation_pct` | number | Python | tidak | `deviation` |
| `rolling_mae_7d` | number | Python | tidak | `degraded` |
| `drift_threshold` | number | Python | tidak | `degraded` |
| `read_by` | array<string> | App | tidak | uid yang sudah membaca (`arrayUnion`) |

```json
{ "type": "incomplete", "title": "Data Incomplete Warning",
  "body": "Actual 2026-09-30 belum diinput; prediksi 2026-10-01 memakai fallback H-2. Input actual lalu jalankan ulang batch.",
  "severity": "warning", "wh_id": "WH-CKG-01", "target_date": "2026-10-01", "created_at": "<Timestamp>",
  "audience_roles": ["admin", "supervisor"] }
```

## `decision_logs/{auto}` (milik App)

Ditulis aplikasi saat keputusan manpower diambil; tidak dibaca/ditulis Python. Saran field:
`wh_id`, `target_date`, `prediction_id`, `recommended` (map manpower), `final` (map manpower),
`decision_status`, `note`, `decided_by`, `decided_at`.

## `users/{uid}` (milik App / Firebase Console)

`role` (`admin` | `manager` | `supervisor` | `viewer`), `name`. Akun dibuat lewat Firebase Console
(tanpa layar registrasi). Python tidak membaca/menulis koleksi ini.

---

## Indeks komposit yang dibutuhkan

Buat di Firebase Console → Firestore → Indexes (atau `firestore.indexes.json` di repo aplikasi):

| Koleksi | Field (urutan) | Dipakai oleh |
|---|---|---|
| `predictions` | `wh_id` ASC, `target_date` DESC | App: daftar/tren prediksi terbaru |
| `predictions` | `wh_id` ASC, `evaluated` ASC, `target_date` DESC | Python: Rolling MAE 7 hari (`evaluate`) |
| `model_health_history` | `wh_id` ASC, `date` DESC | App: grafik Rolling MAE |
| `notifications` | `wh_id` ASC, `created_at` DESC | App: daftar notifikasi |
| `notifications` | `audience_roles` ARRAY_CONTAINS, `created_at` DESC | App: notifikasi per peran |
| `batch_logs` | `wh_id` ASC, `started_at` DESC | Python `status`, App: log batch |

Query kesetaraan saja (mis. `daily_data where wh_id ==`, `predictions where wh_id == and evaluated ==`)
tidak memerlukan indeks komposit.

## Verifikasi otomatis kontrak

```
python scripts/check_schema_contract.py            # store memori, rantai lengkap data SAMPLE
python scripts/check_schema_contract.py --emulator # terhadap Firestore emulator (demo-wipas)
```
Skrip menjalankan rantai import → seed → train → backfill → predict (termasuk fallback H-2, deviasi,
degraded), mengambil dokumen contoh tiap koleksi, lalu memastikan (1) setiap field yang ditulis kode
tercantum di tabel dokumen ini dan (2) setiap field wajib milik Python benar-benar ditulis.
