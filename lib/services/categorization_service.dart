import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/expense.dart';
import '../models/ai_log.dart';
import 'database_helper.dart';

const defaultGeminiModel = 'gemini-3.1-flash';
const defaultGeminiApiVersion = 'v1beta';

class CategorizationService {
  final String apiKey;
  final String modelName;
  late final GenerativeModel _model;

  CategorizationService(this.apiKey, {this.modelName = defaultGeminiModel}) {
    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      requestOptions: const RequestOptions(apiVersion: defaultGeminiApiVersion),
    );
  }

  Future<List<Expense>> parseSmsBatch(List<Map<String, dynamic>> smsList) async {
    if (smsList.isEmpty) return [];

    final smsDataString = smsList.asMap().entries.map((e) {
      return 'ID: ${e.key} | Date: ${e.value['date']} | Msg: ${e.value['body']}';
    }).join('\n');

    final prompt = '''
Analyze these SMS messages for financial transactions.
For each message, determine if it is a valid Expense or Income.
Return ONLY a JSON array of arrays in this exact format:
[[ID, "type", amount, "currency", "merchant", "category"], ...]

- ID: The numeric ID from the input.
- "type": "expense" or "income".
- "category": Food, Transport, Utilities, Entertainment, Shopping, Health, Others.

ONLY include valid financial transactions. If a message is not a transaction, skip its ID in the output.

SMS List:
$smsDataString
''';

    String responseText = '';
    String status = 'Success';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      responseText = response.text ?? '[]';
      
      final jsonMatch = RegExp(r'\[\s*\[.*\]\s*\]', dotAll: true).firstMatch(responseText);
      if (jsonMatch == null) {
        status = 'Error: No valid JSON array of arrays found';
        return [];
      }

      final List<dynamic> batchData = json.decode(jsonMatch.group(0)!);
      List<Expense> expenses = [];

      for (var entry in batchData) {
        try {
          final int id = entry[0];
          final String type = entry[1];
          final double amount = (entry[2] as num).toDouble();
          final String currency = entry[3];
          final String merchant = entry[4];
          final String category = entry[5];

          if (type == 'expense') {
            expenses.add(Expense(
              amount: amount,
              currency: currency,
              merchant: merchant,
              category: category,
              date: DateTime.parse(smsList[id]['date']),
              originalSms: smsList[id]['body'],
            ));
          }
        } catch (e) {
          // Skip malformed entries
        }
      }

      return expenses;
    } catch (e) {
      status = 'Error: $e';
      responseText = 'Exception occurred: $e';
      return [];
    } finally {
      await DatabaseHelper.instance.insertAiLog(AiLog(
        requestPrompt: '[Model: $modelName | API: $defaultGeminiApiVersion]\n${prompt.length > 1000 ? '${prompt.substring(0, 1000)}...' : prompt}',
        responseBody: responseText,
        timestamp: DateTime.now(),
        status: status,
      ));
    }
  }
}
