"""Generates docs/blackbox_testing.html, docs/whitebox_testing.html, docs/uat.html
and docs/test_results.txt.

"Hasil Pengujian"/"Status" are filled ONLY from a real `flutter test --reporter json`
run: a scenario is "Lulus" when every referenced automated test is present and
succeeded; otherwise it is "Belum diuji" (or "Gagal" when a referenced test failed).

Usage (repo root):
  flutter test --reporter json > build/test_results.json
  python tools/gen_test_docs.py build/test_results.json
"""
import datetime
import html
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from docs_uc import USE_CASES  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
IMG = DOCS / "img"
esc = html.escape

CSS = (ROOT / "tools" / "gen_db_docs.py").read_text(encoding="utf-8").split('CSS = """', 1)[1].split('"""', 1)[0] + """
td.ok{color:#1B5E20;font-weight:600}td.no{color:#7A4F00;font-weight:600}td.fail{color:#8E1B1B;font-weight:700}
tr.group td{background:#E6EDF6!important;font-weight:700;color:#1F3A5F}
"""


def page(title, subtitle, body):
    return f"""<!doctype html>
<html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title><style>{CSS}</style></head>
<body><h1>{esc(title)}</h1><p class="sub">{subtitle}</p>
{body}
<p class="sub">Dibuat oleh <code>tools/gen_test_docs.py</code>. Hasil otomatis diambil dari <code>flutter test --reporter json</code>
(ringkasan: <a href="test_results.txt">test_results.txt</a>).</p></body></html>
"""


# ----------------------------------------------------------------- results
def load_results(path):
    names, results = {}, {}
    for line in pathlib.Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        e = json.loads(line)
        if e.get("type") == "testStart":
            names[e["test"]["id"]] = e["test"]["name"]
        elif e.get("type") == "testDone" and not e.get("hidden"):
            results[names[e["testID"]]] = e["result"]
    return results


RESULTS = {}


def verdict(refs):
    """Returns (hasil, status, keterangan) for a list of test-name substrings."""
    if not refs:
        return "—", "Belum diuji", ""
    found = []
    for r in refs:
        hits = [(n, res) for n, res in RESULTS.items() if r in n]
        if not hits:
            return "—", "Belum diuji", f"test belum ada: {r}"
        found += hits
    if all(res == "success" for _, res in found):
        return "Sesuai harapan (test otomatis)", "Lulus", "; ".join(sorted({n for n, _ in found}))
    bad = [n for n, res in found if res != "success"]
    return "Tidak sesuai", "Gagal", "; ".join(bad)


def status_cell(s):
    cls = {"Lulus": "ok", "Belum diuji": "no", "Gagal": "fail"}.get(s, "")
    return f'<td class="{cls}">{esc(s)}</td>'


