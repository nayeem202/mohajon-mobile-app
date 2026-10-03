import '../../../core/models/sale.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/services/api_client.dart';

class DigitalInvoiceService {
  DigitalInvoiceService(this._db);
  final LocalDatabase _db;

  /// Requests a server-issued, signed invoice URL. No local or guessed URL is
  /// generated: if the backend cannot issue one, callers can safely fall back
  /// to the PDF/WhatsApp flow.
  Future<Uri?> createLink(Sale sale) async {
    final response = await ApiClient(_db).post(
      '/api/v1/invoices/${Uri.encodeComponent(sale.saleId)}/share-link',
      {'saleId': sale.saleId},
    );
    final raw = (response['url'] ?? response['shareUrl'] ?? '').toString().trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri;
  }
}
