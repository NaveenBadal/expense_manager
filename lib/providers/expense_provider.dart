import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/expense.dart';
import '../models/ai_log.dart';
import '../services/database_helper.dart';
import '../services/gemini_model_catalog_service.dart';
import '../services/sms_service.dart';
import '../services/categorization_service.dart';

// Secure Storage for API Key and Settings
final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());
const geminiModelStorageKey = 'gemini_model';
final geminiModelCatalogServiceProvider = Provider((ref) => const GeminiModelCatalogService());

// API Key Provider
class ApiKeyNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setKey(String? key) => state = key;
}
final apiKeyProvider = NotifierProvider<ApiKeyNotifier, String?>(ApiKeyNotifier.new);

// Sync Lookback Days Provider
class SyncLookbackNotifier extends Notifier<int> {
  @override
  int build() => 1;
  void setDays(int days) => state = days;
}
final syncLookbackProvider = NotifierProvider<SyncLookbackNotifier, int>(SyncLookbackNotifier.new);

// Gemini Model Provider
class GeminiModelNotifier extends Notifier<String> {
  @override
  String build() => defaultGeminiModel;

  void setModel(String model) => state = model;
}
final geminiModelProvider = NotifierProvider<GeminiModelNotifier, String>(GeminiModelNotifier.new);
final availableGeminiModelsProvider = FutureProvider.family<List<GeminiModelCatalogItem>, String>((ref, apiKey) async {
  if (apiKey.trim().isEmpty) return const [];
  final service = ref.watch(geminiModelCatalogServiceProvider);
  return service.fetchModels(apiKey.trim());
});

// Theme Mode Provider
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void setThemeMode(ThemeMode mode) => state = mode;
}
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Initialize settings from storage
final settingsInitializer = FutureProvider<void>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  
  final apiKey = await storage.read(key: 'gemini_api_key');
  if (apiKey != null) {
    ref.read(apiKeyProvider.notifier).setKey(apiKey);
  }

  final lookback = await storage.read(key: 'sync_lookback_days');
  if (lookback != null) {
    ref.read(syncLookbackProvider.notifier).setDays(int.tryParse(lookback) ?? 1);
  }

  final geminiModel = await storage.read(key: geminiModelStorageKey);
  if (geminiModel != null && geminiModel.trim().isNotEmpty) {
    ref.read(geminiModelProvider.notifier).setModel(geminiModel.trim());
  }

  final theme = await storage.read(key: 'theme_mode');
  if (theme != null) {
    final mode = ThemeMode.values.firstWhere(
      (e) => e.toString() == theme,
      orElse: () => ThemeMode.system,
    );
    ref.read(themeModeProvider.notifier).setThemeMode(mode);
  }
});

// Database Provider
final databaseProvider = Provider((ref) => DatabaseHelper.instance);

// Expense List Notifier
class ExpenseListNotifier extends AsyncNotifier<List<Expense>> {
  @override
  Future<List<Expense>> build() async {
    final db = ref.watch(databaseProvider);
    return await db.getAllExpenses();
  }

  Future<void> refreshExpenses() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseProvider);
      return await db.getAllExpenses();
    });
  }

  Future<void> addExpense(Expense expense) async {
    final db = ref.read(databaseProvider);
    await db.insertExpense(expense);
    await refreshExpenses();
  }
}
final expenseListProvider = AsyncNotifierProvider<ExpenseListNotifier, List<Expense>>(ExpenseListNotifier.new);

// AI Logs Notifier
class AiLogNotifier extends AsyncNotifier<List<AiLog>> {
  @override
  Future<List<AiLog>> build() async {
    final db = ref.watch(databaseProvider);
    return await db.getAllAiLogs();
  }

  Future<void> refreshLogs() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseProvider);
      return await db.getAllAiLogs();
    });
  }

  Future<void> clearLogs() async {
    final db = ref.read(databaseProvider);
    await db.clearAiLogs();
    await refreshLogs();
  }
}
final aiLogProvider = AsyncNotifierProvider<AiLogNotifier, List<AiLog>>(AiLogNotifier.new);

// Sync Status Notifier
enum SyncStatus { idle, requestingPermissions, fetchingSms, analyzing, complete, error }

class SyncNotifier extends Notifier<SyncStatus> {
  final SmsService _smsService = SmsService();

  @override
  SyncStatus build() => SyncStatus.idle;

  Future<void> sync() async {
    final apiKey = ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      state = SyncStatus.error;
      return;
    }

    state = SyncStatus.requestingPermissions;
    final hasPermission = await _smsService.requestPermissions();
    if (!hasPermission) {
      state = SyncStatus.error;
      return;
    }

    state = SyncStatus.fetchingSms;
    final messages = await _smsService.getMessages();
    final db = ref.read(databaseProvider);
    final modelName = ref.read(geminiModelProvider);
    final catService = CategorizationService(apiKey, modelName: modelName);
    final lookbackDays = ref.read(syncLookbackProvider);

    state = SyncStatus.analyzing;

    final List<Map<String, dynamic>> unparsedSms = [];
    final Set<String> seenBodies = {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoffDate = today.subtract(Duration(days: lookbackDays));

    for (var msg in messages) {
      final msgBody = msg.body;
      final msgDate = msg.date ?? now;

      if (msgBody == null || msgDate.isBefore(cutoffDate)) continue;
      if (seenBodies.contains(msgBody)) continue;

      if (_smsService.isFinancialSms(msgBody)) {
        final exists = await db.smsExists(msgBody);
        if (!exists) {
          unparsedSms.add({
            'body': msgBody,
            'date': msgDate.toIso8601String(),
          });
          seenBodies.add(msgBody);
        }
      }
    }

    if (unparsedSms.isNotEmpty) {
      // Process in batches of 20
      const batchSize = 20;
      for (var i = 0; i < unparsedSms.length; i += batchSize) {
        final end = (i + batchSize < unparsedSms.length) ? i + batchSize : unparsedSms.length;
        final batch = unparsedSms.sublist(i, end);
        
        final newExpenses = await catService.parseSmsBatch(batch);
        for (var expense in newExpenses) {
          await ref.read(expenseListProvider.notifier).addExpense(expense);
        }
        await ref.read(aiLogProvider.notifier).refreshLogs();
      }
    }

    state = SyncStatus.complete;
    Future.delayed(const Duration(seconds: 2), () {
      if (state == SyncStatus.complete) state = SyncStatus.idle;
    });
  }
}
final syncProvider = NotifierProvider<SyncNotifier, SyncStatus>(SyncNotifier.new);
