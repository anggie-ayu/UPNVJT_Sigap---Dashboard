import '../models/models.dart';
import 'db.dart';
import 'report_queries.dart';

/// Pilihan rentang waktu laporan.
enum Periode { tujuhHari, tigaPuluhHari, sembilanPuluhHari, semua, kustom }

extension PeriodeX on Periode {
  String get label {
    switch (this) {
      case Periode.tujuhHari:
        return '7 hari';
      case Periode.tigaPuluhHari:
        return '30 hari';
      case Periode.sembilanPuluhHari:
        return '90 hari';
      case Periode.semua:
        return 'Semua';
      case Periode.kustom:
        return 'Kustom';
    }
  }
}

/// Grouping waktu untuk line chart.
enum GrupTren { harian, mingguan, bulanan }

extension GrupTrenX on GrupTren {
  String get label {
    switch (this) {
      case GrupTren.harian:
        return 'Harian';
      case GrupTren.mingguan:
        return 'Mingguan';
      case GrupTren.bulanan:
        return 'Bulanan';
    }
  }

  /// Format DATE_FORMAT MySQL untuk mengelompokkan periode.
  String get formatSql {
    switch (this) {
      case GrupTren.harian:
        return '%Y-%m-%d';
      case GrupTren.mingguan:
        return '%x-W%v';
      case GrupTren.bulanan:
        return '%Y-%m';
    }
  }
}

/// Grouping untuk bar chart.
enum GrupBar { kategori, kru }

extension GrupBarX on GrupBar {
  String get label => this == GrupBar.kategori ? 'Per kategori' : 'Per kru';
}

/// Filter laporan: rentang tanggal, kategori, dan jenis grouping.
class ReportFilter {
  ReportFilter({
    this.periode = Periode.tigaPuluhHari,
    this.dariKustom,
    this.sampaiKustom,
    this.idKategori,
    this.grupTren = GrupTren.harian,
    this.grupBar = GrupBar.kategori,
  });

  Periode periode;
  DateTime? dariKustom;
  DateTime? sampaiKustom;
  int? idKategori; // null = semua kategori
  GrupTren grupTren;
  GrupBar grupBar;

  DateTime get sampai {
    if (periode == Periode.kustom && sampaiKustom != null) {
      final DateTime s = sampaiKustom!;
      return DateTime(s.year, s.month, s.day, 23, 59, 59);
    }
    return DateTime.now();
  }

  DateTime get dari {
    final DateTime now = DateTime.now();
    final DateTime hariIni = DateTime(now.year, now.month, now.day);
    switch (periode) {
      case Periode.tujuhHari:
        return hariIni.subtract(const Duration(days: 6));
      case Periode.tigaPuluhHari:
        return hariIni.subtract(const Duration(days: 29));
      case Periode.sembilanPuluhHari:
        return hariIni.subtract(const Duration(days: 89));
      case Periode.semua:
        return DateTime(2000);
      case Periode.kustom:
        final DateTime d = dariKustom ?? hariIni.subtract(const Duration(days: 29));
        return DateTime(d.year, d.month, d.day);
    }
  }

  static String _fmt(DateTime d) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dua(d.month)}-${dua(d.day)} ${dua(d.hour)}:${dua(d.minute)}:${dua(d.second)}';
  }

  /// Parameter bernama untuk query (:dari, :sampai, :kat).
  Map<String, dynamic> get params => <String, dynamic>{
        'dari': _fmt(dari),
        'sampai': _fmt(sampai),
        'kat': idKategori,
      };
}

class KategoriOpsi {
  const KategoriOpsi(this.id, this.nama);
  final int id;
  final String nama;
}

class TitikBar {
  const TitikBar(this.label, this.jumlah, this.omzet);
  final String label;
  final int jumlah;
  final double omzet;
}

class TitikTren {
  const TitikTren(this.periode, this.jumlah, this.omzet, this.komisi);
  final String periode;
  final int jumlah;
  final double omzet;
  final double komisi;
}

class IrisanStatus {
  const IrisanStatus(this.status, this.jumlah);
  final StatusPesanan status;
  final int jumlah;
}

class BarisPesanan {
  const BarisPesanan({
    required this.idPesanan,
    required this.pelanggan,
    required this.kategori,
    required this.kru,
    required this.status,
    required this.biaya,
    required this.dibuat,
  });
  final int idPesanan;
  final String pelanggan;
  final String kategori;
  final String kru;
  final StatusPesanan status;
  final double biaya;
  final DateTime? dibuat;
}

