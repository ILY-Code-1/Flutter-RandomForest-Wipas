"""Generates docs/database_design.html (Firestore) and docs/database_design_v2.html
(conceptual relational: ERD, LRS) from tools/docs_db_model.py, and extracts the
PlantUML blocks to docs/img/*.puml for syntax checking and rendering.

Usage (repo root): python tools/gen_db_docs.py
"""
import html
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from docs_db_model import ENTITY_ORDER, FIRESTORE, RELATIONS, TABLES  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
IMG = DOCS / "img"

CSS = """
body{font-family:Inter,Segoe UI,Arial,sans-serif;color:#1B2433;background:#fff;margin:0 auto;max-width:1100px;padding:24px;line-height:1.5}
h1{color:#1F3A5F;font-size:26px;margin-bottom:4px}h2{color:#1F3A5F;border-bottom:2px solid #DDE3EC;padding-bottom:4px;margin-top:36px}
h3{color:#1F3A5F;margin-top:24px}.sub{color:#5B6779;margin-top:0}
.note{background:#E3F0FC;border:1px solid #90CAF9;border-radius:10px;padding:12px 16px;color:#0D3A73}
.warn{background:#FFF4D6;border:1px solid #F9A825;border-radius:10px;padding:12px 16px;color:#7A4F00}
table{border-collapse:collapse;width:100%;font-size:13px;margin:8px 0 16px}
th,td{border:1px solid #DDE3EC;padding:5px 7px;vertical-align:top;text-align:left}
th{background:#1F3A5F;color:#fff}tr:nth-child(even) td{background:#F5F7FA}
code{background:#EEF1F6;padding:1px 4px;border-radius:4px;font-size:12px}
pre.plantuml{background:#1B2433;color:#E3F0FC;padding:12px;border-radius:10px;overflow-x:auto;font-size:12px}
ul.tree{font-family:Consolas,monospace;font-size:13px}ul.tree li{margin:2px 0}
img.diagram{max-width:100%;border:1px solid #DDE3EC;border-radius:8px;margin:8px 0}
@media print{pre.plantuml{white-space:pre-wrap;color:#000;background:#fff;border:1px solid #999}h2{page-break-after:avoid}table{page-break-inside:auto}}
"""


def page(title, subtitle, body):
    return f"""<!doctype html>
<html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title><style>{CSS}</style></head>
<body><h1>{html.escape(title)}</h1><p class="sub">{subtitle}</p>
{body}
<p class="sub">Dibuat oleh <code>tools/gen_db_docs.py</code> dari <code>tools/docs_db_model.py</code>; sumber: <code>docs/firestore_schema.md</code>, <code>firebase/firestore.rules</code>, <code>firebase/firestore.indexes.json</code>, <code>lib/core/data/models.dart</code>.</p>
</body></html>
"""


def puml_block(name, code):
    """Writes docs/img/<name>.puml and returns the HTML (code + rendered image)."""
    (IMG / f"{name}.puml").write_text(code, encoding="utf-8")
    return (f'<pre class="plantuml">{html.escape(code)}</pre>\n'
            f'<p><img class="diagram" src="img/{name}.png" alt="{name}"></p>')


def esc(s):
    return html.escape(str(s))


