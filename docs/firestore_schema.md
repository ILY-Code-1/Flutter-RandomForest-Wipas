# Skema Firestore WIPAS (kontrak data `wipas-research` ↔ `wipas-app`)

> **Status:** dibuat di repo aplikasi dari tabel KONTRAK DATA pada prompt pengembangan, karena berkas ini belum ada saat pengerjaan. Bagian bertanda **[USULAN]** adalah field tambahan yang dipakai aplikasi/seed tetapi tidak tercantum di prompt; **sinkronkan ke repo riset** sebelum script Python menulis koleksi tersebut.

## Konvensi umum

| Hal | Aturan |
|---|---|
| `wh_id` | Default `WH-CKG-01` (Hub Cakung). |
| Tanggal kalender (`target_date`, `date`, `range_*`) | String `YYYY-MM-DD` dalam zona WIB (Asia/Jakarta). String dipakai agar urutan leksikografis = urutan tanggal dan tidak bergeser karena zona waktu. |
| Waktu kejadian (`*_at`) | Firestore `Timestamp` (UTC). Aplikasi menampilkannya dalam WIB. |
| Persen | Angka dalam satuan persen (mis. `15.8` berarti 15,8%), bukan pecahan. Kecuali `feature_importance` (pecahan 0–1). |
| Penulis | **S** = script Python (Admin SDK, melewati rules). **A** = aplikasi (dibatasi security rules). |

## Koleksi

### `predictions/pred_{wh}_{YYYYMMDD}` — S (A hanya `actual_*`)

| Field | Tipe | Penulis | Keterangan |
|---|---|---|---|
| `wh_id` | string | S | |
| `target_date` | string `YYYY-MM-DD` | S | Tanggal yang diprediksi (H+1 dari waktu batch). |
| `predicted` | int | S | Hasil Random Forest (paket). |
| `projection` | int | S | Projection Tim DI. |
| `deviation_pct` | double | S | `(predicted − projection) / projection × 100`. |
| `alert` | bool | S | `abs(deviation_pct) > 15`. |
| `status` | string | S | `normal` \| `perlu_perhatian`. |
| `data_status` | string | S | `complete` \| `incomplete_fallback_h2`. |
| `source` | string | S | `H-1` \| `H-2`. |
| `model_version` | string | S | mis. `v1.0`. |
| `generated_at` | timestamp | S | |
| `input_features` | map | S | 10 fitur, lihat di bawah. Nilai boleh `null` bila belum diterima. |
| `feature_importance` | map<string,double> | S | Kunci = nama fitur, nilai 0–1. |
| `manpower` | map | S | `rider`, `driver`, `op_inbound`, `op_outbound` (int, ceil) + `config_snapshot` (map nilai `operational_configs` saat dihitung). |
| `is_backfill` | bool | S | |
| `actual_inbound` | int ≥ 0 | **A** | Diisi Admin/Supervisor. |
| `actual_note` | string \| null | **A** | ≤ 500 karakter. |
| `actual_input_by` | string (uid) | **A** | Harus = uid penulis. |
| `actual_input_at` | timestamp | **A** | `serverTimestamp()`. |
| `daily_error_pct` | double | S | `abs(predicted − actual) / actual × 100`. |
| `evaluated` | bool | S | |

`input_features`: `day_of_week` (1=Senin … 7=Minggu), `month`, `is_campaign`, `is_holiday`, `is_payday` (bool), `pickup_request_h1`, `projection_inbound`, `backlog_h1`, `actual_inbound_h2`, `actual_inbound_h1` (int).

### `daily_data/{wh}_{YYYYMMDD}` — S
Baris Excel yang diimpor: `wh_id`, `date`, 10 fitur di atas (flat), `actual_inbound`, **[USULAN]** `source_file`. Aplikasi tidak membacanya secara rutin (hanya hak baca di rules).

### `operational_configs/{wh}` — A (Admin, Manajer)
`capacity_rider`, `capacity_driver`, `capacity_op_inbound`, `capacity_op_outbound` (number > 0), `ratio_rider`, `ratio_driver` (number > 0, jumlah 1,00 ± 0,001), `rounding` (`ceil`), `updated_by` (uid), `updated_at` (timestamp). Default 350 / 800 / 500 / 600, 0,70 / 0,30.

### `config_history/{auto}` — A, append-only
`wh_id`, `changed_by` (uid = penulis), `changed_by_name`, `changed_at`, `old_values` (map), `new_values` (map). Ditulis dalam satu transaksi bersama `operational_configs`.

### `decision_logs/{auto}` — A, append-only
`pred_id`, `wh_id`, `decided_by` (uid = penulis), `decided_by_name`, `decision` (`approved` \| `adjusted`), `manpower_final` (map 4 kategori), `reason` (wajib & tidak kosong bila `adjusted`), `decided_at`. Viewer tidak boleh membaca.

### `model_health/{wh}` — S
`status` (`healthy` \| `degraded`), `rolling_mae_7d`, `baseline_mae`, `drift_threshold` (= 1,15 × baseline), `model_version`, `mae_validation`, `rmse`, `r2`, `feature_importance`, `updated_at`.

### `model_health_history/{wh}_{YYYYMMDD}` — S **[USULAN: daftar field]**
Prompt hanya menyebut ID dokumen. Aplikasi membaca: `wh_id`, `date` (`YYYY-MM-DD`), `rolling_mae_7d`, `baseline_mae`, `drift_threshold`, `status`. Dipakai grafik Rolling MAE 30 hari di Evaluasi.

### `batch_logs/{wh}_{YYYYMMDD}` — S **[USULAN: daftar field]**
`wh_id`, `run_date`, `target_date`, `started_at`, `finished_at` (timestamp), `duration_sec` (int), `status` (`success` \| `failed`), `retry_count` (int), `source` (`H-1` \| `H-2`), `message` (string \| null). ID memakai tanggal **eksekusi**.

### `dataset_status/{wh}` — S **[USULAN: daftar field]**
`wh_id`, `last_import_at`, `range_start`, `range_end` (`YYYY-MM-DD`), `row_count` (int), `source_file`.

### `notifications/{type}_{wh}_{YYYYMMDD}` — S
`type` (`deviation` \| `degraded` \| `incomplete` \| `batch`), `title`, `body`, `wh_id`, `target_date`, `created_at`, `audience_roles` (array role). Tanggal di ID = `target_date`. Query aplikasi **wajib** memfilter `audience_roles array-contains <role>` (rules menolak query tanpa filter ini).

Audiens yang dipakai seed (usulan default untuk script): deviasi & incomplete → semua role; degraded → admin, manajer, viewer; batch → admin, manajer.

### `users/{uid}` — dibuat manual (Console / seed)
`display_name`, `email`, `role` (`admin` \| `manajer` \| `supervisor` \| `viewer`), `wh_id`, **[USULAN]** `job_title` (label chip, mis. "Manajer Warehouse"; boleh `null`). Klien hanya membaca dokumennya sendiri, tidak bisa menulis.

### `users/{uid}/notification_reads/{notifId}` — A (pemilik)
`read_at` (timestamp). Keberadaan dokumen = sudah dibaca.

### `warehouses/{wh}` — dibuat manual **[USULAN: daftar field]**
`name` (mis. "Hub Cakung"), `city`. Bila tidak ada, aplikasi menampilkan `wh_id`.

## Query aplikasi dan indeks
Lihat `firebase/firestore.indexes.json`. Semua query list dibatasi rentang tanggal dan/atau `limit` (≤ 31 dokumen prediksi, 30 riwayat model, 30 notifikasi, 60 keputusan) agar hemat kuota baca Spark (50.000/hari).