# ---------------------------------------------------------------- blackbox
# (uc, deskripsi, langkah, data uji, harapan, [test refs], catatan)
BLACKBOX = [
    ("UC01", "Login berhasil dengan akun valid", "Buka Login, isi email & password, tekan Masuk", "supervisor@wipas.example / wipas-demo-123",
     "Masuk ke Beranda dengan chip \"Supervisor Operasional\"", ["Auth valid credentials via the form open Beranda for the role"], ""),
    ("UC01", "Login gagal karena kredensial salah", "Isi email & password salah, tekan Masuk", "rina.putri@perusahaan.id / salah",
     "Pesan \"Email atau password salah\", tetap di Login", ["Auth wrong credentials show the design error"], ""),
    ("UC01", "Login ditolak karena akun tanpa role valid", "Masuk dengan akun yang role-nya tidak dikenal", "users/{uid}.role = superuser",
     "Pesan \"Akun belum memiliki role. Hubungi administrator.\"", ["Auth account without a valid role is rejected with a message"], ""),
    ("UC01", "Sesi berakhir setelah 24 jam", "Buka aplikasi dengan sesi berumur 25 jam", "session_started_ms = sekarang − 25 jam",
     "Kembali ke Login dengan banner \"Sesi berakhir\"", ["Auth session older than 24 hours ends with the Sesi berakhir banner"], ""),
    ("UC02", "Reset kata sandi berhasil", "Lupa password → isi email → Kirim tautan reset", "rina.putri@perusahaan.id",
     "\"Tautan reset telah dikirim ke email\"", ["Auth forgot password shows confirmation"], ""),
    ("UC02", "Reset ditolak karena format email salah", "Isi teks bukan email → Kirim", "bukan-email",
     "Pesan \"Masukkan email yang valid…\"", ["Auth forgot password shows confirmation"], "test yang sama memeriksa kedua jalur"),
    ("UC03", "Beranda menampilkan data dan peringatan deviasi", "Login Admin, buka Beranda", "Predicted 18.420, Projection 15.900",
     "KPI 18.420 dan banner \"Deviasi 15,8% melewati ambang 15%\"", ["admin lands on Beranda with seeded data"], ""),
    ("UC03", "Beranda kosong saat belum ada batch", "Buka Beranda dengan data seed kosong", "skenario empty",
     "\"Belum ada data batch\"", ["/beranda empty shows explanation"], ""),
    ("UC03", "Beranda galat dan saran IT Support", "Simulasikan galat server lalu tekan Coba lagi 3 kali", "stream error",
     "\"Gagal memuat data\" + saran hubungi IT Support", ["/beranda error shows retry and IT Support after 3 failures"], ""),
    ("UC03", "Viewer tidak melihat kartu Manpower", "Login Viewer, buka Beranda", "akun viewer",
     "Tanpa kartu Rekomendasi Manpower, tab Manpower tidak ada", ["Beranda per role viewer: read-only, no manpower card or links",
                                                                 "Bottom navigation viewer has no Manpower tab"], ""),
    ("UC03", "Beranda offline menampilkan data tersimpan", "Matikan koneksi, buka Beranda", "connectivity offline",
     "Banner \"Mode offline · menampilkan data tersimpan\" + data cache", ["/beranda offline shows banner and cached data"], ""),
    ("UC04", "Prediksi H+1 tampil hanya baca", "Buka Prediksi sebagai Admin", "pred_WH-CKG-01_20261009",
     "Chip Hanya baca, target 18.420, Faktor pendorong tampil", ["Prediksi (admin): read-only"], ""),
    ("UC04", "Supervisor tidak melihat Faktor pendorong", "Buka Prediksi sebagai Supervisor", "akun supervisor",
     "Kartu Faktor pendorong tersembunyi", ["Prediksi (supervisor): read-only"], ""),
    ("UC04", "H+2 tanpa data menampilkan state kosong", "Pilih H+2", "batch hanya H+1",
     "\"Belum ada prediksi untuk tanggal terpilih\" + Kembali ke H+1", ["Prediksi H+2 without data shows empty state"], ""),
    ("UC04", "Fallback H-2 ditandai", "Buka dengan data H-1 terlambat", "data_status = incomplete_fallback_h2",
     "Banner \"Fallback H-2 · Data Incomplete Warning\"", ["Fallback H-2 shows the Data Incomplete warning"], ""),
    ("UC05", "Rekomendasi 37/7/37/31 dan Cara hitung", "Buka Manpower, tekan Cara hitung Rider", "Predicted 18.420, rasio 0,70, kapasitas 350",
     "(18.420 × 0,70) ÷ 350 = 36,84 → 37 orang", ["Manpower decisions Cara hitung sheet shows the substituted formula",
                                                 "ManpowerCalculator 18.420 → 37 / 7 / 37 / 31"], ""),
    ("UC05", "Supervisor hanya baca", "Buka Manpower sebagai Supervisor", "akun supervisor",
     "Tombol Setujui/Sesuaikan tidak tampil, chip Hanya baca", ["Manpower: supervisor read-only without actions"], ""),
    ("UC05", "Viewer tidak bisa membuka Manpower", "Buka /manpower sebagai Viewer", "akun viewer",
     "Diarahkan ke Beranda", ["Route guard viewer cannot open /manpower"], ""),
    ("UC06", "Manajer menyetujui rekomendasi", "Setujui rekomendasi → dialog → Setujui", "pred_WH-CKG-01_20261009",
     "decision_logs berisi approved, status Disetujui", ["Manpower decisions manajer approves"], ""),
    ("UC06", "Batal pada dialog", "Setujui rekomendasi → Batal", "-",
     "Tidak ada log baru, status tetap menunggu", ["Manpower decisions cancel keeps the recommendation pending"], ""),
    ("UC06", "Aksi nonaktif saat offline", "Buka Manpower tanpa koneksi", "connectivity offline",
     "Tombol nonaktif dengan \"Tidak tersedia saat offline\"", ["Manpower decisions offline disables actions"], ""),
    ("UC07", "Penyesuaian dengan alasan tersimpan", "Sesuaikan manual → Rider +3 → isi alasan → Simpan", "Rider 40, alasan \"Antrean backlog 640 paket…\"",
     "Log adjusted, status \"Disesuaikan manual\", Rider 40 (rekomendasi 37)", ["Manpower decisions manual adjustment requires a reason"], ""),
    ("UC07", "Penyesuaian tanpa alasan ditolak", "Simpan penyesuaian dengan alasan kosong", "alasan = \"\"",
     "\"Alasan wajib diisi.\"", ["Manpower decisions manual adjustment requires a reason"], "test yang sama memeriksa kedua jalur"),
    ("UC08", "Evaluasi menampilkan kesehatan model", "Buka Evaluasi sebagai Admin", "model_health seed",
     "Kartu Kesehatan model, Rolling MAE, metrik, batch, dataset", ["/evaluasi data renders"], ""),
    ("UC08", "Viewer melihat Evaluasi hanya baca", "Buka Evaluasi sebagai Viewer", "akun viewer",
     "Chip Hanya baca", ["Evaluasi viewer is read-only"], ""),
    ("UC08", "Supervisor tidak bisa membuka Evaluasi", "Buka /evaluasi sebagai Supervisor", "akun supervisor",
     "Diarahkan ke Beranda; tab tidak ada", ["Route guard supervisor cannot open /evaluasi", "Bottom navigation supervisor has no Evaluasi tab"], ""),
    ("UC08", "Status Model Degraded", "Buka dengan Rolling MAE di atas ambang", "skenario degraded",
     "Badge/banner Model Degraded + saran retraining", ["golden evaluasi_manajer_degraded", "Model Degraded shows a danger banner on Beranda"],
     "bukti visual = golden test"),
    ("UC09", "Simpan actual valid", "Isi 17.560 → Simpan", "actual 17.560, predicted 17.200",
     "Selisih +360 paket (+2,1%), dokumen prediksi berisi actual_inbound 17560", ["Input Actual supervisor reminder, validation and save"], ""),
    ("UC09", "Actual negatif ditolak", "Isi -5", "-5",
     "\"Nilai tidak boleh negatif.\"", ["WB-AV-P2"], ""),
    ("UC09", "Actual kosong ditolak", "Tekan Simpan tanpa angka", "\"\"",
     "\"Actual inbound wajib diisi.\"", ["Input Actual supervisor reminder, validation and save"], ""),
    ("UC09", "Simpan nonaktif saat offline", "Buka Input Actual tanpa koneksi", "connectivity offline",
     "\"Tidak tersedia saat offline\"", ["Input Actual offline disables Simpan"], ""),
    ("UC09", "Manajer tidak bisa membuka Input Actual", "Buka /input-actual sebagai Manajer", "akun manajer",
     "Diarahkan ke Beranda", ["Route guard manajer cannot open /input-actual"], ""),
    ("UC10", "Simpan konfigurasi valid", "Capacity_Rider 400, Capacity_Op_Outbound 650 → Simpan → konfirmasi", "400/800/500/650, 0,70/0,30",
     "Pratinjau Rider 33 (−4), Op. Outbound 29 (−2); config + riwayat tersimpan", ["Konfigurasi ratio error disables save; valid change saves config + history"], ""),
    ("UC10", "Rasio 0,60 + 0,30 ditolak", "Isi Ratio_Rider 0,60", "0,60 + 0,30 = 0,90",
     "Galat rasio, Simpan nonaktif", ["WB-CV-P7", "Konfigurasi ratio error disables save"], ""),
    ("UC10", "Kapasitas 0 ditolak", "Isi Capacity_Driver 0", "0",
     "\"Nilai harus lebih dari 0.\"", ["Konfigurasi capacity 0 shows a field error"], ""),
    ("UC10", "Supervisor tidak bisa membuka Konfigurasi", "Buka /konfigurasi sebagai Supervisor", "akun supervisor",
     "Diarahkan ke Beranda", ["Route guard supervisor cannot open /konfigurasi"], ""),
    ("UC11", "Riwayat 7 dan 14 hari", "Buka Riwayat → pilih 14 hari", "3 Okt – 9 Okt 2026 → 26 Sep – 9 Okt 2026",
     "Rentang berubah, badge Perlu Perhatian pada deviasi > 15%", ["Riwayat 14 hari filter extends the list"], ""),
    ("UC11", "Viewer tanpa kolom keputusan", "Buka Riwayat sebagai Viewer", "akun viewer",
     "Tidak ada status Disetujui/Menunggu, judul \"Prediksi & actual\"", ["Riwayat viewer: no export and no decision column"], ""),
    ("UC12", "Export CSV berhasil", "Admin tekan Export CSV", "7 baris",
     "\"File siap diunduh\", berkas riwayat_wipas_2026-10-03_2026-10-09.csv diawali BOM", ["Export CSV (admin) success state with BOM file"], ""),
    ("UC12", "Export CSV gagal", "Export saat penyimpanan gagal", "FileSystemException",
     "\"Export gagal\" + Coba lagi", ["Export CSV (admin) failure state offers retry"], ""),
    ("UC12", "Non-Admin tidak melihat Export", "Buka Riwayat sebagai Manajer", "akun manajer",
     "Tombol Export CSV tidak tampil", ["Riwayat manajer: decisions without export"], ""),
    ("UC13", "Filter dan tandai semua dibaca", "Buka Notifikasi → chip Batch → Semua → Tandai semua dibaca", "2 belum dibaca dari 4",
     "\"0 belum dibaca · 4 total\"", ["Notifikasi filter and mark all read"], ""),
    ("UC13", "Notifikasi kosong", "Buka Notifikasi tanpa data", "skenario empty",
     "\"Belum ada notifikasi\"", ["Notifikasi empty state"], ""),
    ("UC13", "Supervisor hanya menerima notifikasi relevan", "Buka Notifikasi sebagai Supervisor", "audience_roles",
     "Notifikasi batch tidak tampil", ["Notifikasi for supervisor excludes batch notifications"], ""),
    ("UC14", "Keluar melalui dialog", "Profil → Keluar → Keluar", "-",
     "Kembali ke Login", ["Auth logout via Profil dialog returns to Login"], ""),
    ("UC14", "Menu Lainnya per role", "Buka Lainnya sebagai tiap role", "4 akun",
     "Konfigurasi hanya untuk Admin/Manajer", ["Lainnya menu for admin", "Lainnya menu for viewer"], ""),
    ("UC15", "Batch harian menulis prediksi H+1", "Jalankan `wipas predict` di repo riset", "Excel dengan baris tanggal target",
     "predictions/pred_WH-CKG-01_{H+1} beserta manpower, notifikasi, batch_logs", [], "script ada di repo wipas-research (di luar repo ini)"),
    ("UC15", "Batch dengan data H-1 terlambat", "Jalankan batch saat actual H-1 kosong", "actual H-1 kosong",
     "data_status = incomplete_fallback_h2 + notifikasi incomplete", [], "di luar repo ini; kontrak diverifikasi lewat seed (seed_data_test)"),
]