# ================================================================ v1 Firestore
def object_diagram():
    o = ["@startuml db_object", "skinparam defaultFontName Arial", "skinparam shadowing false", "left to right direction"]
    objs = {
        "w": ("warehouses/WH-CKG-01", ['name = "Hub Cakung"', 'code = "WH-CKG-01"', 'timezone = "Asia/Jakarta"']),
        "u": ("users/uid-manajer", ['name = "Budi Santoso"', 'role = "manager"']),
        "d": ("daily_data/WH-CKG-01_20261008", ['date = "2026-10-08"', 'campaign = 0', 'payday = 0',
                                                'projection_inbound = 16200', 'actual_inbound = 17560',
                                                'actual_source = "app"']),
        "p": ("predictions/pred_WH-CKG-01_20261009", ['target_date = "2026-10-09"', 'predicted = 18420',
                                                      'projection = 15900', 'deviation_pct = 15.85', 'alert = true',
                                                      'status = "Perlu Perhatian"', 'data_status = "complete"',
                                                      'input_features = {hari: 4, bulan: 10, actual_h1: 17560, …}',
                                                      'manpower = {rider: 37, driver: 7, op_inbound: 37, op_outbound: 31, config_snapshot: {…}}',
                                                      'actual_inbound = null', 'decision_status = "approved"',
                                                      'decision_by = "uid-manajer"']),
        "c": ("operational_configs/WH-CKG-01", ['wh_id = "WH-CKG-01"', 'capacity_rider = 350', 'capacity_driver = 800',
                                                'ratio_rider = 0.7', 'ratio_driver = 0.3', 'updated_by = "uid-manajer"']),
        "h": ("operational_configs/WH-CKG-01/history/seed_1", ['capacity_op_outbound = 600', 'changed_by = "uid-manajer"',
                                                               'note = "Capacity_Op_Outbound: 580 → 600"']),
        "dl": ("decision_logs/Rz8TnB4cWq", ['prediction_id = "pred_WH-CKG-01_20261009"', 'decision_status = "approved"',
                                            'final = {rider: 37, driver: 7, op_inbound: 37, op_outbound: 31}',
                                            'note = null', 'decided_by = "uid-manajer"']),
        "mh": ("model_health/WH-CKG-01", ['status = "healthy"', 'rolling_mae_7d = 6.8', 'n_points = 7',
                                          'baseline_mae = 6.2', 'drift_threshold = 7.13', 'drift_factor = 1.15']),
        "mhh": ("model_health_history/WH-CKG-01_20261008", ['date = "2026-10-08"', 'rolling_mae_7d = 6.8', 'n_points = 7']),
        "b": ("batch_logs/WH-CKG-01_20261009", ['target_date = "2026-10-09"', 'status = "success"', 'duration_s = 134.0',
                                                'retries = 0', 'source = "H-1"']),
        "ds": ("dataset_status/WH-CKG-01", ['range_start = "2025-01-01"', 'range_end = "2026-10-09"', 'row_count = 647',
                                            'labeled_count = 646']),
        "n": ("notifications/deviation_WH-CKG-01_20261009", ['type = "deviation"', 'severity = "warning"',
                                                              'audience_roles = [admin, manager, supervisor]',
                                                              'read_by = ["uid-admin"]']),
    }
    for key, (title, fields) in objs.items():
        o.append(f'object "{title}" as {key} {{')
        o += [f"  {f}" for f in fields]
        o.append("}")
    links = [("p", "w", "wh_id"), ("d", "w", "wh_id"), ("c", "w", "wh_id"), ("c", "h", "sub-koleksi history"),
             ("c", "u", "updated_by"), ("h", "u", "changed_by"), ("dl", "p", "prediction_id"), ("dl", "u", "decided_by"),
             ("p", "u", "decision_by"), ("mh", "w", "id = wh_id"), ("mhh", "w", "wh_id"), ("b", "w", "wh_id"),
             ("ds", "w", "id = wh_id"), ("n", "w", "wh_id"), ("n", "u", "read_by[]")]
    o += [f"{a} --> {b} : {lbl}" for a, b, lbl in links]
    o.append("@enduml")
    return "\n".join(o)


