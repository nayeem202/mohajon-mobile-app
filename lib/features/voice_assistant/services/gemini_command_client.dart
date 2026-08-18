import '../../../core/offline/local_database.dart';
import '../../../core/services/api_client.dart';
import '../models/voice_command.dart';

class GeminiCommandClient {
  GeminiCommandClient(this._db);

  final LocalDatabase _db;

  Future<VoiceCommand> interpret(String transcript) async {
    final response = await ApiClient(_db).post('/api/v1/assistant/command', {
      'text': transcript,
    });
    final action = response['action']?.toString();
    final type = switch (action) {
      'open_home' => VoiceCommandType.openHome,
      'open_sales' => VoiceCommandType.openSales,
      'open_products' => VoiceCommandType.openProducts,
      'open_customers' => VoiceCommandType.openCustomers,
      'open_more' => VoiceCommandType.openMore,
      'open_notifications' => VoiceCommandType.openNotifications,
      'open_investors' => VoiceCommandType.openInvestors,
      'open_expenses' => VoiceCommandType.openExpenses,
      _ => VoiceCommandType.unknown,
    };
    return VoiceCommand(type: type, transcript: transcript);
  }
}
