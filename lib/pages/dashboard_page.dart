import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/report_repository.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Dashboard laporan: semua angka & grafik diambil dari MySQL lewat query
/// (lihat lib/data/report_queries.dart). Filter: periode, kategori, grouping.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onLihatSemua});

  final VoidCallback onLihatSemua;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ReportRepository _repo = ReportRepository.instance;
  final ReportFilter _filter = ReportFilter();

  late Future<DashboardData> _future;
  List<KategoriOpsi> _kategori = <KategoriOpsi>[];
  DateTime _diperbarui = DateTime.now();

  @override
  void initState() {
    super.initState();
    _future = _ambil();
    _muatKategori();
  }

  Future<DashboardData> _ambil() => _repo.muat(_filter);

  void _muat() {
    setState(() {
      _future = _ambil();
      _diperbarui = DateTime.now();
    });
  }

  Future<void> _muatKategori() async {
    try {
      final List<KategoriOpsi> k = await _repo.daftarKategori();
      if (mounted) setState(() => _kategori = k);
    } catch (_) {
      // Kesalahan koneksi ditampilkan oleh FutureBuilder utama.
    }
  }

  Future<void> _pilihRentang() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _filter.dari.year < 2010 ? now.subtract(const Duration(days: 29)) : _filter.dari,
        end: now,
      ),
      helpText: 'Pilih rentang tanggal laporan',
      saveText: 'Terapkan',
    );
    if (r == null) return;
    _filter
      ..periode = Periode.kustom
      ..dariKustom = r.start
      ..sampaiKustom = r.end;
    _muat();
  }

  String _ringkasanFilter() {
    final String kat = _filter.idKategori == null
        ? 'semua kategori'
        : _kategori
            .firstWhere((KategoriOpsi k) => k.id == _filter.idKategori,
                orElse: () => const KategoriOpsi(0, 'kategori terpilih'))
            .nama;
    if (_filter.periode == Periode.semua) return 'Seluruh periode · $kat';
    return '${_tgl(_filter.dari)} - ${_tgl(_filter.periode == Periode.kustom ? _filter.sampai : DateTime.now())} · $kat';
  }

  static String _tgl(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PageHeader(
          title: 'Dashboard Laporan',
          subtitle: 'Data dari database MySQL · ${_ringkasanFilter()}',
        ),
        const SizedBox(height: 16),
        _filterBar(),
        const SizedBox(height: 16),
        FutureBuilder<DashboardData>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<DashboardData> snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const CardBox(
                child: SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (snap.hasError) return _errorCard(snap.error);
            return _isi(snap.data!);
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- filter

  Widget _filterBar() {
    return CardBox(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const Icon(Icons.filter_alt_outlined, size: 18, color: AppColors.muted),
          // Periode
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (final Periode p in <Periode>[
                Periode.tujuhHari,
                Periode.tigaPuluhHari,
                Periode.sembilanPuluhHari,
                Periode.semua,
              ])
                ChoiceChip(
                  label: Text(p.label, style: const TextStyle(fontSize: 12)),
                  selected: _filter.periode == p,
                  selectedColor: AppColors.green.withAlpha(40),
                  onSelected: (_) {
                    _filter.periode = p;
                    _muat();
                  },
                ),
              ChoiceChip(
                avatar: const Icon(Icons.date_range, size: 15),
                label: Text(
                  _filter.periode == Periode.kustom
                      ? '${_tgl(_filter.dari)} - ${_tgl(_filter.sampai)}'
                      : 'Pilih tanggal',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: _filter.periode == Periode.kustom,
                selectedColor: AppColors.green.withAlpha(40),
                onSelected: (_) => _pilihRentang(),
              ),
            ],
          ),
          // Kategori
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _filter.idKategori,
                isDense: true,
                style: const TextStyle(fontSize: 12, color: AppColors.text),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(value: null, child: Text('Semua kategori')),
                  for (final KategoriOpsi k in _kategori)
                    DropdownMenuItem<int?>(value: k.id, child: Text(k.nama)),
                ],
                onChanged: (int? v) {
                  _filter.idKategori = v;
                  _muat();
                },
              ),
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang data dari database',
            onPressed: _muat,
            icon: const Icon(Icons.refresh, size: 20, color: AppColors.green),
          ),
          Text(
            'Diperbarui ${_jam(_diperbarui)}',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  static String _jam(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

  Widget _errorCard(Object? e) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              Icon(Icons.error_outline, color: AppColors.red),
              SizedBox(width: 8),
              Text('Tidak dapat mengambil data dari MySQL',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Server: ${DbConfig.host}:${DbConfig.port} · database: ${DbConfig.name} · user: ${DbConfig.user}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text('$e',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.red)),
          const SizedBox(height: 10),
          const Text(
            'Pastikan MySQL berjalan, sql/01_schema.sql dan sql/02_seed.sql sudah diimpor, '
            'lalu atur SIGAP_DB_HOST / SIGAP_DB_USER / SIGAP_DB_PASSWORD / SIGAP_DB_NAME bila perlu. '
            'Bila server tanpa TLS, set SIGAP_DB_SECURE=false.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            child: PrimaryButton(label: 'Coba lagi', icon: Icons.refresh, onPressed: _muat),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ isi

  Widget _isi(DashboardData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: StatCard(
                color: AppColors.green,
                icon: Icons.inventory_2_outlined,
                label: 'Total Pesanan',
                value: '${d.totalPesanan}',
                caption: '${d.pesananAktif} aktif · ${d.pesananSelesai} selesai · ${d.pesananBatal} batal',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                color: AppColors.blue,
                icon: Icons.payments_outlined,
                label: 'Total Transaksi',
                value: rupiah(d.omzet),
                caption: '${d.jumlahTransaksi} transaksi selesai',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                color: AppColors.red,
                icon: Icons.account_balance_wallet_outlined,
                label: 'Komisi Admin 8%',
                value: rupiah(d.komisi),
                caption: 'Pendapatan kru ${rupiah(d.pendapatanKru)}',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                color: AppColors.purple,
                icon: Icons.star_outline,
                label: 'Rating Layanan',
                value: d.jumlahUlasan == 0 ? '-' : '${d.rataRating.toStringAsFixed(1)} / 5',
                caption: '${d.jumlahUlasan} ulasan',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 3, child: _barCard(d)),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _pieCard(d)),
          ],
        ),
        const SizedBox(height: 16),
        _lineCard(d),
        const SizedBox(height: 16),
        _tabelCard(d),
      ],
    );
  }

  Widget _judul(String t, String sub, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  static const TextStyle _axisStyle = TextStyle(fontSize: 10, color: AppColors.muted);
  static const AxisTitles _tanpaJudul = AxisTitles(sideTitles: SideTitles(showTitles: false));

  static String _singkat(String s, int maks) =>
      s.length <= maks ? s : '${s.substring(0, maks - 1)}…';

  static String _ringkasRp(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}jt';
    if (v >= 1000) return '${(v / 1000).round()}rb';
    return v.round().toString();
  }

  // ------------------------------------------------------------ bar chart

  Widget _barCard(DashboardData d) {
    final bool perKategori = _filter.grupBar == GrupBar.kategori;
    final List<TitikBar> data = d.bar;
    final int maks = data.isEmpty
        ? 0
        : data.map((TitikBar b) => b.jumlah).reduce((int a, int b) => a > b ? a : b);
    final double maxY = (maks < 4 ? 4 : maks * 1.2).toDouble();
    final double interval = maxY <= 8 ? 1 : (maxY / 5).ceilToDouble();

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _judul(
            'Bar Chart · Pesanan ${perKategori ? 'per Kategori' : 'per Kru'}',
            'Jumlah pesanan pada periode terpilih (hover untuk omzet pesanan selesai)',
            trailing: SizedBox(
              width: 190,
              child: Segmented(
                labels: GrupBar.values.map((GrupBar g) => g.label).toList(),
                index: _filter.grupBar.index,
                onChanged: (int i) {
                  _filter.grupBar = GrupBar.values[i];
                  _muat();
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: data.isEmpty || maks == 0
                ? const EmptyRow('Tidak ada pesanan pada filter ini.')
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (double v) =>
                            const FlLine(color: AppColors.border, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: _tanpaJudul,
                        rightTitles: _tanpaJudul,
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: interval,
                            getTitlesWidget: (double v, TitleMeta m) =>
                                Text(v.toInt().toString(), style: _axisStyle),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            getTitlesWidget: (double v, TitleMeta m) {
                              final int i = v.toInt();
                              if (i < 0 || i >= data.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 70,
                                  child: Text(
                                    _singkat(data[i].label, 20),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: _axisStyle,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (BarChartGroupData g, int gi, BarChartRodData rod, int ri) {
                            final TitikBar t = data[gi];
                            return BarTooltipItem(
                              '${t.label}\n${t.jumlah} pesanan\nOmzet selesai ${rupiah(t.omzet)}',
                              const TextStyle(color: Colors.white, fontSize: 11),
                            );
                          },
                        ),
                      ),
                      barGroups: <BarChartGroupData>[
                        for (int i = 0; i < data.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: <BarChartRodData>[
                              BarChartRodData(
                                toY: data[i].jumlah.toDouble(),
                                width: 22,
                                color: AppColors.palette[i % AppColors.palette.length],
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ pie chart

  Widget _pieCard(DashboardData d) {
    final int total = d.pie.fold<int>(0, (int a, IrisanStatus s) => a + s.jumlah);
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _judul('Pie Chart · Status Pesanan', 'Komposisi status pada periode terpilih'),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: total == 0
                ? const EmptyRow('Tidak ada pesanan pada filter ini.')
                : Column(
                    children: <Widget>[
                      SizedBox(
                        height: 170,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 38,
                            sections: <PieChartSectionData>[
                              for (final IrisanStatus s in d.pie)
                                PieChartSectionData(
                                  value: s.jumlah.toDouble(),
                                  color: statusColor(s.status),
                                  radius: 50,
                                  title: (s.jumlah * 100 / total) >= 6
                                      ? '${(s.jumlah * 100 / total).round()}%'
                                      : '',
                                  titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: <Widget>[
                          for (final IrisanStatus s in d.pie)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: statusColor(s.status), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                Text('${s.status.label} (${s.jumlah})',
                                    style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- line chart

  String _labelPeriode(String p) {
    // harian: 2026-11-26 -> 26/11 ; mingguan: 2026-W47 -> W47 ; bulanan: 2026-11 -> Nov 2026
    switch (_filter.grupTren) {
      case GrupTren.harian:
        final List<String> a = p.split('-');
        return a.length == 3 ? '${a[2]}/${a[1]}' : p;
      case GrupTren.mingguan:
        final int i = p.indexOf('-');
        return i >= 0 ? p.substring(i + 1) : p;
      case GrupTren.bulanan:
        const List<String> bln = <String>[
          'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
        ];
        final List<String> a = p.split('-');
        final int m = a.length == 2 ? (int.tryParse(a[1]) ?? 1) : 1;
        return a.length == 2 ? '${bln[(m - 1).clamp(0, 11).toInt()]} ${a[0]}' : p;
    }
  }

  Widget _lineCard(DashboardData d) {
    final List<TitikTren> data = d.tren;
    final double maks = data.isEmpty
        ? 0
        : data.map((TitikTren t) => t.omzet).reduce((double a, double b) => a > b ? a : b);
    final double maxY = maks <= 0 ? 10000 : maks * 1.2;
    final double intervalY = maxY / 4;
    final double intervalX = data.length > 12 ? (data.length / 8).ceilToDouble() : 1;

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _judul(
            'Line Chart · Tren Transaksi ${_filter.grupTren.label}',
            'Total transaksi selesai per periode (hover untuk jumlah transaksi & komisi)',
            trailing: SizedBox(
              width: 260,
              child: Segmented(
                labels: GrupTren.values.map((GrupTren g) => g.label).toList(),
                index: _filter.grupTren.index,
                onChanged: (int i) {
                  _filter.grupTren = GrupTren.values[i];
                  _muat();
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: data.isEmpty
                ? const EmptyRow('Belum ada transaksi selesai pada filter ini.')
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: intervalY,
                        getDrawingHorizontalLine: (double v) =>
                            const FlLine(color: AppColors.border, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: _tanpaJudul,
                        rightTitles: _tanpaJudul,
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval: intervalY,
                            getTitlesWidget: (double v, TitleMeta m) =>
                                Text(_ringkasRp(v), style: _axisStyle),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: intervalX,
                            getTitlesWidget: (double v, TitleMeta m) {
                              final int i = v.toInt();
                              if (i < 0 || i >= data.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(_labelPeriode(data[i].periode), style: _axisStyle),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> spots) {
                            return spots.map((LineBarSpot s) {
                              final TitikTren t = data[s.x.toInt()];
                              return LineTooltipItem(
                                '${_labelPeriode(t.periode)}\n${rupiah(t.omzet)}\n'
                                '${t.jumlah} transaksi · komisi ${rupiah(t.komisi)}',
                                const TextStyle(color: Colors.white, fontSize: 11),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: <LineChartBarData>[
                        LineChartBarData(
                          spots: <FlSpot>[
                            for (int i = 0; i < data.length; i++)
                              FlSpot(i.toDouble(), data[i].omzet),
                          ],
                          isCurved: true,
                          curveSmoothness: 0.2,
                          color: AppColors.green,
                          barWidth: 3,
                          dotData: FlDotData(show: data.length <= 40),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.green.withAlpha(34),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- tabel

  Widget _tabelCard(DashboardData d) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text('Pesanan Terbaru (sesuai filter)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              TextButton(
                onPressed: widget.onLihatSemua,
                child: const Text('Lihat semua',
                    style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const TableHead(cols: <MapEntry<String, int>>[
            MapEntry<String, int>('ID', 1),
            MapEntry<String, int>('Pelanggan', 2),
            MapEntry<String, int>('Kategori', 2),
            MapEntry<String, int>('Kru', 2),
            MapEntry<String, int>('Dibuat', 2),
            MapEntry<String, int>('Status', 2),
            MapEntry<String, int>('Biaya', 1),
          ]),
          if (d.terbaru.isEmpty) const EmptyRow('Belum ada pesanan pada filter ini.'),
          for (final BarisPesanan p in d.terbaru)
            TableRowBox(children: <Widget>[
              Expanded(
                  flex: 1,
                  child: cellText(kodePsn(p.idPesanan), bold: true, color: AppColors.green)),
              Expanded(flex: 2, child: cellText(p.pelanggan, bold: true)),
              Expanded(flex: 2, child: cellText(p.kategori)),
              Expanded(flex: 2, child: cellText(p.kru)),
              Expanded(flex: 2, child: cellText(p.dibuat == null ? '-' : tglWaktu(p.dibuat!))),
              Expanded(flex: 2, child: leftAlign(Pill(p.status.label, statusColor(p.status)))),
              Expanded(flex: 1, child: cellText(rupiah(p.biaya), bold: true)),
            ]),
        ],
      ),
    );
  }
}
