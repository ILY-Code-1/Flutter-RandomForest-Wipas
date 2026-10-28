"""Automatic consistency checks for the WIPAS documentation (docs/).

Usage (repo root): python tools/check_docs.py
Exit code 0 = all checks pass; 1 = at least one violation.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from docs_uc import APP_ROLES, USE_CASES  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
results = []


def check(name, ok, detail=""):
    results.append((ok, name, detail))


def read(p):
    return (DOCS / p).read_text(encoding="utf-8")


def blocks(text):
    """Splits a multi-diagram PlantUML file into (title_comment, body) pairs."""
    out, title = [], None
    for chunk in re.split(r"(?m)^@enduml\s*$", text):
        m = re.search(r"' == (?:Activity|Sequence): (.+?) ==", chunk)
        if "@startuml" in chunk:
            out.append((m.group(1) if m else title, chunk.split("@startuml", 1)[1]))
    return out


uc_codes = [c for c, _, _ in USE_CASES]
uc_names = [f"{c} {n}" for c, n, _ in USE_CASES]

# --- use case diagram
uc_txt = read("use_case.txt")
ucs = re.findall(r'usecase "(UC\d+) ([^"]+)" as (UC\d+)', uc_txt)
N = len(ucs)
check("Use case: jumlah 14–20", 14 <= N <= 20, f"N = {N}")
check("Use case: nama & urutan = daftar baku (docs_uc.py)", [f"{a} {b}" for a, b, _ in ucs] == uc_names)
actors = set(re.findall(r'actor "[^"]+" as (\w+)', uc_txt))
for bad in ("participant", "database", "class ", "lifeline"):
    check(f"Use case: tanpa elemen '{bad.strip()}'", bad not in uc_txt)
human = {a for a in actors if a not in ("Pengguna", "Script")}
check("Use case: aktor manusia = role aplikasi", human == set(APP_ROLES), f"{sorted(human)}")

# --- activity
act = blocks(read("activity.txt"))
check("Activity: jumlah diagram = N", len(act) == N, f"{len(act)} vs N={N}")
check("Activity: judul & urutan = use case", [t for t, _ in act] == uc_names)
for t, body in act:
    n_act = len(re.findall(r"(?m)^\s*:[^\n]*;\s*$", body))
    check(f"Activity '{t}': ≤ 8 aktivitas", n_act <= 8, f"{n_act}")
    check(f"Activity '{t}': sintaks baru (start/stop)", "start" in body and "stop" in body and "(*)" not in body)

# --- sequence
seq_txt = read("sequence.txt")
seq = blocks(seq_txt)
check("Sequence: jumlah diagram = N", len(seq) == N, f"{len(seq)} vs N={N}")
check("Sequence: judul & urutan = use case", [t for t, _ in seq] == uc_names)
for kw in ("participant", "database", "queue"):
    check(f"Sequence: tanpa kata kunci '{kw}'", not re.search(rf"(?m)^\s*{kw}\b", seq_txt))
for t, body in seq:
    lifelines = re.findall(r"(?m)^\s*(actor|boundary|control|entity)\s", body)
    msgs = re.findall(r"(?m)^\s*[\w\"]+\s*-{1,2}>", body)
    kinds = {k for k in lifelines}
    check(f"Sequence '{t}': ≤ 4 lifeline", len(lifelines) <= 4, f"{len(lifelines)}")
    check(f"Sequence '{t}': ≤ 10 pesan", len(msgs) <= 10, f"{len(msgs)}")
    check(f"Sequence '{t}': actor+boundary+control+entity", kinds == {"actor", "boundary", "control", "entity"}, f"{sorted(kinds)}")

# --- class
cls = re.findall(r"(?m)^class (\w+)", read("class.txt"))
check("Class: ≤ 8 kelas", len(cls) <= 8, f"{len(cls)}: {', '.join(cls)}")
bad_names = [c for c in cls if re.search(r"(Controller|Service|Screen|Repository|Provider|View|Route)$", c)]
check("Class: hanya entitas domain", not bad_names, ", ".join(bad_names))

# --- ERD = LRS = spesifikasi
erd = set(re.findall(r"(?m)^entity (\w+) \{", (DOCS / "img" / "erd.puml").read_text(encoding="utf-8")))
lrs_t = set(re.findall(r"(?m)^class (\w+) <<Table>>", (DOCS / "img" / "lrs_transformasi.puml").read_text(encoding="utf-8")))
lrs_f = set(re.findall(r"(?m)^class (\w+) <<Table>>", (DOCS / "img" / "lrs_final.puml").read_text(encoding="utf-8")))
v2 = read("database_design_v2.html")
spec = set(re.findall(r"<h3>Tabel (\w+)</h3>", v2))
check("DB v2: entitas ERD = tabel LRS transformasi = LRS final = spesifikasi",
      erd == lrs_t == lrs_f == spec and len(erd) > 0, f"ERD {len(erd)}, LRS {len(lrs_f)}, spek {len(spec)}")
check("DB v2: diagram ada di <pre class=\"plantuml\">", v2.count('<pre class="plantuml">') >= 3)
check("DB v2: catatan relasional konseptual", "desain relasional konseptual" in v2)
v1 = read("database_design.html")
check("DB v1: object diagram di <pre class=\"plantuml\">", '<pre class="plantuml">' in v1 and "object " in v1)

# --- testing docs
bb = read("blackbox_testing.html")
uat = read("uat.html")
bb_ucs = re.findall(r'<tr class="group"><td colspan="8">(UC\d+)', bb)
check("Blackbox: setiap use case punya grup", bb_ucs == uc_codes, f"{len(bb_ucs)}")
for code in uc_codes:
    seg = bb.split(f'colspan="8">{code} ')[1].split('<tr class="group">')[0]
    check(f"Blackbox {code}: ≥ 2 skenario", seg.count("<tr>") >= 2, f"{seg.count('<tr>')}")
uat_rows = re.findall(r"<tr><td>\d+</td><td>[^<]*</td><td>([^<]*)</td><td>([^<]*)</td>", uat)
uat_roles = {r.strip() for roles, _ in uat_rows for r in roles.split(",")}
uat_ucs = {u.strip() for _, ucs_ in uat_rows for u in ucs_.split(",")}
check("UAT: role penguji = aktor manusia use case", uat_roles == set(APP_ROLES), f"{sorted(uat_roles)}")
check("Fitur: blackbox = UAT = use case", set(bb_ucs) == uat_ucs == set(uc_codes),
      f"UAT tanpa: {sorted(set(uc_codes) - uat_ucs)}")
check("UAT: status awal 'Belum diuji'", "Pass</td>" not in uat and uat.count("Belum diuji") == len(uat_rows))
# A "Lulus" row must cite a test name in Keterangan.
lulus_rows = re.findall(r'<td class="ok">Lulus</td><td>([^<]*)</td>', bb)
check("Blackbox: setiap 'Lulus' menyebut test", all(k.strip() for k in lulus_rows), f"{len(lulus_rows)} baris Lulus")

# --- rendered images
img = DOCS / "img"
expected = ["use_case", "class_domain", "db_object", "erd", "lrs_transformasi", "lrs_final"] + \
    [f"act_{c}" for c in uc_codes] + [f"seq_{c}" for c in uc_codes] + \
    [p.stem for p in img.glob("wb_*.puml")]
missing = [e for e in expected if not (img / f"{e}.png").exists()]
check("Render: semua PNG ada di docs/img", not missing, ", ".join(missing))

# --- outputs exist
for f in ["use_case.txt", "activity.txt", "sequence.txt", "class.txt", "database_design.html", "database_design_v2.html",
          "blackbox_testing.html", "whitebox_testing.html", "uat.html", "index.html", "DOC_REPORT.md"]:
    check(f"Berkas ada: docs/{f}", (DOCS / f).exists())

bad = [r for r in results if not r[0]]
for ok, name, detail in results:
    print(f"[{'OK ' if ok else 'GAGAL'}] {name}" + (f" — {detail}" if detail else ""))
print(f"\n{len(results) - len(bad)}/{len(results)} pemeriksaan lulus.")
sys.exit(1 if bad else 0)
