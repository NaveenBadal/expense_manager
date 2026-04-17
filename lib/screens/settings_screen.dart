import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/expense_provider.dart';
import '../services/pdf_service.dart';
import '../services/bank_csv_importer.dart';
import '../services/drive_backup_service.dart';
import '../services/notification_service.dart';
import 'audit_screen.dart';
import 'logs_screen.dart';
import 'custom_categories_screen.dart';
import 'year_in_review_screen.dart';
import 'package:printing/printing.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late int _lookbackDays;
  late ThemeMode _themeMode;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _lookbackDays = ref.read(syncLookbackProvider);
    _themeMode = ref.read(themeModeProvider);
  }

  Future<void> _applyThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    ref.read(themeModeProvider.notifier).setThemeMode(mode);
    await ref.read(secureStorageProvider).write(
      key: 'theme_mode',
      value: mode.toString(),
    );
  }

  Future<void> _saveConfiguration() async {
    await ref.read(secureStorageProvider).write(
      key: 'sync_lookback_days',
      value: _lookbackDays.toString(),
    );
    ref.read(syncLookbackProvider.notifier).setDays(_lookbackDays);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _importBankCsv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    setState(() => _importing = true);

    try {
      final expenses = await BankCsvImporter.parse(file);
      if (expenses.isEmpty) throw Exception('No transactions found in CSV.');
      setState(() => _importing = false);
      if (!mounted) return;

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _CsvPreviewSheet(expenses: expenses),
      );

      if (confirmed == true && mounted) {
        setState(() => _importing = true);
        for (final e in expenses) {
          await ref.read(expenseListProvider.notifier).addExpense(e);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported ${expenses.length} transactions.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _generatePdfReport() async {
    final expenses = await ref.read(expenseListProvider.future);
    if (!mounted) return;
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export.')),
      );
      return;
    }
    final now = DateTime.now();
    final budgetProg = await ref.read(budgetProgressProvider.future);
    if (!mounted) return;
    final pdfFile = await PdfService.generateMonthlyStatement(
      year: now.year,
      month: now.month,
      expenses: expenses,
      budgetProgress: budgetProg,
    );
    await Printing.sharePdf(bytes: await pdfFile.readAsBytes(), filename: 'monthly_statement.pdf');
  }

  Future<void> _driveBackup() async {
    final drive = DriveBackupService.instance;
    final account = await drive.signIn();
    if (account == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In failed.')),
        );
      }
      return;
    }
    final result = await drive.backup();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result ? 'Backup successful.' : 'Backup failed.')),
      );
    }
  }

  Future<void> _driveRestore() async {
    final drive = DriveBackupService.instance;
    final account = await drive.signIn();
    if (!mounted) return;
    if (account == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Drive?'),
        content: const Text('Current local data will be overwritten.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await drive.restore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result ? 'Restore successful. Restart app.' : 'Restore failed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final privateMode = ref.watch(privateModeProvider);
    final dailyDigestEnabled = ref.watch(dailyDigestEnabledProvider);
    final notifParsingEnabled = ref.watch(notificationParsingEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _HeroSettingsCard(
            title: 'On-device SMS expense tracking',
            subtitle: 'DistilBERT model runs entirely on device — no API key or internet required.',
            icon: Icons.model_training_outlined,
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'AI Model',
            subtitle: 'Bundled DistilBERT (distilbert-base-uncased), fine-tuned on SMS data.',
            child: _BundledOnnxModelCard(scheme: scheme),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Security & Privacy',
            subtitle: 'Protect your financial data with biometrics and UI blurs.',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('App Lock'),
                  subtitle: const Text('Require Biometric/PIN on startup'),
                  value: appLockEnabled,
                  onChanged: (_) => ref.read(appLockEnabledProvider.notifier).toggle(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Private Mode'),
                  subtitle: const Text('Blur amounts on dashboard'),
                  value: privateMode,
                  onChanged: (_) => ref.read(privateModeProvider.notifier).toggle(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Data & Backup',
            subtitle: 'Manage categories, import history, and cloud sync.',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.category_rounded, color: scheme.primary),
                  ),
                  title: const Text('Custom Categories'),
                  subtitle: const Text('Create icons and colors for your needs'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CustomCategoriesScreen()),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: scheme.secondaryContainer,
                    child: Icon(Icons.upload_file_rounded, color: scheme.secondary),
                  ),
                  title: const Text('Import Bank CSV'),
                  subtitle: const Text('Support for HDFC, ICICI, Axis, SBI, Kotak'),
                  onTap: _importing ? null : _importBankCsv,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: scheme.tertiaryContainer,
                    child: Icon(Icons.picture_as_pdf_rounded, color: scheme.tertiary),
                  ),
                  title: const Text('Monthly PDF Statement'),
                  subtitle: const Text('Generate shareable summary report'),
                  onTap: _generatePdfReport,
                ),
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _driveBackup,
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: const Text('Backup'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _driveRestore,
                        icon: const Icon(Icons.cloud_download_rounded),
                        label: const Text('Restore'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Uses Google Drive to sync your encrypted database.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Insights & Notifications',
            subtitle: 'Automated summaries and yearly recaps.',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily Digest'),
                  subtitle: const Text('Summary notification at 8 PM'),
                  value: dailyDigestEnabled,
                  onChanged: (val) {
                    ref.read(dailyDigestEnabledProvider.notifier).toggle();
                    if (val) {
                      NotificationService.instance.scheduleDailyDigest();
                    } else {
                      NotificationService.instance.cancelDailyDigest();
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notification Parsing'),
                  subtitle: const Text('Parse bank push notifications for transactions'),
                  value: notifParsingEnabled,
                  onChanged: (_) =>
                      ref.read(notificationParsingEnabledProvider.notifier).toggle(),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Icon(Icons.auto_graph_rounded, color: scheme.onSurfaceVariant),
                  ),
                  title: const Text('Year in Review'),
                  subtitle: const Text('Shareable visual spending story'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YearInReviewScreen(year: DateTime.now().year),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Appearance',
            subtitle: 'Theme mode for the app.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme mode',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {_themeMode},
                  onSelectionChanged: (selection) => _applyThemeMode(selection.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Sync window',
            subtitle: 'Controls how many days of SMS history to scan.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [1, 2, 3, 7, 14, 30].map((value) {
                final selected = _lookbackDays == value;
                return ChoiceChip(
                  selected: selected,
                  label: Text('$value day${value == 1 ? '' : 's'}'),
                  avatar: Icon(
                    selected ? Icons.check_circle : Icons.calendar_month_outlined,
                    size: 18,
                  ),
                  onSelected: (_) => setState(() => _lookbackDays = value),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Developer',
            subtitle: 'Inspect prompts, responses, and parsed SMS history.',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: scheme.tertiaryContainer,
                    child: Icon(Icons.bug_report_outlined, color: scheme.tertiary),
                  ),
                  title: const Text('View AI request logs'),
                  subtitle: const Text('Raw prompts, model output, and error states'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogsScreen()),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: scheme.secondaryContainer,
                    child: Icon(Icons.sms_outlined, color: scheme.secondary),
                  ),
                  title: const Text('Parsed SMS audit'),
                  subtitle: const Text('All SMS sent to AI — with or without resulting transactions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuditScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _saveConfiguration,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save configuration'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSettingsCard extends StatelessWidget {
  const _HeroSettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.surface.withValues(alpha: 0.75),
            child: Icon(icon, color: scheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _BundledOnnxModelCard extends StatelessWidget {
  const _BundledOnnxModelCard({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.model_training_outlined, color: scheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'distilbert-base-uncased (SMS fine-tuned)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _OnnxInfoRow(label: 'Architecture', value: 'DistilBERT dual-head'),
          _OnnxInfoRow(label: 'Task 1', value: 'SMS classification (7 labels)'),
          _OnnxInfoRow(label: 'Task 2', value: 'Named entity recognition (8 tags)'),
          _OnnxInfoRow(label: 'Labels', value: 'expense · income · transfer · otp · promotional · balance_info · bill_reminder'),
          _OnnxInfoRow(label: 'Entities', value: 'AMOUNT · MERCHANT · DATE · ACCOUNT · BALANCE'),
          _OnnxInfoRow(label: 'Max tokens', value: '128 (WordPiece, do_lower_case)'),
          _OnnxInfoRow(label: 'Runtime', value: 'ONNX Runtime (on-device, no internet)'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 14, color: scheme.secondary),
                const SizedBox(width: 6),
                Text('Bundled with app — no download required', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnnxInfoRow extends StatelessWidget {
  const _OnnxInfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall,
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _CsvPreviewSheet extends StatelessWidget {
  const _CsvPreviewSheet({required this.expenses});

  final List expenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Preview Import',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${expenses.length} transactions',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Review before importing. All will be saved.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: expenses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = expenses[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.merchant as String? ?? '',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                e.category as String? ?? '',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${e.currency} ${(e.amount as double).toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Import All'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