def v1():
    body = []
    body.append('<div class="note">Implementasi aktual WIPAS memakai <b>Cloud Firestore (NoSQL)</b> pada paket Spark, mengikuti kontrak '
                '<code>docs/firestore_schema.md</code> v1.0 dari repo <code>wipas-research</code>. Script menulis koleksi hasil batch '
                'dengan Admin SDK; aplikasi hanya menulis field milik App: <code>predictions.actual_*</code>, <code>predictions.decision_*</code>, '
                '<code>decision_logs</code>, <code>operational_configs</code> + <code>/history</code>, dan <code>notifications.read_by</code>, '
                'dibatasi oleh <code>firebase/firestore.rules</code>.</div>')

    body.append("<h2>1. Model NoSQL: embedding vs referencing</h2>")
    body.append("""<table><tr><th>Keputusan</th><th>Strategi</th><th>Alasan (terkait fitur WIPAS)</th><th>Contoh nyata</th></tr>
<tr><td>Fitur prediktor & rekomendasi manpower</td><td><b>Embed</b> di <code>predictions</code></td><td>Selalu dibaca bersama prediksi (Beranda, Prediksi, Manpower); satu dokumen = satu baca, hemat kuota 50.000 baca/hari. <code>config_snapshot</code> membekukan kapasitas saat dihitung sehingga "Cara hitung" konsisten walau konfigurasi berubah.</td><td><code>predictions/pred_WH-CKG-01_20261009.manpower = {rider: 37, driver: 7, op_inbound: 37, op_outbound: 31, config_snapshot: {...}}</code></td></tr>
<tr><td>Feature importance & catatan script</td><td><b>Embed</b> (map / array) di <code>predictions</code> dan <code>model_health</code></td><td>Ukuran kecil dan dibaca utuh ("Faktor pendorong", catatan fallback).</td><td><code>feature_importance.actual_h1 = 0.27</code>, <code>notes = ["Fallback H-2 …"]</code></td></tr>
<tr><td>Status keputusan terkini</td><td><b>Embed</b> field App <code>decision_*</code> di <code>predictions</code></td><td>Beranda, Manpower, dan Riwayat cukup membaca prediksi (tanpa query log tambahan); Viewer tetap dapat membaca prediksi tetapi UI menyembunyikan keputusan.</td><td><code>decision_status = "adjusted"</code>, <code>decision_manpower = {rider: 40, …}</code></td></tr>
<tr><td>Riwayat keputusan</td><td><b>Referensi</b> lewat <code>prediction_id</code> (koleksi <code>decision_logs</code>)</td><td>Append-only milik App; rules melarang update/delete dan menolak Viewer. Ditulis dalam satu batch bersama <code>decision_*</code>.</td><td><code>decision_logs/{auto}.prediction_id = "pred_WH-CKG-01_20261009"</code></td></tr>
<tr><td>Riwayat konfigurasi</td><td><b>Sub-koleksi</b> <code>operational_configs/{wh_id}/history</code> + transaksi</td><td>Salinan konfigurasi sesudah perubahan + <code>changed_by</code>, <code>changed_at</code>, <code>note</code>; Python tidak membaca/menulisnya.</td><td><code>operational_configs/WH-CKG-01/history/{auto}</code></td></tr>
<tr><td>Status baca notifikasi</td><td><b>Array</b> <code>read_by</code> di dokumen notifikasi (<code>arrayUnion</code>)</td><td>Satu baca per notifikasi tanpa koleksi tambahan; rules hanya mengizinkan penerima menambahkan uid sendiri.</td><td><code>read_by = ["uid-admin"]</code></td></tr>
<tr><td>Nama pembuat log</td><td><b>Denormalisasi</b> <code>*_by_name</code> (ekstensi App)</td><td>Rules hanya mengizinkan membaca profil sendiri; nama disalin saat menulis.</td><td><code>decided_by_name = "Budi Santoso"</code></td></tr>
<tr><td>ID dokumen</td><td><b>Deterministik</b> <code>pred_{wh_id}_{YYYYMMDD}</code>, <code>{type}_{wh_id}_{YYYYMMDD}</code>, <code>{wh_id}_{YYYYMMDD}[_runN]</code></td><td>Batch idempoten (<code>set(merge=True)</code>): menjalankan ulang script tidak menggandakan dokumen.</td><td><code>pred_WH-CKG-01_20261009</code></td></tr>
<tr><td>Hindari collection group besar</td><td>Koleksi top-level per jenis + query <code>wh_id</code> + rentang tanggal + <code>limit</code></td><td>Kuota Spark; setiap query dibatasi (≤ 31 prediksi, 30 notifikasi, 60 keputusan).</td><td><code>where wh_id == … where target_date ≥ … limit 31</code></td></tr>
</table>""")

    body.append("<h2>2. Struktur koleksi</h2><ul class='tree'><li><b>(root)</b><ul>")
    for path, example, desc, writer, fields in FIRESTORE:
        if "/history/" in path:
            continue
        items = "".join(f"<li><code>{esc(f)}</code> : {esc(t)}</li>" for f, t, _, _ in fields)
        sub = ""
        if path.startswith("operational_configs/"):
            h = next(x for x in FIRESTORE if "/history/" in x[0])
            hitems = "".join(f"<li><code>{esc(f)}</code> : {esc(t)}</li>" for f, t, _, _ in h[4])
            sub = (f"<li><b>history/{{auto}}</b> — {esc(h[2])} Penulis: {esc(h[3])}. Contoh ID <code>{esc(h[1])}</code>"
                   f"<ul>{hitems}</ul></li>")
        body.append(f"<li><b>{esc(path)}</b> — {esc(desc)} Penulis: {esc(writer)}. Contoh ID <code>{esc(example)}</code>"
                    f"<ul>{items}{sub}</ul></li>")
    body.append("</ul></li></ul>")
    body.append("<p>Referensi antar koleksi: <code>wh_id</code> → <code>warehouses</code>; <code>prediction_id</code> → <code>predictions</code>; "
                "<code>decided_by</code>, <code>decision_by</code>, <code>changed_by</code>, <code>updated_by</code>, <code>actual_input_by</code>, "
                "<code>read_by[]</code> → <code>users</code>; <code>batch_log_id</code> → <code>batch_logs</code>.</p>")

    body.append("<h2>3. Struktur logis (Object Diagram)</h2><p>Satu objek contoh per koleksi. Nilai bersifat ilustrasi (skenario desain: Predicted 18.420 vs Projection 15.900), bukan hasil model.</p>")
    body.append(puml_block("db_object", object_diagram()))

    body.append("<h2>4. Spesifikasi basis data</h2>")
    body.append("<table><tr><th>No</th><th>Nama Field</th><th>Tipe Data</th><th>Koleksi</th><th>Deskripsi</th><th>Constraint / Index</th></tr>")
    n = 0
    for path, _, _, _, fields in FIRESTORE:
        for f, t, d, c in fields:
            n += 1
            body.append(f"<tr><td>{n}</td><td><code>{esc(f)}</code></td><td>{esc(t)}</td><td><code>{esc(path)}</code></td>"
                        f"<td>{esc(d)}</td><td>{esc(c)}</td></tr>")
    body.append("</table>")
    body.append("<h3>Ringkasan aturan keamanan per koleksi</h3><table><tr><th>Koleksi</th><th>Baca</th><th>Tulis</th></tr>"
                "<tr><td>predictions</td><td>semua user login</td><td>admin/supervisor: hanya actual_*; admin/manager: hanya decision_*; tanpa create/delete</td></tr>"
                "<tr><td>operational_configs</td><td>semua user login</td><td>admin/manager dengan validasi kapasitas & rasio, wh_id = ID</td></tr>"
                "<tr><td>operational_configs/{wh_id}/history, decision_logs</td><td>admin, manager, supervisor</td><td>create admin/manager atas nama sendiri; tanpa update/delete</td></tr>"
                "<tr><td>notifications</td><td>role ∈ audience_roles</td><td>penerima hanya menambah uid sendiri ke read_by</td></tr>"
                "<tr><td>users/{uid}</td><td>pemilik</td><td>tidak ada (Console)</td></tr>"
                "<tr><td>daily_data, model_health, model_health_history, batch_logs, dataset_status, warehouses</td><td>semua user login</td><td>tidak ada (Admin SDK)</td></tr></table>")
    return page("Desain Basis Data WIPAS (Firestore) — v1",
                "Model dokumen NoSQL yang benar-benar dipakai aplikasi wipas-app.", "\n".join(body)), n


