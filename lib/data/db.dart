import 'dart:io';

import 'package:mysql_client/mysql_client.dart';

/// Konfigurasi koneksi MySQL. Bisa diubah lewat environment variable:
///   SIGAP_DB_HOST, SIGAP_DB_PORT, SIGAP_DB_USER, SIGAP_DB_PASSWORD,
///   SIGAP_DB_NAME, SIGAP_DB_SECURE (isi "false" bila server tanpa TLS).
class DbConfig {
  static String _env(String k, String d) => Platform.environment[k] ?? d;

  static String get host => _env('SIGAP_DB_HOST', '127.0.0.1');
  static int get port => int.tryParse(_env('SIGAP_DB_PORT', '3306')) ?? 3306;
  static String get user => _env('SIGAP_DB_USER', 'root');
  static String get password => _env('SIGAP_DB_PASSWORD', '');
  static String get name => _env('SIGAP_DB_NAME', 'sigap_db');
  static bool get secure => _env('SIGAP_DB_SECURE', 'true').toLowerCase() != 'false';
}

/// Pembungkus koneksi MySQL (satu koneksi, dibuka saat pertama dipakai
/// dan dibuka ulang otomatis bila terputus).
class Db {
  Db._();
  static final Db instance = Db._();

  MySQLConnection? _conn;

  Future<MySQLConnection> _connection() async {
    final MySQLConnection? c = _conn;
    if (c != null && c.connected) return c;
    final MySQLConnection baru = await MySQLConnection.createConnection(
      host: DbConfig.host,
      port: DbConfig.port,
      userName: DbConfig.user,
      password: DbConfig.password,
      databaseName: DbConfig.name,
      secure: DbConfig.secure,
    );
    await baru.connect(timeoutMs: 8000);
    _conn = baru;
    return baru;
  }

  /// Menjalankan SELECT dan mengembalikan baris sebagai Map kolom -> teks.
  Future<List<Map<String, String?>>> select(
    String sql, [
    Map<String, dynamic>? params,
  ]) async {
    final MySQLConnection c = await _connection();
    final IResultSet res = await c.execute(sql, params);
    return res.rows.map((ResultSetRow r) => r.assoc()).toList();
  }

  Future<void> close() async {
    await _conn?.close();
    _conn = null;
  }
}
