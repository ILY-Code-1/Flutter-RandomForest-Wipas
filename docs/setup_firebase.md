# Setup Firebase

Dua bagian: **A. Emulator lokal** (dipakai pengembangan & pengujian, tanpa akun Google) dan **B. Project nyata (Spark)** — dijalankan sendiri oleh pemilik proyek, tidak oleh Claude Code.

## A. Firebase Emulator (project `demo-wipas`)

Prasyarat: Node.js 18+ (terpasang: 22), Java 11+ (terpasang: 17/22), Flutter 3.41+.

1. Pasang Firebase CLI (sekali):
   ```bash
   npm install -g firebase-tools
   ```
   Saat pertama dijalankan, CLI mengunduh JAR emulator Firestore (~60 MB) ke `~/.cache/firebase/emulators`.
2. Jalankan emulator dari root repo:
   ```bash
   firebase emulators:start --only auth,firestore --project demo-wipas
   ```
   Auth `:9099`, Firestore `:8080`, UI `http://127.0.0.1:4000`. Awalan `demo-` menjamin emulator tidak pernah menyentuh cloud. Rules dan indeks dibaca dari `firebase.json`.
3. Isi data demo (terminal lain, root repo):
   ```bash
   dart run firebase/seed/seed.dart                      # skenario normal
   dart run firebase/seed/seed.dart --scenario=degraded  # Model Degraded
   dart run firebase/seed/seed.dart --scenario=fallback  # Fallback H-2 / Data Incomplete
   dart run firebase/seed/seed.dart --scenario=empty     # hanya akun + konfigurasi (state kosong)
   ```
   Seed menghapus data emulator lama (kecuali `--keep`) dan menolak host selain localhost. Tanggal acuan = hari ini (WIB); pin dengan `SEED_TODAY=2026-10-08`.
4. Jalankan aplikasi di emulator Android:
   ```bash
   flutter run
   ```
   Aplikasi menyambung ke `10.0.2.2` (host dari sudut pandang emulator Android). Untuk HP fisik di Wi-Fi yang sama: `flutter run --dart-define=EMULATOR_HOST=<IP-LAN-komputer>` dan pastikan port 8080/9099 tidak diblokir firewall. Tambahkan juga IP tersebut sebagai `<domain>` di `android/app/src/main/res/xml/network_security_config.xml` (Android memblokir HTTP polos selain ke host emulator).

### Akun demo (dibuat oleh seed)
| Role | Email | Password |
|---|---|---|
| Admin (Shift Lead) | `admin.shift@wipas.example` | `wipas-demo-123` |
| Manajer | `manajer@wipas.example` | `wipas-demo-123` |
| Supervisor | `supervisor@wipas.example` | `wipas-demo-123` |
| Viewer (Tim DI) | `viewer@wipas.example` | `wipas-demo-123` |

Panel "Demo prototipe" di Login mengisi akun ini otomatis (build emulator saja).

## B. Project Firebase nyata (paket Spark, gratis)

> Langkah ini memakai akun Google dan **tidak dijalankan oleh Claude Code**. Urutan bernomor yang siap diikuti juga ada di `docs/HANDOFF.md`.

1. Buka https://console.firebase.google.com → **Add project** (mis. `wipas-prod`). Google Analytics boleh dimatikan. Paket tetap **Spark**.
2. **Build → Authentication → Get started → Sign-in method → Email/Password → Enable.**
3. **Build → Firestore Database → Create database** → mode *production*, lokasi `asia-southeast2 (Jakarta)`.
4. Tambahkan aplikasi Android dengan package `id.wipas.wipas_app`.
5. Di root repo:
   ```bash
   npm install -g firebase-tools        # bila belum
   dart pub global activate flutterfire_cli
   firebase login
   flutterfire configure --project=<project-id> --platforms=android
   ```
   Ini menimpa `lib/firebase_options.dart` dan membuat `android/app/google-services.json` (sudah di-`.gitignore`).
6. Deploy rules & indeks:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes --project <project-id>
   ```
7. Buat akun di **Authentication → Users → Add user** (Admin = Shift Lead; akun demo Manajer/Supervisor/Viewer bila perlu). Catat UID tiap akun.
8. Di **Firestore → Start collection**:
   - `users/<UID>`: `name` (string), `role` (`admin`/`manager`/`supervisor`/`viewer`) — sesuai kontrak `docs/firestore_schema.md`; email diambil dari Firebase Auth, `job_title` (opsional).
   - `warehouses/WH-CKG-01`: `name` = `Hub Cakung`.
   - `operational_configs/WH-CKG-01`: `capacity_rider` 350, `capacity_driver` 800, `capacity_op_inbound` 500, `capacity_op_outbound` 600, `ratio_rider` 0.7, `ratio_driver` 0.3, `rounding` `ceil`, `updated_by` (UID admin), `updated_at` (timestamp).
9. Jalankan script batch `wipas-research` agar `predictions`, `model_health`, dll. terisi (lihat repo riset; skema di `docs/firestore_schema.md`).
10. Build aplikasi untuk project nyata:
    ```bash
    flutter build apk --release --dart-define=USE_EMULATOR=false
    ```
