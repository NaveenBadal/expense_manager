import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../models/money_briefing.dart';
import '../providers/expense_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/category_utils.dart';
import '../utils/currency_utils.dart';
import '../widgets/expense_form_sheet.dart';
import '../widgets/development_update_ui.dart';
import '../widgets/ui/command_ui.dart';
import 'action_inbox_screen.dart';
import 'budget_screen.dart';
import 'plan_screen.dart';
import 'savings_goals_screen.dart';
import 'settings_screen.dart';
import 'subscriptions_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(expenseListProvider);
    final sync = ref.watch(syncProvider);
    final hidden = ref.watch(privateModeProvider);
    final briefing = ref.watch(moneyBriefingProvider);
    final currency = ref.watch(preferredCurrencyProvider);

    return CommandScaffold(
      eyebrow:
          'FINANCIAL INTELLIGENCE · ${DateFormat('d MMM').format(DateTime.now()).toUpperCase()}',
      title: 'Your money, thinking.',
      actions: [
        const ActionInboxButton(),
        IconButton(
          tooltip: hidden ? 'Reveal amounts' : 'Hide amounts',
          onPressed: () => ref.read(privateModeProvider.notifier).toggle(),
          icon: Icon(
            hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
      slivers: [
        const SliverToBoxAdapter(child: DevelopmentUpdateBanner()),
        if (sync.phase != SyncPhase.idle)
          SliverToBoxAdapter(child: _SyncLine(sync)),
        entries.when(
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SliverFillRemaining(
            child: StatePanel(
              icon: Icons.cloud_off_rounded,
              title: 'Your data took a detour',
              message: '$error',
              action: FilledButton(
                onPressed: () => ref.invalidate(expenseListProvider),
                child: const Text('Try again'),
              ),
            ),
          ),
          data: (items) => items.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: StatePanel(
                    icon: Icons.south_west_rounded,
                    title: 'Your money story starts here',
                    message:
                        'Sync bank messages or add the first transaction. Everything stays organized automatically.',
                    action: FilledButton.icon(
                      onPressed: () => ref.read(syncProvider.notifier).sync(),
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('Sync messages'),
                    ),
                  ),
                )
              : _TodayContent(
                  items: items,
                  hidden: hidden,
                  briefing: briefing,
                  currency: currency,
                  onOpen: (e) => _openExpense(context, ref, e),
                  onMove: (move) => _openMoneyMove(context, move),
                ),
        ),
      ],
    );
  }

  static void _openMoneyMove(BuildContext context, MoneyMoveType move) {
    final page = switch (move) {
      MoneyMoveType.protectBills => const SubscriptionsScreen(),
      MoneyMoveType.fundGoal => const SavingsGoalsScreen(),
      MoneyMoveType.slowCategory => const BudgetScreen(),
      MoneyMoveType.reviewPlan => const PlanScreen(),
      MoneyMoveType.stayCourse => const PlanScreen(),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  static Future<void> _openExpense(
    BuildContext context,
    WidgetRef ref, [
    Expense? expense,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ExpenseFormSheet(
        initialExpense: expense,
        onSave: (value) async {
          if (expense == null) {
            await ref.read(expenseListProvider.notifier).addExpense(value);
          } else {
            await ref.read(expenseListProvider.notifier).updateExpense(value);
          }
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        onDelete: expense?.id == null
            ? null
            : () async {
                await ref
                    .read(expenseListProvider.notifier)
                    .deleteExpense(expense!.id!);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
      ),
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({
    required this.items,
    required this.hidden,
    required this.briefing,
    required this.currency,
    required this.onOpen,
    required this.onMove,
  });
  final List<Expense> items;
  final bool hidden;
  final MoneyBriefing? briefing;
  final String currency;
  final ValueChanged<Expense> onOpen;
  final ValueChanged<MoneyMoveType> onMove;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = items
        .where(
          (e) =>
              e.currency == currency &&
              e.date.year == now.year &&
              e.date.month == now.month,
        )
        .toList();
    final today = items.where((e) => DateUtils.isSameDay(e.date, now)).toList();
    final spent = month
        .where((e) => !e.isIncome)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final income = month
        .where((e) => e.isIncome)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final todaySpent = today
        .where((e) => !e.isIncome)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day + 1;
    final available = briefing?.safeToSpend ?? (income - spent);
    final dailyRoom =
        briefing?.dailySafeToSpend ??
        (available > 0 ? available / daysLeft : 0.0);
    String money(double value) =>
        hidden ? maskAmount(currency) : formatAmount(value, currency);

    final latest = items.take(3).toList();
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _NeuralCashField(
              available: money(available),
              spent: money(spent),
              dailyRoom: money(dailyRoom),
              hidden: hidden,
              protection: briefing == null
                  ? 'I am learning your financial rhythm.'
                  : _protectionLine(briefing!, currency, hidden),
            ),
          ),
        ),
        if (briefing != null) ...[
          const SliverToBoxAdapter(child: SectionLabel('AI intervention')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _MoneyMoveCard(
                briefing: briefing!,
                currency: currency,
                hidden: hidden,
                onTap: () => onMove(briefing!.nextMove.type),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SectionLabel('Live intelligence')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 112,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                SizedBox(
                  width: 170,
                  child: MetricTile(
                    label: 'NOW PULSE',
                    value: money(todaySpent),
                    icon: Icons.today_rounded,
                    caption: '${today.length} events understood',
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 170,
                  child: MetricTile(
                    label: 'INFLOW SIGNAL',
                    value: money(income),
                    icon: Icons.south_west_rounded,
                    color: context.finance.income,
                    caption: 'This month',
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 170,
                  child: MetricTile(
                    label: 'RUNWAY',
                    value: '$daysLeft',
                    icon: Icons.hourglass_bottom_rounded,
                    caption: 'In this cycle',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionLabel('Recently understood')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: latest.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 54,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            itemBuilder: (context, index) => _LedgerRow(
              expense: latest[index],
              hidden: hidden,
              onTap: () => onOpen(latest[index]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 16,
                  color: context.finance.income,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Duplicate shield active · every bank signal is cross-checked before it changes your story.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _protectionLine(MoneyBriefing value, String currency, bool hidden) {
    final protected =
        value.commitmentsTotal + value.goalReserve + value.safetyBuffer;
    if (protected <= 0) return 'Nothing else needs protecting this month.';
    final amount = hidden
        ? maskAmount(currency)
        : formatAmount(protected, currency);
    final parts = <String>[];
    if (value.upcomingCommitments.isNotEmpty) {
      parts.add(
        '${value.upcomingCommitments.length} upcoming commitment${value.upcomingCommitments.length == 1 ? '' : 's'}',
      );
    }
    if (value.goalReserve > 0) parts.add('your goals');
    if (value.safetyBuffer > 0) parts.add('your safety buffer');
    return '$amount protected for ${parts.join(' and ')}.';
  }
}

class _NeuralCashField extends StatefulWidget {
  const _NeuralCashField({
    required this.available,
    required this.spent,
    required this.dailyRoom,
    required this.hidden,
    required this.protection,
  });
  final String available;
  final String spent;
  final String dailyRoom;
  final bool hidden;
  final String protection;

  @override
  State<_NeuralCashField> createState() => _NeuralCashFieldState();
}

class _NeuralCashFieldState extends State<_NeuralCashField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const acid = Color(0xFFC7FF4A);
    return Container(
      height: 370,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) =>
                  CustomPaint(painter: _IntelligenceFieldPainter(_pulse.value)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: acid,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: acid, blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'FLOW AI · LIVE',
                      style: TextStyle(
                        color: acid,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'You can move freely with',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: AppMotion.medium,
                  child: Text(
                    widget.available,
                    key: ValueKey(widget.hidden),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -2.5,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  widget.protection,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FieldMetric(
                          label: 'OBSERVED',
                          value: widget.spent,
                        ),
                      ),
                      Container(width: 1, height: 28, color: Colors.white12),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FieldMetric(
                          label: 'TODAY’S RANGE',
                          value: widget.dailyRoom,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldMetric extends StatelessWidget {
  const _FieldMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.fade,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _IntelligenceFieldPainter extends CustomPainter {
  const _IntelligenceFieldPainter(this.phase);
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF8CFFED).withValues(alpha: .22),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * (.66 + .05 * phase),
                size.height * .28,
              ),
              radius: size.width * .55,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
    final line = Paint()
      ..color = const Color(0xFFC7FF4A).withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(size.width * .78, size.height * .22),
        28.0 + i * 24 + phase * 8,
        line,
      );
    }
    final dot = Paint()..color = const Color(0xFFC7FF4A).withValues(alpha: .8);
    canvas.drawCircle(Offset(size.width * .78, size.height * .22), 3, dot);
  }

  @override
  bool shouldRepaint(covariant _IntelligenceFieldPainter old) =>
      old.phase != phase;
}

class _MoneyMoveCard extends StatelessWidget {
  const _MoneyMoveCard({
    required this.briefing,
    required this.currency,
    required this.hidden,
    required this.onTap,
  });

  final MoneyBriefing briefing;
  final String currency;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (briefing.nextMove.type) {
      MoneyMoveType.protectBills => Icons.event_available_rounded,
      MoneyMoveType.fundGoal => Icons.savings_rounded,
      MoneyMoveType.slowCategory => Icons.speed_rounded,
      MoneyMoveType.reviewPlan => Icons.account_balance_wallet_rounded,
      MoneyMoveType.stayCourse => Icons.check_rounded,
    };
    final forecast = hidden
        ? maskAmount(currency)
        : formatAmount(briefing.projectedMonthSpend, currency);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.all(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.all(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: AppRadius.all(15),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      briefing.nextMove.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      briefing.nextMove.body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'MONTH-END FORECAST  ·  $forecast',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.expense,
    required this.hidden,
    required this.onTap,
  });
  final Expense expense;
  final bool hidden;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = expense.isIncome
        ? context.finance.income
        : categoryColor(expense.category);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.all(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.all(14),
              ),
              child: Icon(
                expense.isIncome
                    ? Icons.south_west_rounded
                    : categoryIcon(expense.category),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${expense.category} · ${DateFormat('h:mm a').format(expense.date)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              hidden
                  ? maskAmount(expense.currency)
                  : '${expense.isIncome ? '+' : '−'}${formatAmount(expense.amount, expense.currency)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: expense.isIncome ? context.finance.income : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncLine extends StatelessWidget {
  const _SyncLine(this.sync);
  final SyncState sync;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: AppRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sync.phase == SyncPhase.error
                    ? Icons.error_outline_rounded
                    : sync.phase == SyncPhase.complete
                    ? Icons.check_circle_outline_rounded
                    : Icons.bolt_rounded,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sync.errorMessage ?? sync.detail ?? 'Preparing sync',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (sync.total > 0)
                Text(
                  '${(sync.current / sync.total * 100).clamp(0, 100).round()}%',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          if (sync.isActive && sync.total > 0) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: AppRadius.all(99),
              child: LinearProgressIndicator(
                value: (sync.current / sync.total).clamp(0, 1),
                minHeight: 5,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

extension on SyncState {
  bool get isActive =>
      phase == SyncPhase.requestingPermissions ||
      phase == SyncPhase.fetchingSms ||
      phase == SyncPhase.analyzing;
}
