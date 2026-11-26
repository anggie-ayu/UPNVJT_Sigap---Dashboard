# UPNVJT SIGAP — Aplikasi Desktop Admin (Flutter) + Dashboard Laporan MySQL

Aplikasi desktop untuk administrasi layanan bantuan antar mahasiswa UPN "Veteran" Jawa Timur. 

UPNVJT Sigap dibuat untuk membantu pengelolaan layanan bantuan antar mahasiswa di Universitas Pembangunan Nasional "Veteran" Jawa Timur. Merupakan pengembangan dari layanan UPNVJT Sigap yang sebelumnya masih dilakukan melalui chat. Dengan ini, proses pengelolaan data dan pesanan dibuat lebih terstruktur sehingga admin dapat mengelola pengguna, kategori layanan, pesanan, transaksi, dan data lainnya menjadi satu.

Struktur model mengikuti PDM SIGAP: `users`, `kategori_layanan`, `pesanan`, `negosiasi`, `ulasan`,
dan `transaksi_keuangan`.


## Screenshot Dashboard


![Dashboard Laporan — bar chart dan pie chart](docs/screenshots/Cuplikan Layar 2026-11-26 195423.png)
![Dashboard Laporan — line chart](docs/screenshots/Cuplikan Layar 2026-11-26 195453.png)
![Dashboard Laporan — filter kategori & grouping](docs/screenshots/Cuplikan Layar 2026-11-26 202712.png)


## Akun demo untuk login Admin

- Email: `sultan@email.com`
- Kata sandi: `admin123`

## Fitur yang tersedia

- **Dashboard Laporan (MySQL)**: KPI, bar/line/pie chart, filter periode & kategori, grouping, tabel pesanan terbaru.
- Login Admin (panel desktop dibatasi untuk role Admin). Registrasi mandiri hanya untuk Pelanggan; Kru hanya didaftarkan Admin.
- CRUD master kategori layanan (termasuk kategori tetap **Lainnya (Request)**) dan master pengguna.
- Kelola status & ubah data pesanan, status kru Free/Sibuk, dan **negosiasi harga** per pesanan.
- Laporan Keuangan dan ekspor CSV (teks yang bisa disalin).
- Profil admin, ubah kata sandi, logout.

## Pemetaan model ke PDM

| Model aplikasi | Tabel PDM | Keterangan |
|---|---|---|
| `UserModel` | `users` | data akun dan role |
| `KategoriLayanan` | `kategori_layanan` | nama kategori dan tarif dasar per km |
| `Pesanan` | `pesanan` | pelanggan, kru, kategori, lokasi, waktu, biaya, status |
| `Negosiasi` | `negosiasi` | tawaran harga, pengirim, status tawaran |
| `Ulasan` | `ulasan` | rating dan komentar pesanan |
| `TransaksiKeuangan` | `transaksi_keuangan` | total bayar, komisi admin, pendapatan kru |

| Nama | NPM | Peran |
|---|---|---|
| Meutia Zaini Siregar | 25082010199 | Captain |
| Zaskia Syakira Nazahrani | 25082010206 | Hustler |
| Aprilia Tri Jayanti A. | 25082010221 | Hipster |
| Anggie Ayu Ramadhani | 25082010225 | Hacker |