# ============================================================ v2 relational
def erd():
    o = ["@startuml erd", "skinparam defaultFontName Arial", "skinparam shadowing false", "hide circle",
         "skinparam linetype ortho", "left to right direction"]
    for name in ENTITY_ORDER:
        _, _, cols = TABLES[name]
        o.append(f"entity {name} {{")
        for c in cols:
            if c["pk"]:
                tag = " <<PK>>" + (" <<FK>>" if c["fk"] else "")
                o.append(f"  * {c['name']} : {c['type']}{tag}")
        o.append("  --")
        for c in cols:
            if not c["pk"]:
                star = "" if c["null"] else "* "
                tag = " <<FK>>" if c["fk"] else ""
                o.append(f"  {star}{c['name']} : {c['type']}{tag}")
        o.append("}")
    for p, ch, cf, lbl, _ in RELATIONS:
        o.append(f"{p} {cf} {ch} : {lbl}")
    o.append("@enduml")
    return "\n".join(o)


def lrs(name, annotated):
    o = [f"@startuml {name}", "skinparam defaultFontName Arial", "skinparam shadowing false", "hide circle",
         "hide methods", "skinparam linetype ortho", "left to right direction"]
    for t in ENTITY_ORDER:
        _, _, cols = TABLES[t]
        o.append(f"class {t} <<Table>> {{")
        for c in cols:
            if c["pk"]:
                o.append(f"  + {c['name']} : {c['type']}" + (" {FK}" if c["fk"] else ""))
        for c in cols:
            if c["fk"] and not c["pk"]:
                o.append(f"  # {c['name']} : {c['type']}")
        for c in cols:
            if not c["pk"] and not c["fk"]:
                o.append(f"  - {c['name']} : {c['type']}")
        o.append("}")
    for p, ch, _, lbl, card in RELATIONS:
        left, right = [s.strip() for s in card.split(":")]
        o.append(f'{p} "{left}" --> "{right}" {ch}' + (f" : {lbl}" if annotated else ""))
    if annotated:
        notes = [
            ("ManpowerRecommendation", "1:1 embed manpower → tabel terpisah,\\nPK = FK pred_id"),
            ("PredictionNote", "array notes → tabel,\\nPK (pred_id, seq)"),
            ("BatchEvaluatedDate", "array evaluated_dates → tabel,\\nPK (batch_id, evaluated_date)"),
            ("PredictionFeatureImportance", "atribut multinilai feature_importance\\n→ tabel, PK komposit"),
            ("NotificationAudience", "array audience_roles → tabel,\\nPK (notif_id, role)"),
            ("NotificationRead", "array read_by (M:N AppUser–Notification)\\n→ tabel junction"),
        ]
        for t, txt in notes:
            o.append(f"note bottom of {t}\n  {txt.replace(chr(92) + 'n', chr(10) + '  ')}\nend note")
    o.append("@enduml")
    return "\n".join(o)