def blackbox():
    rows, n, ok = [], 0, 0
    for code, name, _ in USE_CASES:
        rows.append(f'<tr class="group"><td colspan="8">{code} — {esc(name)}</td></tr>')
        for uc, desc, steps, data, exp, refs, note in [b for b in BLACKBOX if b[0] == code]:
            n += 1
            hasil, status, ket = verdict(refs)
            ok += status == "Lulus"
            ket = "; ".join(x for x in [ket, note] if x)
            rows.append(f"<tr><td>{n}</td><td>{esc(desc)}</td><td>{esc(steps)}</td><td>{esc(data)}</td><td>{esc(exp)}</td>"
                        f"<td>{esc(hasil)}</td>{status_cell(status)}<td>{esc(ket)}</td></tr>")
    body = (f'<div class="note">Total skenario: <b>{n}</b> · terbukti lulus oleh test otomatis: <b>{ok}</b> · belum diuji: <b>{n - ok}</b>. '
            f'Status "Lulus" hanya diberikan bila test yang disebut pada kolom Keterangan benar-benar dijalankan dan sukses.</div>'
            "<table><tr><th>No</th><th>Deskripsi Pengujian</th><th>Langkah Uji</th><th>Data Uji</th><th>Hasil yang Diharapkan</th>"
            "<th>Hasil Pengujian</th><th>Status</th><th>Keterangan</th></tr>" + "".join(rows) + "</table>")
    return page("Blackbox Testing — WIPAS", "Pengujian fungsional per use case (UC01–UC15).", body), n, ok


