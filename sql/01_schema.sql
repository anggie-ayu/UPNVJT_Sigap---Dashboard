-- UPNVJT SIGAP - Skema MySQL (mengikuti PDM: 6 tabel)
-- Jalankan:  mysql -u root -p < sql/01_schema.sql
-- Catatan: bila database SIGAP kelompok sudah ada, cukup cocokkan nama tabel/kolom
-- dengan PDM_MAPPING.md dan lewati berkas ini.

CREATE DATABASE IF NOT EXISTS sigap_db
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sigap_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS transaksi_keuangan;
DROP TABLE IF EXISTS ulasan;
DROP TABLE IF EXISTS negosiasi;
DROP TABLE IF EXISTS pesanan;
DROP TABLE IF EXISTS kategori_layanan;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE users (
  id_user        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nama_lengkap   VARCHAR(100) NOT NULL,
  email          VARCHAR(100) NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,
  no_telepon     VARCHAR(20)  NOT NULL,
  role           ENUM('pelanggan','kru','admin') NOT NULL,
  jadwal_krs     TEXT NULL,
  PRIMARY KEY (id_user),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE kategori_layanan (
  id_kategori     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nama_kategori   VARCHAR(100) NOT NULL,
  tarif_dasar_km  DECIMAL(12,2) NOT NULL DEFAULT 0,   -- 0 = harga dinegosiasikan
  PRIMARY KEY (id_kategori)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pesanan (
  id_pesanan        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_pelanggan      INT UNSIGNED NOT NULL,
  id_kru            INT UNSIGNED NULL,
  id_kategori       INT UNSIGNED NOT NULL,
  lokasi_jemput     VARCHAR(150) NOT NULL,
  lokasi_antar      VARCHAR(150) NOT NULL,
  waktu_dibutuhkan  DATETIME NOT NULL,
  detail_pesanan    TEXT NOT NULL,
  estimasi_biaya    DECIMAL(12,2) NOT NULL DEFAULT 0,
  status_pesanan    ENUM('menunggu','diambil','dikerjakan','selesai','dibatalkan') NOT NULL DEFAULT 'menunggu',
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_pesanan),
  KEY idx_pesanan_created (created_at),
  KEY idx_pesanan_status (status_pesanan),
  CONSTRAINT fk_pesanan_pelanggan FOREIGN KEY (id_pelanggan) REFERENCES users (id_user),
  CONSTRAINT fk_pesanan_kru       FOREIGN KEY (id_kru)       REFERENCES users (id_user),
  CONSTRAINT fk_pesanan_kategori  FOREIGN KEY (id_kategori)  REFERENCES kategori_layanan (id_kategori)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE negosiasi (
  id_negosiasi    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_pesanan      INT UNSIGNED NOT NULL,
  id_pengirim     INT UNSIGNED NOT NULL,
  harga_tawar     DECIMAL(12,2) NOT NULL,
  status_tawaran  ENUM('menunggu','diterima','ditolak') NOT NULL DEFAULT 'menunggu',
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_negosiasi),
  CONSTRAINT fk_nego_pesanan  FOREIGN KEY (id_pesanan)  REFERENCES pesanan (id_pesanan),
  CONSTRAINT fk_nego_pengirim FOREIGN KEY (id_pengirim) REFERENCES users (id_user)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ulasan (
  id_ulasan     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_pesanan    INT UNSIGNED NOT NULL,
  id_pelanggan  INT UNSIGNED NOT NULL,
  id_kru        INT UNSIGNED NOT NULL,
  rating        TINYINT UNSIGNED NOT NULL,
  komentar      TEXT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_ulasan),
  CONSTRAINT fk_ulasan_pesanan   FOREIGN KEY (id_pesanan)   REFERENCES pesanan (id_pesanan),
  CONSTRAINT fk_ulasan_pelanggan FOREIGN KEY (id_pelanggan) REFERENCES users (id_user),
  CONSTRAINT fk_ulasan_kru       FOREIGN KEY (id_kru)       REFERENCES users (id_user)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE transaksi_keuangan (
  id_transaksi    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_pesanan      INT UNSIGNED NOT NULL,
  total_bayar     DECIMAL(12,2) NOT NULL,
  komisi_admin    DECIMAL(12,2) NOT NULL,
  pendapatan_kru  DECIMAL(12,2) NOT NULL,
  waktu_selesai   DATETIME NOT NULL,
  PRIMARY KEY (id_transaksi),
  KEY idx_trx_waktu (waktu_selesai),
  CONSTRAINT fk_trx_pesanan FOREIGN KEY (id_pesanan) REFERENCES pesanan (id_pesanan)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
