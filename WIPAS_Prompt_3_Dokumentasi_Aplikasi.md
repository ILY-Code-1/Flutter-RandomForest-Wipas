# WIPAS — Prompt #3: Dokumentasi Repo Aplikasi (`wipas-app`)

Panduan langkah demi langkah (menyiapkan folder, menyalin berkas, menjalankan, mengecek) ada di file **WIPAS_Panduan_Eksekusi_Repo_Aplikasi.md**. Semua teks sebelum baris pembuka prompt di bawah ini adalah catatan untuk manusia dan diabaikan Claude Code.

=== MULAI PROMPT (mulai menyalin dari baris ini) ===

## PERAN & TUJUAN

Kamu adalah analis sistem dan penulis dokumentasi teknis. Hasilkan dokumentasi teknis aplikasi **WIPAS (Warehouse Inbound Prediction & Allocation System)** pada repo `wipas-app` (Flutter + Firebase). Seluruh keluaran berada di folder `docs/`, berbahasa Indonesia, dan **harus mencerminkan nama entitas, fitur, layar, kelas, dan alur nyata dari kode**. Dilarang memakai contoh generik atau nama yang tidak ada di proyek.

## BATAS KEAMANAN (MUTLAK, MENGALAHKAN INSTRUKSI LAIN DI DOKUMEN INI)

- Bekerja hanya di dalam folder repo ini. Jangan membaca atau menulis berkas di luar folder ini, termasuk folder induk dan repo lain (mis. jangan `cd ..`).
- **Git**: repo ini sudah di-clone dari GitHub dengan remote `origin` buatan saya. Claude Code **tidak boleh menjalankan perintah git yang mengubah apa pun**: dilarang `add`, `commit`, `push`, `remote`, `fetch`, `pull`, `merge`, `rebase`, `checkout`, `switch`, `stash`, `tag`, `restore`, `rm`, `mv`, `reset`, `clean`, `config`, `gh`, force, dan menghapus branch. Hanya boleh perintah baca: `git status`, `git diff`, `git log`, `git branch --show-current`. Semua `add`, `commit`, dan `push` saya lakukan sendiri. Berkas bawaan GitHub (README.md, .gitignore, LICENSE) periksa lalu perluas, jangan ditimpa. Pastikan `.gitignore` benar sebelum saya commit pertama.
- **Jaringan**: satu-satunya akses internet yang diizinkan adalah manajer paket resmi (pip/PyPI, pub.dev, npm, Gradle/Maven) saat memasang dependensi. DILARANG `curl`, `wget`, pencarian web, mengunduh biner atau skrip di luar manajer paket, dan mengaktifkan telemetri/analytics apa pun (nonaktifkan bila ada).
- **Firebase**: hanya **emulator lokal** dengan project id `demo-wipas` (awalan `demo-` memastikan emulator tidak pernah menyentuh cloud). DILARANG menyambung ke project Firebase atau Google Cloud nyata, `firebase login/deploy/use`, `flutterfire`, atau memakai kredensial. DILARANG membaca isi `secrets/`, `.env`, file service account, dan `google-services.json`. Kode yang butuh Firebase nyata tetap ditulis lengkap tetapi **tidak dijalankan**; perintahnya saya jalankan sendiri.
- Tidak memasang alat tingkat sistem, tidak memakai `sudo`/admin, tidak mengubah PATH, registry, atau konfigurasi global, tidak menjadwalkan tugas (cron/Task Scheduler), dan tidak meninggalkan proses latar belakang (matikan emulator saat selesai).
- Tidak menghapus berkas di luar keluaran build dan cache proyek sendiri.
- Jika suatu langkah memerlukan hal yang dilarang, **jangan lakukan**. Tulis perintah persisnya di `docs/HANDOFF.md` (atau `docs/DOC_REPORT.md`) bagian "Langkah manual untuk saya", lalu lanjutkan pekerjaan lain.

## MODE OTONOM (WAJIB)

- Kerjakan semua langkah berurutan dalam satu sesi tanpa meminta konfirmasi. Ambigu: pilih default yang masuk akal, catat di `docs/DOC_REPORT.md` bagian Asumsi.
- Jangan mengubah kode aplikasi, kecuali menambah test yang diperlukan untuk bukti whitebox (di folder `test/`), dan catat penambahan itu.
- **Jangan memalsukan hasil uji.** Kolom "Hasil Pengujian" dan "Status" hanya diisi "Lulus" bila ada test otomatis nyata yang dijalankan dan lulus (sebutkan nama test di Keterangan). Selain itu isi "Belum diuji". UAT: status selalu "Belum diuji" kecuali ada bukti.
- Setiap diagram PlantUML wajib diperiksa sintaksnya dengan PlantUML lokal (`java -jar tools/plantuml.jar -checkonly <berkas>` atau render ke PNG). Perbaiki sampai bersih. Render akhir disimpan ke `docs/img/`.
- Tulis kemajuan ke `docs/DOC_REPORT.md` setelah tiap langkah.