/// Hasil seluruh query laporan untuk satu kombinasi filter.
class DashboardData {
  DashboardData({
    required this.totalPesanan,
    required this.pesananAktif,
    required this.pesananSelesai,
    required this.pesananBatal,
    required this.jumlahTransaksi,
    required this.omzet,
    required this.komisi,
    required this.pendapatanKru,
    required this.rataRating,
    required this.jumlahUlasan,
    required this.bar,
    required this.tren,
    required this.pie,
    required this.terbaru,
  });

  final int totalPesanan;
  final int pesananAktif;
  final int pesananSelesai;
  final int pesananBatal;
  final int jumlahTransaksi;
  final double omzet;
  final double komisi;
  final double pendapatanKru;
  final double rataRating;
  final int jumlahUlasan;
  final List<TitikBar> bar;
  final List<TitikTren> tren;
  final List<IrisanStatus> pie;
  final List<BarisPesanan> terbaru;
}

double _d(String? v) => double.tryParse(v ?? '') ?? 0;
int _i(String? v) => _d(v).round();

/// Repository yang menjalankan query MySQL untuk dashboard laporan.
class ReportRepository {
  ReportRepository._();
  static final ReportRepository instance = ReportRepository._();

  final Db _db = Db.instance;

  Future<List<KategoriOpsi>> daftarKategori() async {
    final List<Map<String, String?>> rows = await _db.select(qDaftarKategori);
    return rows
        .map((Map<String, String?> r) =>
            KategoriOpsi(_i(r['id_kategori']), r['nama_kategori'] ?? '-'))
        .toList();
  }

  Future<DashboardData> muat(ReportFilter f) async {
    final Map<String, dynamic> p = f.params;

    // Query dijalankan berurutan (satu koneksi MySQL).
    final Map<String, String?> kp = (await _db.select(qKpiPesanan, p)).first;
    final Map<String, String?> kk = (await _db.select(qKpiKeuangan, p)).first;
    final Map<String, String?> kr = (await _db.select(qKpiRating, p)).first;

    final String qBar = f.grupBar == GrupBar.kategori ? qBarPerKategori : qBarPerKru;
    final List<Map<String, String?>> bar = await _db.select(qBar, p);

    final String qTren = qTrenTransaksi.replaceAll('{FMT}', f.grupTren.formatSql);
    final List<Map<String, String?>> tren = await _db.select(qTren, p);

    final List<Map<String, String?>> pie = await _db.select(qPieStatus, p);
    final List<Map<String, String?>> terbaru = await _db.select(qPesananTerbaru, p);

    return DashboardData(
      totalPesanan: _i(kp['total_pesanan']),
      pesananAktif: _i(kp['pesanan_aktif']),
      pesananSelesai: _i(kp['pesanan_selesai']),
      pesananBatal: _i(kp['pesanan_batal']),
      jumlahTransaksi: _i(kk['jumlah_transaksi']),
      omzet: _d(kk['omzet']),
      komisi: _d(kk['komisi']),
      pendapatanKru: _d(kk['pendapatan_kru']),
      rataRating: _d(kr['rata_rating']),
      jumlahUlasan: _i(kr['jumlah_ulasan']),
      bar: bar
          .map((Map<String, String?> r) =>
              TitikBar(r['label'] ?? '-', _i(r['jumlah']), _d(r['omzet'])))
          .toList(),
      tren: tren
          .map((Map<String, String?> r) => TitikTren(
              r['periode'] ?? '', _i(r['jumlah']), _d(r['omzet']), _d(r['komisi'])))
          .toList(),
      pie: pie
          .map((Map<String, String?> r) => IrisanStatus(
              StatusPesanan.values.firstWhere(
                (StatusPesanan s) => s.dbValue == r['status'],
                orElse: () => StatusPesanan.menunggu,
              ),
              _i(r['jumlah'])))
          .toList(),
      terbaru: terbaru
          .map((Map<String, String?> r) => BarisPesanan(
                idPesanan: _i(r['id_pesanan']),
                pelanggan: r['pelanggan'] ?? '-',
                kategori: r['kategori'] ?? '-',
                kru: r['kru'] ?? '-',
                status: StatusPesanan.values.firstWhere(
                  (StatusPesanan s) => s.dbValue == r['status'],
                  orElse: () => StatusPesanan.menunggu,
                ),
                biaya: _d(r['biaya']),
                dibuat: DateTime.tryParse(r['dibuat'] ?? ''),
              ))
          .toList(),
    );
  }
}