# ---------------------------------------------------------------- whitebox
# Each function: code location, flowchart (PlantUML activity), flowgraph (nodes, edges),
# decisions, basis paths [(id, path, input, expected)].
WB = [
    dict(key="mp", title="ManpowerCalculator.compute", file="lib/core/domain/calculators.dart",
         sig="static ManpowerCounts compute(", length=9, decisions=0,
         flow="""start
:p = predicted.toDouble();
:rider = _ceil(p × ratioRider / capacityRider)
driver = _ceil(p × ratioDriver / capacityDriver)
opInbound = _ceil(p / capacityOpInbound)
opOutbound = _ceil(p / capacityOpOutbound);
:return ManpowerCounts;
stop""",
         nodes=3, edges=[(1, 2), (2, 3)],
         labels={1: "p = toDouble", 2: "4 × _ceil (tanpa cabang)", 3: "return"},
         paths=[("WB-MP-P1", "1-2-3", "predicted 18.420, kapasitas default", "37 / 7 / 37 / 31")]),
    dict(key="dp", title="DeviationCalculator.percent", file="lib/core/domain/calculators.dart",
         sig="static double? percent(", length=4, decisions=3,
         flow="""start
if (predicted == null?) then (ya)
  :return null;
  stop
elseif (projection == null?) then (ya)
  :return null;
  stop
elseif (projection <= 0?) then (ya)
  :return null;
  stop
else (tidak)
  :return (predicted − projection) / projection × 100;
  stop
endif""",
         nodes=6, edges=[(1, 4), (1, 2), (2, 4), (2, 3), (3, 4), (3, 5), (4, 6), (5, 6)],
         labels={1: "predicted == null?", 2: "projection == null?", 3: "projection <= 0?", 4: "return null", 5: "return deviasi", 6: "exit"},
         paths=[("WB-DP-P1", "1-4-6", "predicted null, projection 15.900", "null"),
                ("WB-DP-P2", "1-2-4-6", "predicted 18.420, projection null", "null"),
                ("WB-DP-P3", "1-2-3-4-6", "projection 0", "null"),
                ("WB-DP-P4", "1-2-3-5-6", "18.420 vs 15.900", "15,85")]),
    dict(key="dn", title="DeviationCalculator.needsAttention", file="lib/core/domain/calculators.dart",
         sig="static bool needsAttention(", length=6, decisions=2,
         flow="""start
if (deviationPct == null?) then (ya)
  :return false;
  stop
else (tidak)
  :v = |deviationPct| dibulatkan 4 desimal;
  if (v > 15?) then (ya)
    :return true;
  else (tidak)
    :return false;
  endif
  stop
endif""",
         nodes=7, edges=[(1, 2), (1, 3), (3, 4), (4, 5), (4, 6), (2, 7), (5, 7), (6, 7)],
         labels={1: "null?", 2: "return false", 3: "v = round(|d|)", 4: "v > 15?", 5: "return true", 6: "return false", 7: "exit"},
         paths=[("WB-DN-P1", "1-2-7", "null", "false"), ("WB-DN-P2", "1-3-4-6-7", "15,0", "false"),
                ("WB-DN-P3", "1-3-4-5-7", "15,8", "true")]),
    dict(key="cv", title="ConfigValidator.validate", file="lib/core/domain/calculators.dart",
         sig="static ConfigValidation validate(", length=19, decisions=6,
         flow="""start
:errors = {};
while (masih ada entri values?) is (ya)
  if (v == null?) then (ya)
    :errors[key] = "Wajib diisi dengan angka.";
  elseif (v <= 0?) then (ya)
    :errors[key] = "Nilai harus lebih dari 0.";
  else (tidak)
  endif
endwhile (tidak)
if (ratio_rider != null?) then (ya)
  if (ratio_driver != null?) then (ya)
    if (|rr + rd − 1| > 0,001?) then (ya)
      :ratioError = msgRatio(sum);
    endif
  endif
endif
:return ConfigValidation(errors, ratioError);
stop""",
         nodes=12, edges=[(1, 2), (2, 3), (2, 8), (3, 4), (3, 5), (4, 7), (5, 6), (5, 7), (6, 7), (7, 2), (8, 9), (8, 12),
                          (9, 10), (9, 12), (10, 11), (10, 12), (11, 12)],
         labels={1: "errors = {}", 2: "ada entri?", 3: "v == null?", 4: "err kosong", 5: "v <= 0?", 6: "err > 0", 7: "lanjut",
                 8: "rr != null?", 9: "rd != null?", 10: "|sum−1| > tol?", 11: "ratioError", 12: "return"},
         paths=[("WB-CV-P1", "1-2-8-12", "{}", "valid"),
                ("WB-CV-P2", "1-2-3-4-7-2-8-12", "capacity_rider = null", "\"Wajib diisi dengan angka.\""),
                ("WB-CV-P3", "1-2-3-5-6-7-2-8-12", "capacity_rider = 0", "\"Nilai harus lebih dari 0.\""),
                ("WB-CV-P4", "1-2-3-5-7-2-8-12", "capacity_rider = 350", "valid"),
                ("WB-CV-P5", "1-2-3-5-7-2-8-9-12", "ratio_rider = 0,7 saja", "tanpa galat rasio"),
                ("WB-CV-P6", "1-2-…-8-9-10-12", "350/800/500/600, 0,70/0,30", "valid"),
                ("WB-CV-P7", "1-2-…-8-9-10-11-12", "ratio 0,60 + 0,30", "\"…harus = 1,00 (saat ini 0,90).\"")]),
    dict(key="av", title="ActualValidator.validate", file="lib/core/domain/calculators.dart",
         sig="static String? validate(String text)", length=8, decisions=6,
         flow="""start
:t = text.trim();
if (t kosong?) then (ya)
  :return "Actual inbound wajib diisi.";
  stop
elseif (diawali "-" atau "−"?) then (ya)
  :return "Nilai tidak boleh negatif.";
  stop
elseif (bukan pola [0-9.]+?) then (ya)
  :return "Masukkan angka bulat…";
  stop
else (tidak)
  :cleaned = hapus titik;
  if (cleaned kosong atau tryParse null?) then (ya)
    :return "Masukkan angka bulat…";
  else (tidak)
    :return null (valid);
  endif
  stop
endif""",
         nodes=13, edges=[(1, 2), (2, 3), (2, 4), (4, 6), (4, 5), (5, 6), (5, 7), (7, 8), (7, 9), (9, 11), (9, 10), (10, 11),
                          (10, 12), (3, 13), (6, 13), (8, 13), (11, 13), (12, 13)],
         labels={1: "trim", 2: "kosong?", 3: "ret wajib", 4: "'-'?", 5: "'−'?", 6: "ret negatif", 7: "pola?", 8: "ret bulat",
                 9: "cleaned kosong?", 10: "tryParse null?", 11: "ret bulat", 12: "ret null", 13: "exit"},
         paths=[("WB-AV-P1", "1-2-3-13", "\" \"", "wajib diisi"), ("WB-AV-P2", "1-2-4-6-13", "-5", "negatif"),
                ("WB-AV-P3", "1-2-4-5-6-13", "−5", "negatif"), ("WB-AV-P4", "1-2-4-5-7-8-13", "17,5", "angka bulat"),
                ("WB-AV-P5", "1-2-4-5-7-9-11-13", ".", "angka bulat"),
                ("WB-AV-P6", "1-2-4-5-7-9-10-11-13", "99999999999999999999999", "angka bulat"),
                ("WB-AV-P7", "1-2-4-5-7-9-10-12-13", "17.560", "null (valid)")]),
    dict(key="rg", title="roleGuard (RoleGuard go_router)", file="lib/router.dart",
         sig="String? roleGuard(", length=16, decisions=10,
         flow="""start
if (path == /dev/gallery?) then (ya)
  if (kDebugMode?) then (ya)
    :return null;
  else (tidak)
    :return /splash;
  endif
  stop
elseif (path == /splash?) then (ya)
  :return null;
  stop
else (tidak)
  switch (auth.status)
  case (unknown)
    :return /splash;
  case (signedOut)
    if (rute publik?) then (ya)
      :return null;
    elseif (sessionExpired?) then (ya)
      :return /login?expired=1;
    else (tidak)
      :return /login;
    endif
  case (signedIn)
    if (path == /login atau /login/lupa?) then (ya)
      :return /beranda;
    elseif (AccessMatrix.canOpen?) then (ya)
      :return null;
    else (tidak)
      :return /beranda;
    endif
  endswitch
  stop
endif""",
         nodes=16, edges=[(1, 2), (2, 3), (2, 6), (3, 4), (3, 5), (6, 4), (6, 7), (7, 5), (7, 8), (7, 12), (8, 4), (8, 9),
                          (9, 10), (9, 11), (12, 15), (12, 13), (13, 15), (13, 14), (14, 4), (14, 15), (4, 16), (5, 16),
                          (10, 16), (11, 16), (15, 16)],
         labels={1: "path", 2: "gallery?", 3: "kDebugMode?", 4: "return null", 5: "return /splash", 6: "splash?",
                 7: "status?", 8: "publik?", 9: "expired?", 10: "/login?expired=1", 11: "/login", 12: "== /login?",
                 13: "== /login/lupa?", 14: "canOpen?", 15: "return /beranda", 16: "exit"},
         paths=[("WB-RG-P1", "1-2-3-4-16", "/dev/gallery (debug)", "null"),
                ("WB-RG-P2", "1-2-3-5-16", "/dev/gallery (rilis)", "/splash"),
                ("WB-RG-P3", "1-2-6-4-16", "/splash", "null"),
                ("WB-RG-P4", "1-2-6-7-5-16", "unknown, /beranda", "/splash"),
                ("WB-RG-P5", "1-2-6-7-8-4-16", "signedOut, /login", "null"),
                ("WB-RG-P6", "1-2-6-7-8-9-10-16", "signedOut + expired, /beranda", "/login?expired=1"),
                ("WB-RG-P7", "1-2-6-7-8-9-11-16", "signedOut, /manpower", "/login"),
                ("WB-RG-P8", "1-2-6-7-12-15-16", "admin, /login", "/beranda"),
                ("WB-RG-P9", "1-2-6-7-12-13-15-16", "viewer, /login/lupa", "/beranda"),
                ("WB-RG-P10", "1-2-6-7-12-13-14-4-16", "manajer, /konfigurasi", "null"),
                ("WB-RG-P11", "1-2-6-7-12-13-14-15-16", "viewer, /manpower", "/beranda")],
         note="WB-RG-P2 tidak dapat dieksekusi di test karena kDebugMode adalah konstanta kompilasi (selalu true saat flutter test); "
              "jalur ini hanya dapat diverifikasi manual pada APK rilis."),
    dict(key="cs", title="CsvExport._cell", file="lib/features/riwayat/csv_export.dart",
         sig="static String _cell(", length=6, decisions=2,
         flow="""start
if (v == null?) then (ya)
  :return "";
else (tidak)
  :s = v.toString();
  if (s memuat " , CR atau LF?) then (ya)
    :return "\\"" + s (kutip digandakan) + "\\"";
  else (tidak)
    :return s;
  endif
endif
stop""",
         nodes=6, edges=[(1, 2), (1, 3), (3, 4), (3, 5), (2, 6), (4, 6), (5, 6)],
         labels={1: "null?", 2: "return ''", 3: "perlu kutip?", 4: "return kutip", 5: "return s", 6: "exit"},
         paths=[("WB-CS-P1", "1-2-6", "actual null", "sel kosong"), ("WB-CS-P2", "1-3-5-6", "17560", "17560"),
                ("WB-CS-P3", "1-3-4-6", "rute \"padat\", hujan", "\"rute \"\"padat\"\", hujan\"")]),
    dict(key="vs", title="toViewState (penentuan state layar)", file="lib/core/state/view_state.dart",
         sig="ViewState<T> toViewState<T>(", length=20, decisions=5,
         flow="""start
if (value.hasValue?) then (ya)
  if (isEmpty != null dan isEmpty(data)?) then (ya)
    :return ViewEmpty;
  elseif (offline?) then (ya)
    :return ViewOffline(data, lastSync);
  else (tidak)
    :return ViewData(data);
  endif
elseif (value.hasError?) then (ya)
  :return ViewError;
else (tidak)
  :return ViewLoading;
endif
stop""",
         nodes=11, edges=[(1, 2), (1, 8), (2, 3), (2, 5), (3, 4), (3, 5), (5, 6), (5, 7), (8, 9), (8, 10), (4, 11), (6, 11),
                          (7, 11), (9, 11), (10, 11)],
         labels={1: "hasValue?", 2: "isEmpty != null?", 3: "isEmpty(data)?", 4: "Empty", 5: "offline?", 6: "Offline",
                 7: "Data", 8: "hasError?", 9: "Error", 10: "Loading", 11: "exit"},
         paths=[("WB-VS-P1", "1-8-10-11", "AsyncLoading", "ViewLoading"), ("WB-VS-P2", "1-8-9-11", "AsyncError", "ViewError"),
                ("WB-VS-P3", "1-2-5-7-11", "AsyncData([]), tanpa isEmpty, online", "ViewData"),
                ("WB-VS-P4", "1-2-3-4-11", "AsyncData([]), isEmpty", "ViewEmpty"),
                ("WB-VS-P5", "1-2-3-5-6-11", "AsyncData([1]), offline", "ViewOffline"),
                ("WB-VS-P6", "1-2-3-5-7-11", "AsyncData([1]), online", "ViewData")]),
]


