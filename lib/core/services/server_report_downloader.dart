import 'dart:typed_data';

import '../offline/local_database.dart';
import 'api_client.dart';

/// Downloads report files rendered by the Haalkhata business service.
///
/// The mobile app only calls the API and saves the returned bytes; the
/// server (Jasper) owns the PDF/XLSX layout and data preparation.
/// Returns `null` when the server endpoint is unavailable (not deployed yet,
/// offline, or auth failed) so callers can fall back to local generation.
class ServerReportDownloader {
  ServerReportDownloader({LocalDatabase? db}) : _db = db ?? LocalDatabase();

  final LocalDatabase _db;

  static const _timeout = Duration(seconds: 60);

  /// Download `GET /api/v1/reports/{reportType}/export?format=...`.
  Future<Uint8List?> download({
    required String reportType,
    required String format,
    DateTime? from,
    DateTime? to,
    Map<String, String>? extraQuery,
  }) async {
    try {
      final api = ApiClient(_db);
      final query = <String, String>{
        'format': format,
        if (from != null) 'from': _isoDate(from),
        if (to != null) 'to': _isoDate(to),
        ...?extraQuery,
      };
      return await api.getBytes(
        '/api/v1/reports/$reportType/export',
        query: query,
        timeout: _timeout,
      );
    } on Exception {
      return null;
    }
  }

  static String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}