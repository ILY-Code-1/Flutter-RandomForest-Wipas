"""Writes docs/index.html: table of contents for all documentation and images."""
import html
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from docs_uc import USE_CASES  # noqa: E402

DOCS = pathlib.Path(__file__).resolve().parent.parent / "docs"
esc = html.escape

files = [
    ("DOC_REPORT.md", "Laporan dokumentasi: inventaris, N use case, asumsi, keterbatasan, langkah manual"),
    ("use_case.txt", "Use Case Diagram (PlantUML)"),
    ("activity.txt", "Activity Diagram, satu per use case (PlantUML)"),
    ("sequence.txt", "Sequence Diagram, satu per use case (PlantUML)"),
    ("class.txt", "Class Diagram konseptual domain (PlantUML)"),
    ("database_design.html", "Desain basis data Firestore v1 (NoSQL, object diagram, spesifikasi)"),
    ("database_design_v2.html", "Desain relasional konseptual v2 (ERD, LRS, spesifikasi)"),
    ("blackbox_testing.html", "Blackbox testing per use case"),
    ("whitebox_testing.html", "Whitebox testing (flowchart, flowgraph, V(G), basis path)"),
    ("uat.html", "User Acceptance Test (diisi manual)"),
    ("test_results.txt", "Ringkasan hasil flutter test (bukti otomatis)"),
    ("HANDOFF.md", "Handoff pengembangan aplikasi"),
    ("architecture.md", "Arsitektur aplikasi"),
    ("rbac_matrix.md", "Matriks akses per peran"),
    ("firestore_schema.md", "Kontrak data Firestore"),
]
rows = "".join(f'<tr><td><a href="{f}">{f}</a></td><td>{esc(d)}</td></tr>' for f, d in files)
uc_rows = "".join(
    f'<tr><td>{c}</td><td>{esc(n)}</td><td>{esc(", ".join(a))}</td>'
    f'<td><a href="img/act_{c}.png">activity</a></td><td><a href="img/seq_{c}.png">sequence</a></td></tr>'
    for c, n, a in USE_CASES)
others = sorted(p.name for p in (DOCS / "img").glob("*.png") if not p.name.startswith(("act_", "seq_")))
img_rows = "".join(f'<li><a href="img/{n}">{n}</a></li>' for n in others)
style = ("body{font-family:Inter,Segoe UI,Arial,sans-serif;max-width:1000px;margin:auto;padding:24px;color:#1B2433}"
         "h1,h2{color:#1F3A5F}table{border-collapse:collapse;width:100%}th,td{border:1px solid #DDE3EC;padding:6px 8px;text-align:left}"
         "th{background:#1F3A5F;color:#fff}a{color:#2F5F9F}")
(DOCS / "index.html").write_text(f"""<!doctype html><html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Dokumentasi WIPAS</title><style>{style}</style></head>
<body><h1>Dokumentasi Teknis WIPAS (wipas-app)</h1>
<p>Warehouse Inbound Prediction &amp; Allocation System — aplikasi Flutter + Firebase.</p>
<h2>Berkas</h2><table><tr><th>Berkas</th><th>Isi</th></tr>{rows}</table>
<h2>Use case (N = {len(USE_CASES)})</h2><p><a href="img/use_case.png">Use Case Diagram</a> · <a href="img/class_domain.png">Class Diagram</a></p>
<table><tr><th>ID</th><th>Use case</th><th>Aktor</th><th colspan="2">Diagram</th></tr>{uc_rows}</table>
<h2>Gambar lain</h2><ul>{img_rows}</ul></body></html>
""", encoding="utf-8")
print("index.html ditulis")
