"""Use case list shared by the test-document generator and tools/check_docs.py."""

USE_CASES = [
    ("UC01", "Login", ["Admin", "Manajer", "Supervisor", "Viewer"]),
    ("UC02", "Reset Kata Sandi", ["Admin", "Manajer", "Supervisor", "Viewer"]),
    ("UC03", "Melihat Beranda", ["Admin", "Manajer", "Supervisor", "Viewer"]),
    ("UC04", "Melihat Prediksi H+1/H+2", ["Admin", "Manajer", "Supervisor", "Viewer"]),
    ("UC05", "Melihat Rekomendasi Manpower", ["Admin", "Manajer", "Supervisor"]),
    ("UC06", "Menyetujui Rekomendasi", ["Admin", "Manajer"]),
    ("UC07", "Menyesuaikan Manpower Manual", ["Admin", "Manajer"]),
    ("UC08", "Melihat Evaluasi Model", ["Admin", "Manajer", "Viewer"]),
    ("UC09", "Input Actual Inbound", ["Admin", "Supervisor"]),
    ("UC10", "Mengatur Konfigurasi Kapasitas", ["Admin", "Manajer"]),
    ("UC11", "Melihat Riwayat dan Log Keputusan", ["Admin", "Manajer", "Supervisor", "Viewer"]),
    ("UC12", "Export CSV Riwayat", ["Admin"]),
    ("UC13", "Mengelola Notifikasi", ["Admin", "Manajer", "Supervisor", "Viewer"]),
    ("UC14", "Melihat Profil dan Keluar", ["Admin", "Manajer", "Supervisor", "Viewer"]),
    ("UC15", "Menjalankan Batch Prediksi", ["Script Batch Prediksi"]),
]

APP_ROLES = ["Admin", "Manajer", "Supervisor", "Viewer"]
