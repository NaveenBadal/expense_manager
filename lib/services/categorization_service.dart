import 'dart:async';

import '../models/expense.dart';
import '../models/ai_log.dart';
import 'database_helper.dart';
import 'merchant_normalizer.dart';
import 'onnx_sms_service.dart';

/// Result of a batch parse: extracted expenses + per-body skip reasons.
class SmsBatchResult {
  const SmsBatchResult({
    required this.expenses,
    required this.skipReasons,
  });

  final List<Expense> expenses;

  /// Maps SMS body text → reason string (e.g. "otp", "promotional",
  /// "balance_alert", "not_financial", "no_response", "parse_error").
  /// Only populated for messages that did NOT produce an expense.
  final Map<String, String> skipReasons;
}

class CategorizationService {
  const CategorizationService();

  Future<SmsBatchResult> parseSmsBatch(List<Map<String, dynamic>> smsList) async {
    if (smsList.isEmpty) {
      return const SmsBatchResult(expenses: [], skipReasons: {});
    }
    return _parseWithOnnxProvider(smsList);
  }

  Future<SmsBatchResult> _parseWithOnnxProvider(
    List<Map<String, dynamic>> smsList,
  ) async {
    final onnx = OnnxSmsService.instance;
    final expenses = <Expense>[];
    final skipReasons = <String, String>{};
    int expenseCount = 0;
    int skipCount = 0;
    String status = 'Success';

    try {
      await onnx.ensureInitialized();
    } catch (e) {
      status = 'Error: ONNX init failed: $e';
      final reasons = {for (final s in smsList) s['body'] as String: 'parse_error'};
      await _logOnnxResult(
        batchSize: smsList.length,
        expenses: 0,
        skipped: smsList.length,
        status: status,
      );
      return SmsBatchResult(expenses: [], skipReasons: reasons);
    }

    for (final sms in smsList) {
      final body = sms['body'] as String;
      try {
        final result = await onnx.infer(body);
        final isFinancial = result.label == 'expense' ||
            result.label == 'income' ||
            result.label == 'transfer';

        if (!isFinancial) {
          skipReasons[body] = result.label;
          skipCount++;
          continue;
        }

        final amount = OnnxSmsService.extractAmount(body);
        if (amount == null || amount <= 0) {
          skipReasons[body] = 'zero_amount';
          skipCount++;
          continue;
        }

        final merchant = result.merchant ?? '';
        final normalized = MerchantNormalizer.normalize(merchant);

        String category = OnnxSmsService.inferCategory(merchant);
        try {
          final learnedMap = await DatabaseHelper.instance.getMerchantCategoryMap();
          final learned = learnedMap[normalized.toLowerCase().trim()];
          if (learned != null && learned.isNotEmpty) category = learned;
        } catch (_) {}

        expenses.add(Expense(
          amount: amount,
          currency: 'INR',
          merchant: merchant,
          normalizedMerchant: normalized != merchant ? normalized : null,
          category: category,
          date: DateTime.parse(sms['date'] as String),
          originalSms: body,
          type: result.label == 'income' ? 'income' : 'expense',
        ));
        expenseCount++;
      } catch (_) {
        skipReasons[body] = 'parse_error';
        skipCount++;
      }
    }

    await _logOnnxResult(
      batchSize: smsList.length,
      expenses: expenseCount,
      skipped: skipCount,
      status: status,
    );
    return SmsBatchResult(expenses: expenses, skipReasons: skipReasons);
  }

  Future<void> _logOnnxResult({
    required int batchSize,
    required int expenses,
    required int skipped,
    required String status,
  }) async {
    try {
      await DatabaseHelper.instance.insertAiLog(AiLog(
        requestPrompt:
            '[Provider: DistilBERT | Model: bundled_distilbert]\n$batchSize SMS messages processed',
        responseBody: 'Extracted $expenses expenses, skipped $skipped',
        timestamp: DateTime.now(),
        status: status,
      ));
    } catch (_) {}
  }
}