def v2():
    body = []
    body.append('<div class="warn"><b>Catatan:</b> dokumen ini adalah <b>desain relasional konseptual</b> untuk keperluan analisis '
                'dan bab skripsi. Implementasi aplikasi memakai <b>Cloud Firestore (NoSQL)</b> seperti pada '
                '<a href="database_design.html">database_design.html</a>. Nama entitas, tabel, dan atribut di bawah identik di ERD, '
                'transformasi, LRS final, dan spesifikasi.</div>')
    body.append("<h3>Pemetaan koleksi Firestore → tabel relasional</h3><table><tr><th>Tabel</th><th>Sumber Firestore</th><th>Keterangan</th></tr>")
    for t in ENTITY_ORDER:
        src, desc, _ = TABLES[t]
        body.append(f"<tr><td><b>{t}</b></td><td><code>{esc(src)}</code></td><td>{esc(desc)}</td></tr>")
    body.append("</table>")

    body.append("<h2>1. Entity Relationship Diagram (crow's foot)</h2>")
    body.append("<p>Pusat model adalah <b>Warehouse</b>: setiap data operasional terikat ke satu gudang. <b>Prediction</b> dihasilkan "
                "script per tanggal dan menjadi induk <b>ManpowerRecommendation</b> (1:0..1), <b>PredictionFeatureImportance</b>, "
                "<b>PredictionNote</b>, dan <b>DecisionLog</b>. <b>AppUser</b> membuat keputusan, menginput actual, mengubah konfigurasi, dan membaca notifikasi "
                "(M:N lewat <b>NotificationRead</b>). Atribut bertanda <code>*</code> wajib; <code>&lt;&lt;PK&gt;&gt;</code> kunci primer; "
                "<code>&lt;&lt;FK&gt;&gt;</code> kunci asing. Catatan: <code>model_health.feature_importance</code> tidak dibuat tabel "
                "tersendiri karena sama dengan bobot pada prediksi terbaru (turunan); tidak ada tabel versi model karena "
                "<code>model_version</code> hanya berupa label teks di skema.</p>")
    body.append(puml_block("erd", erd()))

    body.append("<h2>2. Transformasi ERD ke LRS</h2>")
    body.append("""<table><tr><th>Kasus</th><th>Keputusan transformasi</th><th>Tabel hasil</th></tr>
<tr><td>1:1 Warehouse–OperationalConfig, Warehouse–ModelHealth, Warehouse–DatasetStatus</td><td>PK tabel anak = FK <code>wh_id</code> (sesuai ID dokumen <code>{wh}</code>).</td><td>OperationalConfig, ModelHealth, DatasetStatus</td></tr>
<tr><td>1:0..1 Prediction–ManpowerRecommendation (embed <code>manpower</code>)</td><td>Dipisah menjadi tabel dengan PK sekaligus FK <code>pred_id</code>; <code>config_snapshot</code> diratakan menjadi kolom <code>snap_*</code>.</td><td>ManpowerRecommendation</td></tr>
<tr><td>1:N di sisi many</td><td>FK diletakkan di tabel sisi many: <code>wh_id</code>, <code>prediction_id</code>, <code>decided_by</code>, <code>decision_by</code>, <code>changed_by</code>, <code>actual_input_by</code>, <code>batch_log_id</code> (opsional). <code>updated_by</code> dan <code>actual_input_by</code> dapat berisi nilai non-uid (<code>wipas-research:seed-config</code>, <code>backfill:excel</code>) sehingga hanya <code>actual_input_by</code> yang diberi FK opsional.</td><td>DailyData, Prediction, DecisionLog, ConfigHistory, BatchLog, ModelHealthHistory, Notification</td></tr>
<tr><td>Atribut multinilai <code>feature_importance</code></td><td>Tabel terpisah, PK komposit (<code>pred_id</code>, <code>feature_name</code>).</td><td>PredictionFeatureImportance</td></tr>
<tr><td>Atribut multinilai <code>audience_roles</code></td><td>Tabel terpisah, PK komposit (<code>notif_id</code>, <code>role</code>).</td><td>NotificationAudience</td></tr>
<tr><td>Atribut multinilai <code>notes</code> (prediksi) dan <code>evaluated_dates</code> (batch)</td><td>Tabel terpisah, PK komposit (<code>pred_id</code>, <code>seq</code>) dan (<code>batch_id</code>, <code>evaluated_date</code>). <code>dataset_status.target_dates</code>/<code>missing_dates</code> tidak dibuat tabel karena dapat diturunkan dari DailyData.</td><td>PredictionNote, BatchEvaluatedDate</td></tr>
<tr><td>M:N AppUser–Notification (array <code>read_by</code>)</td><td>Tabel junction dengan PK komposit (<code>uid</code>, <code>notif_id</code>).</td><td>NotificationRead</td></tr>
<tr><td>Map <code>input_features</code> (1:1, ukuran tetap)</td><td>Diratakan menjadi kolom <code>feat_*</code> di Prediction (tidak perlu tabel).</td><td>Prediction</td></tr>
<tr><td>Map <code>recommended</code>/<code>final</code> pada keputusan, <code>decision_manpower</code> pada prediksi, salinan konfigurasi pada history</td><td>Diratakan menjadi kolom <code>recommended_*</code>, <code>final_*</code>, <code>decision_*</code>, dan kolom kapasitas/rasio di ConfigHistory.</td><td>DecisionLog, Prediction, ConfigHistory</td></tr>
</table>
<p>Notasi: <code>+</code> PK, <code>#</code> FK, <code>-</code> atribut; <code>{FK}</code> pada PK menandai PK yang juga FK.</p>""")
    body.append(puml_block("lrs_transformasi", lrs("lrs_transformasi", annotated=True)))

    body.append("<h2>3. LRS final</h2>")
    body.append(puml_block("lrs_final", lrs("lrs_final", annotated=False)))

    body.append("<h2>4. Spesifikasi basis data</h2>")
    for t in ENTITY_ORDER:
        src, desc, cols = TABLES[t]
        ordered = [c for c in cols if c["pk"]] + [c for c in cols if c["fk"] and not c["pk"]] + \
                  [c for c in cols if not c["pk"] and not c["fk"]]
        body.append(f"<h3>Tabel {t}</h3><p>{esc(desc)} — sumber <code>{esc(src)}</code>.</p>")
        body.append("<table><tr><th>No</th><th>Nama Field</th><th>Tipe Data</th><th>Ukuran/Presisi</th><th>PK</th>"
                    "<th>FK (Tabel.Field)</th><th>Null/Not Null</th><th>Default</th><th>Deskripsi</th></tr>")
        for i, c in enumerate(ordered, 1):
            body.append(f"<tr><td>{i}</td><td><code>{c['name']}</code></td><td>{c['type']}</td><td>{c['size'] or '—'}</td>"
                        f"<td>{'Ya' if c['pk'] else ''}</td><td>{c['fk'] or ''}</td>"
                        f"<td>{'Null' if c['null'] else 'Not Null'}</td><td>{esc(c['default']) or '—'}</td><td>{esc(c['desc'])}</td></tr>")
        body.append("</table>")
    return page("Desain Basis Data WIPAS — v2 (Relasional Konseptual)",
                "ERD, transformasi ke LRS, LRS final, dan spesifikasi tabel.", "\n".join(body))


def main():
    IMG.mkdir(parents=True, exist_ok=True)
    html1, n_fields = v1()
    (DOCS / "database_design.html").write_text(html1, encoding="utf-8")
    (DOCS / "database_design_v2.html").write_text(v2(), encoding="utf-8")
    print(f"database_design.html: {len(FIRESTORE)} koleksi, {n_fields} field")
    print(f"database_design_v2.html: {len(TABLES)} tabel, {len(RELATIONS)} relasi")


if __name__ == "__main__":
    main()