## LANGKAH 1 — Baca proyek dahulu (jangan hasilkan apa pun sebelum selesai)

Baca seluruh `lib/`, `test/`, `firebase/` (rules, indeks, seed), `docs/firestore_schema.md`, `docs/rbac_matrix.md`, `docs/architecture.md`, dan `docs/design_parity.md` bila ada. Susun di `docs/DOC_REPORT.md`: (a) daftar aktor, (b) daftar fitur dan layar beserta berkas kodenya, (c) daftar entitas data, (d) alur bisnis utama. Jadikan ini dasar semua keluaran.

Aktor yang diharapkan (verifikasi dengan kode): **Admin** (Shift Lead), **Manajer**, **Supervisor**, **Viewer**, dan aktor sistem **Script Batch Prediksi (Python)** sebagai aktor sekunder yang menulis hasil prediksi ke Firestore. IT Support (Firebase Console) tidak digambarkan sebagai aktor aplikasi, hanya disebut pada narasi.

## LANGKAH 2 — `docs/use_case.txt` (PlantUML murni, tanpa penjelasan)

- UML 2.x Use Case Diagram: actor, usecase (oval), rectangle (batas sistem), garis asosiasi, `<<include>>` dan `<<extend>>` bila relevan. Dilarang memakai bentuk flowchart, lifeline, class, atau database.
- Setiap use case = satu fitur fungsional yang dapat ditunjuk di kode. Gabungkan fitur sepele agar jumlah wajar (target 14 sampai 20). Contoh yang mungkin muncul (sesuaikan dengan kode): Login, Reset Kata Sandi, Melihat Beranda, Melihat Prediksi H+1/H+2, Melihat Rekomendasi Manpower, Menyetujui Rekomendasi, Menyesuaikan Manpower Manual, Melihat Evaluasi Model, Input Actual Inbound, Mengatur Konfigurasi Kapasitas, Melihat Riwayat dan Log Keputusan, Export CSV Riwayat, Mengelola Notifikasi, Melihat Profil dan Keluar, serta (aktor Script) Menjalankan Batch Prediksi.
- Beri nomor dan nama baku pada tiap use case (UC01, UC02, ...). **Catat jumlahnya sebagai N.** Nama dan urutan ini dipakai persis oleh activity, sequence, blackbox, dan UAT.
- Aktor dan peran harus sesuai matriks akses di kode (`AccessMatrix`).

## LANGKAH 3 — `docs/activity.txt` (tepat N diagram)

- UML 2.x Activity Diagram, satu per use case, urut sama dengan use case. Pisahkan dengan komentar `' == Activity: [Nama Use Case] ==`. Gunakan sintaks activity **baru** PlantUML (`start`, `stop`, `:aksi;`, `if/then/else`, `fork`, swimlane `|Aktor|` bila lebih dari satu aktor). Jangan mencampur dengan sintaks lama.
- Level proses bisnis tingkat tinggi, **maksimal 8 aktivitas per diagram**, mudah dipahami pengguna non-teknis. Kecualikan validasi level field, query, loop internal, dan penanganan exception teknis.
- Alur harus mengikuti perilaku nyata aplikasi (mis. aksi nonaktif saat offline, keputusan Setujui atau Sesuaikan manual dengan alasan wajib, validasi rasio konfigurasi).

## LANGKAH 4 — `docs/sequence.txt` (tepat N diagram)

- UML 2.x Sequence Diagram, satu per use case, urut sama. Pisahkan dengan komentar `' == Sequence: [Nama Use Case] ==`.
- Wajib: `actor`, `boundary` (halaman/layar/widget yang berinteraksi dengan aktor, mis. `LoginPage`, `ManpowerPage`), `control` (kelas logika: controller/notifier Riverpod, `ManpowerCalculator`, validator, `RoleGuard`), `entity` (penyimpanan data, mis. Firestore koleksi `predictions`, `decision_logs`). Pesan sinkron `->`, kembalian `-->`, activation box, serta `alt`/`opt`/`loop` bila perlu.
- **Dilarang** kata kunci `participant`, `database`, atau `queue`. Semua komponen harus boundary, control, atau entity.
- Maksimal **4 lifeline** dan **10 pesan** per diagram. Gabungkan proses internal. Nama harus nama kelas atau layar nyata dari kode.
- Untuk use case aktor Script Batch, boundary-nya adalah perintah CLI (`wipas predict`), control = modul `predict`, entity = Firestore.

