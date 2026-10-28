# WIPAS — aplikasi Android (`wipas-app`)

**Warehouse Inbound Prediction & Allocation System.** Aplikasi pendukung keputusan untuk Hub Cakung (WH-CKG-01): menampilkan prediksi volume inbound H+1 hasil Random Forest (dihitung repo `wipas-research`), rekomendasi manpower (Rider, Driver, Op. Inbound, Op. Outbound), kesehatan model, dan mencatat actual inbound serta keputusan alokasi.

Aplikasi **membaca** hasil script dari Cloud Firestore dan hanya **menulis** actual inbound, keputusan manpower, konfigurasi kapasitas (+ riwayat), dan status baca notifikasi. Flutter 3 · Material 3 · Riverpod · go_router · Firebase (Auth, Firestore) · Android 7.0+ (API 24).

## Mulai cepat (Firebase Emulator, tanpa akun Google)
```bash
flutter pub get
npm install -g firebase-tools                                  # sekali
firebase emulators:start --only auth,firestore --project demo-wipas
# terminal lain:
dart run firebase/seed/seed.dart                               # akun demo + data 30 hari
flutter run                                                     # emulator Android
```
Skenario seed lain: `--scenario=degraded | fallback | empty`. Rincian: [docs/setup_firebase.md](docs/setup_firebase.md).

## Akun demo (emulator)
Password semua akun: `wipas-demo-123`

| Role | Email | Nama |
|---|---|---|
| Admin (Shift Lead) | admin.shift@wipas.example | Admin WIPAS · Shift Lead |
| Manajer | manajer@wipas.example | Budi Santoso |
| Supervisor | supervisor@wipas.example | Rina Putri |
| Viewer (Tim DI) | viewer@wipas.example | Dewi Lestari |

## Pengujian
```bash
flutter analyze
flutter test                       # unit + widget + golden (360×800)
cd firebase/rules-tests && npm install && npm run test:emulator   # security rules
flutter test integration_test      # butuh perangkat + emulator Firebase
```
Lihat [docs/testing.md](docs/testing.md).

## Build APK
```bash
flutter build apk --release                                    # tersambung ke emulator (10.0.2.2)
flutter build apk --release --dart-define=EMULATOR_HOST=192.168.1.10   # HP fisik → emulator di laptop
flutter build apk --release --dart-define=USE_EMULATOR=false   # setelah flutterfire configure (Firebase nyata)
```
Hasil: `build/app/outputs/flutter-apk/app-release.apk`. Build rilis saat ini ditandatangani dengan kunci debug (lihat `docs/HANDOFF.md` untuk kunci rilis).

> `lib/firebase_options.dart` adalah **placeholder** (`demo-wipas`, kunci palsu). Penyambungan ke Firebase nyata: [docs/HANDOFF.md](docs/HANDOFF.md) bagian *Langkah manual untuk saya*.

## Dokumentasi
| Berkas | Isi |
|---|---|
| [docs/HANDOFF.md](docs/HANDOFF.md) | Ringkasan, cara menjalankan, masalah terbuka, langkah manual, checklist uji per peran |
| [docs/architecture.md](docs/architecture.md) | Struktur folder, aliran data, offline, batas baca |
| [docs/rbac_matrix.md](docs/rbac_matrix.md) | Akses per peran |
| [docs/firestore_schema.md](docs/firestore_schema.md) | Kontrak data dengan `wipas-research` |
| [docs/setup_firebase.md](docs/setup_firebase.md) | Emulator & project Spark |
| [docs/testing.md](docs/testing.md) | Jenis test dan cara menjalankannya |
| [docs/design_deviations.md](docs/design_deviations.md) · [docs/design_parity.md](docs/design_parity.md) | Selisih & kesesuaian dengan desain |
| [ASSUMPTIONS.md](ASSUMPTIONS.md) | Asumsi dan keputusan ambigu |

## Struktur
```
lib/core/      tema & token, komponen Wipas*, format id-ID, domain (rumus, RBAC), data (Firestore)
lib/features/  auth beranda prediksi manpower evaluasi input_actual konfigurasi riwayat notifikasi profil lainnya
firebase/      firestore.rules, indeks, seed emulator, rules-tests
test/          unit, widget, golden
```

## Lisensi pihak ketiga
Font Inter © The Inter Project Authors, SIL Open Font License 1.1 (`assets/fonts/OFL.txt`).
