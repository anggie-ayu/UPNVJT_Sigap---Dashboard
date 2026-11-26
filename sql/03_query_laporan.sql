-- UPNVJT SIGAP - Query laporan dashboard (contoh dengan nilai parameter)
-- Di aplikasi, :dari / :sampai / :kat diisi dari filter (periode, kategori).
-- :kat = NULL berarti semua kategori; ganti dengan id_kategori untuk memfilter.
USE sigap_db;
SET @dari = DATE_SUB(NOW(), INTERVAL 30 DAY), @sampai = NOW(), @kat = NULL;

-- [qDaftarKategori]
-- Daftar kategori untuk dropdown filter.
SELECT id_kategori, nama_kategori
FROM kategori_layanan
ORDER BY id_kategori;

-- [qKpiPesanan]
-- KPI pesanan: total, aktif, selesai, dibatalkan (grouping status dengan SUM kondisi).
SELECT
  COUNT(*) AS total_pesanan,
  COALESCE(SUM(p.status_pesanan IN ('menunggu','diambil','dikerjakan')), 0) AS pesanan_aktif,
  COALESCE(SUM(p.status_pesanan = 'selesai'), 0) AS pesanan_selesai,
  COALESCE(SUM(p.status_pesanan = 'dibatalkan'), 0) AS pesanan_batal
FROM pesanan p
WHERE p.created_at BETWEEN @dari AND @sampai
  AND (@kat IS NULL OR p.id_kategori = @kat);

-- [qKpiKeuangan]
-- KPI keuangan: omzet, komisi admin 8%, pendapatan kru.
SELECT
  COUNT(t.id_transaksi) AS jumlah_transaksi,
  COALESCE(SUM(t.total_bayar), 0) AS omzet,
  COALESCE(SUM(t.komisi_admin), 0) AS komisi,
  COALESCE(SUM(t.pendapatan_kru), 0) AS pendapatan_kru
FROM transaksi_keuangan t
JOIN pesanan p ON p.id_pesanan = t.id_pesanan
WHERE t.waktu_selesai BETWEEN @dari AND @sampai
  AND (@kat IS NULL OR p.id_kategori = @kat);

-- [qKpiRating]
-- KPI rating rata-rata.
SELECT
  COALESCE(AVG(u.rating), 0) AS rata_rating,
  COUNT(u.id_ulasan) AS jumlah_ulasan
FROM ulasan u
JOIN pesanan p ON p.id_pesanan = u.id_pesanan
WHERE u.created_at BETWEEN @dari AND @sampai
  AND (@kat IS NULL OR p.id_kategori = @kat);

-- [qBarPerKategori]
-- BAR CHART (grouping per kategori): jumlah pesanan & omzet pesanan selesai.
SELECT
  k.nama_kategori AS label,
  COUNT(p.id_pesanan) AS jumlah,
  COALESCE(SUM(CASE WHEN p.status_pesanan = 'selesai' THEN p.estimasi_biaya ELSE 0 END), 0) AS omzet
FROM kategori_layanan k
LEFT JOIN pesanan p
  ON p.id_kategori = k.id_kategori
 AND p.created_at BETWEEN @dari AND @sampai
WHERE (@kat IS NULL OR k.id_kategori = @kat)
GROUP BY k.id_kategori, k.nama_kategori
ORDER BY jumlah DESC, k.nama_kategori;

-- [qBarPerKru]
-- BAR CHART (grouping per kru): jumlah pesanan & omzet pesanan selesai.
SELECT
  u.nama_lengkap AS label,
  COUNT(p.id_pesanan) AS jumlah,
  COALESCE(SUM(CASE WHEN p.status_pesanan = 'selesai' THEN p.estimasi_biaya ELSE 0 END), 0) AS omzet
FROM users u
LEFT JOIN pesanan p
  ON p.id_kru = u.id_user
 AND p.created_at BETWEEN @dari AND @sampai
 AND (@kat IS NULL OR p.id_kategori = @kat)
WHERE u.role = 'kru'
GROUP BY u.id_user, u.nama_lengkap
ORDER BY jumlah DESC, u.nama_lengkap;

-- [qTrenTransaksi]
-- LINE CHART (grouping periode): tren transaksi. {FMT} diganti format DATE_FORMAT:
-- harian '%Y-%m-%d', mingguan '%x-W%v', bulanan '%Y-%m'.
SELECT
  DATE_FORMAT(t.waktu_selesai, '%Y-%m-%d') AS periode,
  COUNT(t.id_transaksi) AS jumlah,
  SUM(t.total_bayar) AS omzet,
  SUM(t.komisi_admin) AS komisi
FROM transaksi_keuangan t
JOIN pesanan p ON p.id_pesanan = t.id_pesanan
WHERE t.waktu_selesai BETWEEN @dari AND @sampai
  AND (@kat IS NULL OR p.id_kategori = @kat)
GROUP BY DATE_FORMAT(t.waktu_selesai, '%Y-%m-%d')
ORDER BY periode;

-- [qPieStatus]
-- PIE CHART: komposisi status pesanan.
SELECT
  p.status_pesanan AS status,
  COUNT(*) AS jumlah
FROM pesanan p
WHERE p.created_at BETWEEN @dari AND @sampai
  AND (@kat IS NULL OR p.id_kategori = @kat)
GROUP BY p.status_pesanan
ORDER BY jumlah DESC;

-- [qPesananTerbaru]
-- Tabel detail pesanan terbaru sesuai filter.
SELECT
  p.id_pesanan,
  pel.nama_lengkap AS pelanggan,
  k.nama_kategori AS kategori,
  COALESCE(kr.nama_lengkap, '-') AS kru,
  p.status_pesanan AS status,
  p.estimasi_biaya AS biaya,
  p.created_at AS dibuat
FROM pesanan p
JOIN users pel ON pel.id_user = p.id_pelanggan
JOIN kategori_layanan k ON k.id_kategori = p.id_kategori
LEFT JOIN users kr ON kr.id_user = p.id_kru
WHERE p.created_at BETWEEN @dari AND @sampai
  AND (@kat IS NULL OR p.id_kategori = @kat)
ORDER BY p.created_at DESC
LIMIT 8;