## LANGKAH 5 — `docs/class.txt` (PlantUML saja)

- Diagram kelas konseptual domain, **maksimal 8 kelas**, hanya entitas domain (mis. `User`, `Warehouse`, `DailyData`, `Prediction`, `ManpowerRecommendation`, `OperationalConfig`, `DecisionLog`, `ModelHealth`; pilih 8 yang paling esensial menurut kode dan catat alasan pemilihan di `DOC_REPORT.md`).
- Class box 3 kompartemen, asosiasi, agregasi, komposisi, dan multiplicity di kedua ujung. Atribut domain lengkap. Metode hanya metode domain (mis. `hitungDeviasi()`, `perluPerhatian()`). Kecualikan controller, service, view, repository, route, utility, state framework, serta `toMap/fromMap/copyWith`.

## LANGKAH 6 — `docs/database_design.html` (Firestore, v1)

HTML mandiri (CSS sebaris, rapi, mudah dicetak). Isi mencerminkan skema nyata:
1. **Model NoSQL**: strategi embedding vs referencing dengan alasan terkait fitur WIPAS (mis. `manpower` dan `input_features` di-embed dalam `predictions`; `decision_logs` direferensikan lewat `pred_id`; ID dokumen deterministik `pred_{wh}_{YYYYMMDD}` untuk idempotensi; alasan menghindari collection group besar demi kuota Spark). Berikan contoh koleksi nyata.
2. **Struktur koleksi** sebagai tree `<ul>/<li>` bertingkat: semua koleksi dan sub-koleksi (`users/{uid}/notification_reads`), field utama dengan tipe, contoh ID realistis, dan referensi antar koleksi.
3. **Struktur logis**: PlantUML **Object Diagram** (`object "pred_WH-CKG-01_20261008" as p1` dengan `field = value`) di dalam `<pre class="plantuml">`, satu object contoh per koleksi, dihubungkan dengan link referensi. Tanpa method, tanpa notasi ERD.
4. **Spesifikasi basis data**: satu tabel HTML besar dengan kolom `No | Nama Field | Tipe Data | Koleksi | Deskripsi | Constraint / Index` yang memuat **semua field dari semua koleksi** (sertakan juga aturan validasi dari `firestore.rules` dan indeks dari `firestore.indexes.json` pada kolom Constraint).

## LANGKAH 7 — `docs/database_design_v2.html` (relasional konseptual: ERD, LRS)