def code_excerpt(f):
    lines = (ROOT / f["file"]).read_text(encoding="utf-8").splitlines()
    start = next(i for i, l in enumerate(lines) if f["sig"] in l)
    seg = lines[start:start + f["length"]]
    return start + 1, "\n".join(f"{start + 1 + i:4d}  {l}" for i, l in enumerate(seg))


def write_puml(name, code):
    (IMG / f"{name}.puml").write_text(code, encoding="utf-8")
    return f'<pre class="plantuml">{esc(code)}</pre>\n<p><img class="diagram" src="img/{name}.png" alt="{name}"></p>'


def flowgraph_puml(name, f):
    o = [f"@startuml {name}", "skinparam defaultFontName Arial", "skinparam shadowing false", "top to bottom direction"]
    for i in range(1, f["nodes"] + 1):
        o.append(f'circle "{i}" as n{i}')
    for a, b in f["edges"]:
        o.append(f"n{a} --> n{b}")
    o.append("legend right")
    o += [f"  {i}: {f['labels'][i]}" for i in range(1, f["nodes"] + 1)]
    o.append("endlegend")
    o.append("@enduml")
    return "\n".join(o)


def whitebox():
    parts, total, ok = [], 0, 0
    parts.append("<div class='note'>Fungsi dipilih dari kode nyata dengan percabangan berarti. Kutipan kode diambil langsung dari berkas "
                 "saat dokumen dibuat (nomor baris nyata). Setiap basis path dipetakan ke test otomatis di "
                 "<code>test/unit/whitebox_test.dart</code> (nama test diawali ID path); kolom Hasil diisi dari eksekusi nyata.</div>")
    parts.append("<h2>Ringkasan</h2><table><tr><th>No</th><th>Fungsi</th><th>Berkas</th><th>N</th><th>E</th><th>P</th><th>V(G)=E−N+2P</th>"
                 "<th>Keputusan+1</th><th>Basis path</th></tr>")
    summary_rows = []
    for idx, f in enumerate(WB, 1):
        N, E = f["nodes"], len(f["edges"])
        v = E - N + 2
        assert v == f["decisions"] + 1, f"{f['title']}: V(G) {v} != decisions+1 {f['decisions'] + 1}"
        assert len(f["paths"]) == v, f"{f['title']}: {len(f['paths'])} paths but V(G) = {v}"
        line, code = code_excerpt(f)
        summary_rows.append(f"<tr><td>{idx}</td><td><code>{esc(f['title'])}</code></td><td><code>{f['file']}:{line}</code></td>"
                            f"<td>{N}</td><td>{E}</td><td>1</td><td>{v}</td><td>{f['decisions'] + 1}</td><td>{len(f['paths'])}</td></tr>")
        sec = [f"<h2>{idx}. {esc(f['title'])}</h2><h3>Kutipan kode — <code>{f['file']}</code> baris {line}</h3>",
               f"<pre class='plantuml'>{esc(code)}</pre>",
               "<h3>Flowchart</h3>",
               write_puml(f"wb_{idx:02d}_{f['key']}_flowchart", f"@startuml wb_{idx:02d}_{f['key']}_flowchart\n{f['flow']}\n@enduml"),
               "<h3>Flowgraph</h3>",
               write_puml(f"wb_{idx:02d}_{f['key']}_flowgraph", flowgraph_puml(f"wb_{idx:02d}_{f['key']}_flowgraph", f)),
               "<h3>Cyclomatic complexity</h3>",
               f"<table><tr><th>E (edge)</th><th>N (node)</th><th>P (komponen)</th><th>V(G) = E − N + 2P</th><th>Jumlah keputusan + 1</th></tr>"
               f"<tr><td>{E}</td><td>{N}</td><td>1</td><td>{E} − {N} + 2 = <b>{v}</b></td><td>{f['decisions']} + 1 = <b>{f['decisions'] + 1}</b></td></tr></table>",
               f"<p>Edge: {', '.join(f'{a}→{b}' for a, b in f['edges'])}.</p>",
               "<h3>Basis path & test case</h3><table><tr><th>ID</th><th>Jalur</th><th>Input</th><th>Hasil yang diharapkan</th>"
               "<th>Test otomatis</th><th>Hasil</th><th>Status</th></tr>"]
        for pid, path, inp, exp in f["paths"]:
            total += 1
            hasil, status, ket = verdict([pid + " "])
            ok += status == "Lulus"
            sec.append(f"<tr><td>{pid}</td><td>{path}</td><td>{esc(inp)}</td><td>{esc(exp)}</td><td>{esc(ket) or '—'}</td>"
                       f"<td>{esc(hasil)}</td>{status_cell(status)}</tr>")
        sec.append("</table>")
        if f.get("note"):
            sec.append(f"<div class='warn'>{esc(f['note'])}</div>")
        parts.append(("SECTION", "\n".join(sec)))
    out = [p for p in parts if not isinstance(p, tuple)]
    out.append("".join(summary_rows) + "</table>")
    out.append(f"<p>Total basis path: <b>{total}</b>; lulus otomatis: <b>{ok}</b>; belum diuji: <b>{total - ok}</b>.</p>")
    out += [p[1] for p in parts if isinstance(p, tuple)]
    return page("Whitebox Testing — WIPAS", "Flowchart, flowgraph, cyclomatic complexity, dan basis path.", "\n".join(out)), total, ok


