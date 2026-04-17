import '../models/expense.dart';
import '../services/categorization_service.dart';
import '../services/sms_service.dart';

class NotificationParserService {
  const NotificationParserService();

  static final _smsService = SmsService();

  Future<List<Expense>> parse(String title, String body) async {
    final combined = '$title $body'.trim();
    if (!_smsService.isFinancialSms(combined)) return const [];

    const catService = CategorizationService();

    try {
      final result = await catService.parseSmsBatch([
        {
          'body': combined,
          'date': DateTime.now().toIso8601String(),
          'address': title,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      ]);
      return result.expenses;
    } catch (_) {
      return const [];
    }
  }
}