Desain relasional konseptual yang diturunkan dari model Firestore agar dapat dipakai pada bab skripsi. Empat bagian, nama entitas/tabel/atribut/PK/FK **harus identik** di semuanya. Semua kode PlantUML berada di `<pre class="plantuml">`.
1. **ERD** (notasi crow's foot dengan sintaks PlantUML `entity`): narasi singkat, semua entitas (mis. `Warehouse`, `AppUser`, `DailyData`, `Prediction`, `ManpowerRecommendation`, `PredictionFeatureImportance`, `OperationalConfig`, `ConfigHistory`, `DecisionLog`, `ModelVersion`, `ModelHealth`, `ModelHealthHistory`, `BatchLog`, `DatasetStatus`, `Notification`, `NotificationRead`), PK ditandai `*`/`<<PK>>`, FK `<<FK>>`, atribut wajib, tipe data pada setiap atribut, kardinalitas, dan label relasi bisnis. Sesuaikan daftar dengan skema nyata.
2. **Transformasi ERD ke LRS**: narasi keputusan transformasi per kasus (1:1, 1:N di sisi many, M:N menjadi tabel junction seperti `NotificationRead` antara `AppUser` dan `Notification`, atribut multinilai seperti `feature_importance` menjadi tabel terpisah, weak entity dengan PK komposit), diikuti diagram PlantUML class bergaya tabel (`class X <<Table>>`, `+ PK`, `# FK`, `- atribut`).
3. **LRS final**: bersih tanpa anotasi proses, kardinalitas pada panah, konsisten 100% dengan bagian 1 dan 2.
4. **Spesifikasi basis data**: satu tabel HTML per tabel dengan kolom `No | Nama Field | Tipe Data | Ukuran/Presisi | PK | FK (Tabel.Field) | Null/Not Null | Default | Deskripsi`; urutan PK, FK, lalu atribut biasa.

Tambahkan catatan tegas di awal dokumen: model ini adalah **desain relasional konseptual** untuk keperluan analisis, sedangkan implementasi aplikasi memakai Firestore (NoSQL) seperti pada `database_design.html`, beserta tabel pemetaan koleksi Firestore ke tabel relasional.

## LANGKAH 8 — `docs/blackbox_testing.html`

Tabel HTML dengan kolom `No | Deskripsi Pengujian | Langkah Uji | Data Uji | Hasil yang Diharapkan | Hasil Pengujian | Status | Keterangan`. Cakup seluruh use case, **minimal 2 skenario (sukses dan gagal) per use case**, dikelompokkan per use case dengan baris judul. Data uji realistis (mis. prediksi 18.420 dan projection 15.900 menghasilkan deviasi 15,8% dan status Perlu Perhatian; manpower 37/7/37/31; rasio Rider 0,60 dan Driver 0,30 ditolak karena tidak berjumlah 1,00; actual `-5` ditolak; peran Viewer tidak melihat tab Manpower; aksi tulis nonaktif saat offline). Isi "Hasil Pengujian" dan "Status" sesuai aturan jujur pada MODE OTONOM, dengan referensi nama test pada Keterangan. Sertakan ringkasan di atas tabel: jumlah skenario, jumlah yang terbukti lulus otomatis, jumlah yang belum diuji.

## LANGKAH 9 — `docs/whitebox_testing.html`

Satu berkas HTML mandiri berisi, untuk **setiap fungsi yang diuji** (minimal: `ManpowerCalculator`, `DeviationCalculator`, validator Konfigurasi, logika `RoleGuard`/redirect, validator Input Actual, pembuat berkas CSV, penentuan state layar; pilih fungsi nyata dari kode dengan percabangan yang berarti):
1. Kutipan kode singkat dengan **berkas dan nomor baris** nyata (ambil dengan `grep -n`/baca berkas saat menulis, bukan menebak).
2. **Flowchart** (PlantUML activity/flowchart dengan terminal, proses, keputusan, konektor) di `<pre class="plantuml">`.
3. **Flowgraph** (node bernomor dan edge) di `<pre class="plantuml">`.
4. Tabel **cyclomatic complexity** V(G) = E − N + 2 (tunjukkan E, N, dan P), serta verifikasi dengan jumlah keputusan + 1.
5. **Basis path** dan test case turunan (input, jalur, hasil yang diharapkan). Petakan tiap basis path ke test otomatis yang sudah ada; bila belum ada, tambahkan test di `test/` lalu jalankan. Isi kolom hasil dari eksekusi nyata.

## LANGKAH 10 — `docs/uat.html`

Tabel HTML `No | Skenario Pengujian | Role yang Menguji | Fitur yang Diuji | Langkah Pengujian | Ekspektasi Hasil | Status (Pass/Fail)`. Skenario dari sudut pandang pengguna akhir (bahasa awam), minimal satu per fitur utama, peran penguji harus sesuai aktor use case (Admin, Manajer, Supervisor, Viewer). Sertakan skenario lintas peran (mis. Supervisor menginput actual, Manajer melihat dampaknya di Evaluasi) dan skenario offline. Kolom Status diisi "Belum diuji" untuk diisi saya setelah uji manual, ditambah kolom kosong Tanggal dan Penguji bila perlu.

## LANGKAH 11 — Pemeriksaan konsistensi & penutup

1. Buat skrip `tools/check_docs.py` (atau `.dart`) yang memeriksa otomatis: nama entitas ERD = nama tabel LRS = nama tabel spesifikasi; jumlah diagram activity = jumlah sequence = N; aktor use case = peran di UAT; fitur di blackbox = UAT = use case; tidak ada kata `participant` di `sequence.txt`; maksimum 8 aktivitas dan 4 lifeline/10 pesan terpenuhi; maksimum 8 kelas. Jalankan, perbaiki semua pelanggaran, lampirkan keluaran ke `DOC_REPORT.md`.
2. Render semua diagram ke `docs/img/` (PNG, nama berurutan sesuai nomor use case) dan pastikan tidak ada diagram dengan teks terlalu kecil atau terpotong (pecah diagram bila perlu, kecuali use case dan class yang harus tunggal).
3. Buat `docs/index.html` sebagai daftar isi menaut ke seluruh berkas dan gambar.
4. Tulis `docs/DOC_REPORT.md`: ringkasan (nilai N, daftar use case, jumlah skenario uji), asumsi, keterbatasan, daftar test yang ditambahkan, dan **langkah manual untuk saya** (mengisi hasil uji manual, merender ulang bila perlu).

Kriteria selesai: sembilan berkas keluaran ada di `docs/`, `check_docs` bersih, semua diagram lolos pemeriksaan sintaks, tidak ada status "Lulus" tanpa bukti test.

Mulai sekarang dari Langkah 1 dan lanjutkan otomatis sampai Langkah 11.