# ---------------------------------------------------------------------- UAT
# (skenario, role, fitur (UC), langkah, ekspektasi)
UAT = [
    ("Masuk ke aplikasi dengan akun sendiri", "Admin", "UC01", "Buka WIPAS, isi email dan password, tekan Masuk", "Halaman Beranda Hub Cakung terbuka dengan chip Admin"),
    ("Salah memasukkan password", "Viewer", "UC01", "Isi password yang salah lalu Masuk", "Muncul pesan \"Email atau password salah\""),
    ("Meminta tautan reset password", "Supervisor", "UC02", "Di Login tekan \"Lupa password?\", isi email, tekan Kirim tautan reset", "Muncul konfirmasi tautan reset terkirim"),
    ("Melihat ringkasan prediksi besok", "Manajer", "UC03", "Buka tab Beranda", "Terlihat prediksi H+1, Projection, Actual H-1, Deviasi, grafik 14 hari, dan kartu Tinjau & Setujui Alokasi"),
    ("Dashboard hanya baca untuk Tim DI", "Viewer", "UC03", "Buka tab Beranda", "Ada label Hanya baca; tidak ada kartu atau tab Manpower"),
    ("Melihat tabel dan grafik prediksi", "Admin", "UC04", "Buka Prediksi, ganti Tabel ↔ Grafik dan 7/14/30 hari", "Tabel dan grafik berganti sesuai pilihan; Faktor pendorong tampil"),
    ("Supervisor melihat prediksi tanpa faktor pendorong", "Supervisor", "UC04", "Buka Prediksi", "Kartu Faktor pendorong tidak muncul"),
    ("Memahami cara hitung jumlah Rider", "Supervisor", "UC05", "Buka Manpower, tekan Cara hitung pada Rider", "Terlihat rumus dan hasil 37 orang; tombol Setujui tidak ada"),
    ("Menyetujui rekomendasi tenaga kerja", "Manajer", "UC06", "Beranda → Tinjau & Setujui Alokasi → Setujui rekomendasi → Setujui", "Status berubah menjadi Disetujui dan tercatat di Log keputusan"),
    ("Menambah Rider karena antrean", "Manajer", "UC07", "Manpower → Sesuaikan manual → tambah Rider 3 → isi alasan → Simpan", "Status Disesuaikan manual, Rider 40 (rekomendasi 37) dan alasan tercatat"),
    ("Menyimpan penyesuaian tanpa alasan", "Admin", "UC07", "Sesuaikan manual tanpa mengisi alasan lalu Simpan", "Muncul \"Alasan wajib diisi.\" dan data tidak tersimpan"),
    ("Memeriksa kesehatan model", "Admin", "UC08", "Buka tab Evaluasi", "Terlihat status Sehat/Model Degraded, Rolling MAE, metrik validasi, batch, dan dataset"),
    ("Mengisi actual inbound hari ini", "Supervisor", "UC09", "Beranda → Input Actual Inbound → isi angka → Simpan", "Muncul perbandingan dengan prediksi dan pesan tersimpan"),
    ("Menolak angka actual negatif", "Admin", "UC09", "Isi -5 di Input Actual", "Muncul \"Nilai tidak boleh negatif.\" dan Simpan tidak bisa dipakai"),
    ("Lintas peran: actual dari Supervisor terlihat Manajer", "Supervisor, Manajer", "UC09, UC08", "Supervisor menyimpan actual; Manajer membuka Riwayat dan Evaluasi setelah batch berikutnya", "Manajer melihat actual baru di Riwayat dan dampaknya pada Rolling MAE di Evaluasi"),
    ("Mengubah kapasitas Rider", "Manajer", "UC10", "Lainnya → Konfigurasi → Capacity_Rider 400 → Simpan perubahan → Simpan", "Pratinjau menunjukkan Rider 33; perubahan masuk Riwayat perubahan"),
    ("Rasio tidak berjumlah 1,00", "Admin", "UC10", "Isi Ratio_Rider 0,60 dan Ratio_Driver 0,30", "Muncul pesan rasio harus 1,00 dan tombol Simpan nonaktif"),
    ("Melihat riwayat 14 hari", "Supervisor", "UC11", "Lainnya → Riwayat → pilih 14 hari", "Daftar 14 hari dengan status keputusan dan tanda Perlu Perhatian"),
    ("Viewer melihat riwayat tanpa keputusan", "Viewer", "UC11", "Lainnya → Riwayat", "Hanya Predicted dan Actual; tidak ada status keputusan dan tombol Export"),
    ("Mengekspor riwayat ke CSV", "Admin", "UC12", "Lainnya → Riwayat & export → Export CSV → bagikan", "Berkas CSV terbentuk dan bisa dibuka di spreadsheet dengan huruf yang benar"),
    ("Menandai semua notifikasi dibaca", "Manajer", "UC13", "Tekan lonceng → Tandai semua dibaca", "Penanda Baru hilang dan badge lonceng kosong"),
    ("Keluar dari aplikasi", "Viewer", "UC14", "Lainnya → Profil & pengaturan → Keluar → Keluar", "Kembali ke halaman Login"),
    ("Menjalankan batch prediksi manual lalu melihat hasilnya", "Admin", "UC15, UC03", "Jalankan `wipas predict` di laptop (repo wipas-research), lalu buka Beranda di aplikasi", "Tanggal target H+1 dan waktu \"Prediksi dihitung\" ter-update; notifikasi batch selesai muncul"),
    ("Bekerja saat sinyal hilang", "Admin", "UC03, UC06, UC09", "Aktifkan mode pesawat lalu buka Beranda, Manpower, Input Actual", "Data terakhir tetap tampil dengan banner offline; tombol simpan/setujui nonaktif"),
]


