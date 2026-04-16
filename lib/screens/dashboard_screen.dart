import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expenseListProvider);
    final syncStatus = ref.watch(syncProvider);
    final apiKey = ref.watch(apiKeyProvider);
    final modelName = ref.watch(geminiModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Manager'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
            ),
          ),
        ],
      ),
      body: expensesAsync.when(
        data: (expenses) => _buildContent(
          context,
          ref,
          expenses,
          syncStatus,
          apiKey,
          modelName,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: apiKey != null && apiKey.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: syncStatus == SyncStatus.idle
                  ? () => ref.read(syncProvider.notifier).sync()
                  : null,
              label: Text(_syncLabel(syncStatus)),
              icon: syncStatus == SyncStatus.idle
                  ? const Icon(Icons.sync_rounded)
                  : const SpinKitRotatingPlain(color: Colors.white, size: 20),
            )
          : null,
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Expense> expenses,
    SyncStatus syncStatus,
    String? apiKey,
    String modelName,
  ) {
    if (apiKey == null || apiKey.isEmpty) {
      return _EmptySetupState(modelName: modelName);
    }

    if (expenses.isEmpty) {
      return _NoExpensesState(
        syncStatus: syncStatus,
        modelName: modelName,
      );
    }

    final total = expenses.fold(0.0, (sum, item) => sum + item.amount);
    final currency = expenses.first.currency;
    final topCategory = _topCategory(expenses);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _SummaryHero(
              total: total,
              currency: currency,
              count: expenses.length,
              topCategory: topCategory,
              modelName: modelName,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
              child: _CategoryBreakdown(expenses: expenses),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Recent expenses',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: expenses.length,
            itemBuilder: (context, index) => _ExpenseTile(expense: expenses[index]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }

  String _topCategory(List<Expense> expenses) {
    final totals = <String, double>{};
    for (final expense in expenses) {
      totals.update(expense.category, (value) => value + expense.amount, ifAbsent: () => expense.amount);
    }
    if (totals.isEmpty) return 'Others';

    final topEntry = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return topEntry.key;
  }

  String _syncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.requestingPermissions:
        return 'Permissions...';
      case SyncStatus.fetchingSms:
        return 'Reading SMS...';
      case SyncStatus.analyzing:
        return 'Analyzing...';
      case SyncStatus.complete:
        return 'Done';
      case SyncStatus.error:
        return 'Retry sync';
      case SyncStatus.idle:
        return 'Sync SMS';
    }
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.total,
    required this.currency,
    required this.count,
    required this.topCategory,
    required this.modelName,
  });

  final double total;
  final String currency;
  final int count;
  final String topCategory;
  final String modelName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(icon: Icons.auto_awesome_rounded, label: modelName),
              _HeroChip(icon: Icons.receipt_long_outlined, label: '$count entries'),
              _HeroChip(icon: Icons.category_outlined, label: topCategory),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Total expenses',
            style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 8),
          Text(
            '$currency ${total.toStringAsFixed(2)}',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'SMS-driven ledger with AI categorization and local storage.',
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onPrimaryContainer.withValues(alpha: 0.82)),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryTotals = <String, double>{};
    for (final expense in expenses) {
      categoryTotals.update(expense.category, (value) => value + expense.amount, ifAbsent: () => expense.amount);
    }

    final sections = categoryTotals.entries.map((entry) {
      final color = _categoryColor(entry.key);
      return PieChartSectionData(
        value: entry.value,
        title: entry.value.toStringAsFixed(0),
        color: color,
        radius: 58,
        titleStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category breakdown',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 42,
                        sectionsSpace: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ListView(
                      children: categoryTotals.entries.map((entry) {
                        final color = _categoryColor(entry.key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(entry.key, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _categoryColor(expense.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.16),
            child: Icon(_categoryIcon(expense.category), color: color),
          ),
          title: Text(
            expense.merchant,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaPill(label: expense.category, icon: Icons.sell_outlined),
                _MetaPill(
                  label: DateFormat('MMM dd, yyyy').format(expense.date),
                  icon: Icons.event_outlined,
                ),
              ],
            ),
          ),
          trailing: Text(
            '${expense.currency} ${expense.amount.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _EmptySetupState extends StatelessWidget {
  const _EmptySetupState({required this.modelName});

  final String modelName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.key_off_outlined, size: 34, color: scheme.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  'Gemini API key missing',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Add your API key in settings. Current model target: $modelName',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoExpensesState extends StatelessWidget {
  const _NoExpensesState({
    required this.syncStatus,
    required this.modelName,
  });

  final SyncStatus syncStatus;
  final String modelName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: [
                scheme.secondaryContainer,
                scheme.primaryContainer,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 48, color: scheme.onSecondaryContainer),
              const SizedBox(height: 16),
              Text(
                'No expenses yet',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Run SMS sync to populate your dashboard. Active model: $modelName',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              Text(
                'Status: ${syncStatus.name}',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Colors.orange;
    case 'transport':
      return Colors.blue;
    case 'utilities':
      return Colors.green;
    case 'entertainment':
      return Colors.deepPurple;
    case 'shopping':
      return Colors.pink;
    case 'health':
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Icons.restaurant;
    case 'transport':
      return Icons.directions_car;
    case 'utilities':
      return Icons.lightbulb;
    case 'entertainment':
      return Icons.movie;
    case 'shopping':
      return Icons.shopping_bag;
    case 'health':
      return Icons.medical_services;
    default:
      return Icons.category;
  }
}