def uat():
    rows = []
    for i, (sc, role, uc, steps, exp) in enumerate(UAT, 1):
        rows.append(f"<tr><td>{i}</td><td>{esc(sc)}</td><td>{esc(role)}</td><td>{esc(uc)}</td><td>{esc(steps)}</td><td>{esc(exp)}</td>"
                    f'<td class="no">Belum diuji</td><td></td><td></td></tr>')
    body = ("<div class='note'>Diisi oleh penguji setelah uji manual di perangkat Android dengan data seed emulator atau data nyata. "
            "Kolom Status diubah menjadi Pass/Fail beserta tanggal dan nama penguji.</div>"
            "<table><tr><th>No</th><th>Skenario Pengujian</th><th>Role yang Menguji</th><th>Fitur yang Diuji</th><th>Langkah Pengujian</th>"
            "<th>Ekspektasi Hasil</th><th>Status (Pass/Fail)</th><th>Tanggal</th><th>Penguji</th></tr>" + "".join(rows) + "</table>")
    return page("User Acceptance Test — WIPAS", "Skenario dari sudut pandang pengguna akhir.", body)


def main():
    global RESULTS
    RESULTS = load_results(sys.argv[1])
    IMG.mkdir(parents=True, exist_ok=True)
    passed = sorted(n for n, r in RESULTS.items() if r == "success")
    failed = sorted(n for n, r in RESULTS.items() if r != "success")
    (DOCS / "test_results.txt").write_text(
        f"flutter test --reporter json — {datetime.datetime.now():%Y-%m-%d %H:%M}\n"
        f"lulus: {len(passed)}  gagal: {len(failed)}\n\n[GAGAL]\n" + "\n".join(failed) +
        "\n\n[LULUS]\n" + "\n".join(passed) + "\n", encoding="utf-8")
    bb, n_bb, ok_bb = blackbox()
    (DOCS / "blackbox_testing.html").write_text(bb, encoding="utf-8")
    wb, n_wb, ok_wb = whitebox()
    (DOCS / "whitebox_testing.html").write_text(wb, encoding="utf-8")
    (DOCS / "uat.html").write_text(uat(), encoding="utf-8")
    print(f"tests: {len(passed)} lulus, {len(failed)} gagal")
    print(f"blackbox: {n_bb} skenario, {ok_bb} lulus otomatis, {n_bb - ok_bb} belum diuji")
    print(f"whitebox: {len(WB)} fungsi, {n_wb} basis path, {ok_wb} lulus")
    print(f"uat: {len(UAT)} skenario (Belum diuji)")


if __name__ == "__main__":
    main()
