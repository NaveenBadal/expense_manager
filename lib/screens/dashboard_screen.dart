import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../models/money_briefing.dart';
import '../providers/expense_provider.dart';
import '../providers/development_update_provider.dart';
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
    final async = ref.watch(expenseListProvider);
    final hidden = ref.watch(privateModeProvider);
    final briefing = ref.watch(moneyBriefingProvider);
    final currency = ref.watch(preferredCurrencyProvider);
    final sync = ref.watch(syncProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StatePanel(
            icon: Icons.cloud_off_rounded,
            title: 'The financial world is unavailable',
            message: '$error',
            action: FilledButton(
              onPressed: () => ref.invalidate(expenseListProvider),
              child: const Text('Reconstruct it'),
            ),
          ),
          data: (items) => items.isEmpty
              ? _UnbornWorld(
                  onSense: () => ref.read(syncProvider.notifier).sync(),
                )
              : _MoneyWorld(
                  items: items,
                  briefing: briefing,
                  currency: currency,
                  hidden: hidden,
                  sync: sync,
                  onPrivacy: () =>
                      ref.read(privateModeProvider.notifier).toggle(),
                  onSettings: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  onInbox: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ActionInboxScreen(),
                    ),
                  ),
                  onOpen: (expense) => _openExpense(context, ref, expense),
                  onMove: (move) => _openMoneyMove(context, move),
                ),
        ),
      ),
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
    WidgetRef ref,
    Expense expense,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ExpenseFormSheet(
        initialExpense: expense,
        onSave: (value) async {
          await ref.read(expenseListProvider.notifier).updateExpense(value);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        onDelete: expense.id == null
            ? null
            : () async {
                await ref
                    .read(expenseListProvider.notifier)
                    .deleteExpense(expense.id!);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
      ),
    );
  }
}

class _MoneyWorld extends StatefulWidget {
  const _MoneyWorld({
    required this.items,
    required this.briefing,
    required this.currency,
    required this.hidden,
    required this.sync,
    required this.onPrivacy,
    required this.onSettings,
    required this.onInbox,
    required this.onOpen,
    required this.onMove,
  });
  final List<Expense> items;
  final MoneyBriefing? briefing;
  final String currency;
  final bool hidden;
  final SyncState sync;
  final VoidCallback onPrivacy, onSettings, onInbox;
  final ValueChanged<Expense> onOpen;
  final ValueChanged<MoneyMoveType> onMove;

  @override
  State<_MoneyWorld> createState() => _MoneyWorldState();
}

class _MoneyWorldState extends State<_MoneyWorld>
    with SingleTickerProviderStateMixin {
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = widget.items
        .where(
          (e) =>
              e.currency == widget.currency &&
              e.date.year == now.year &&
              e.date.month == now.month,
        )
        .toList();
    final spent = month
        .where((e) => !e.isIncome)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final income = month
        .where((e) => e.isIncome)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final available = widget.briefing?.safeToSpend ?? (income - spent);
    final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day + 1;
    final latest = widget.items.take(3).toList();
    String money(double value) => widget.hidden
        ? maskAmount(widget.currency)
        : formatAmount(value, widget.currency);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 670;
        return Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _time,
                builder: (_, _) => CustomPaint(
                  painter: _WorldPainter(
                    phase: _time.value,
                    pressure: available <= 0
                        ? 1
                        : (spent / math.max(income, 1)).clamp(0, 1),
                    dark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 20,
              right: 20,
              top: 70,
              child: _EvolutionSignal(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 102),
              child: Column(
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat(
                              'EEEE · d MMM',
                            ).format(now).toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _worldState(available, spent, income),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _WorldControl(
                        icon: Icons.inbox_outlined,
                        onTap: widget.onInbox,
                      ),
                      _WorldControl(
                        icon: widget.hidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        onTap: widget.onPrivacy,
                      ),
                      _WorldControl(
                        icon: Icons.tune_rounded,
                        onTap: widget.onSettings,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Align(
                          alignment: const Alignment(0, -.26),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'FLEXIBLE REALITY',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.7,
                                ),
                              ),
                              const SizedBox(height: 7),
                              SizedBox(
                                width: constraints.maxWidth * .72,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    money(available),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: -2,
                                          fontSize: compact ? 42 : 52,
                                        ),
                                  ),
                                ),
                              ),
                              Text(
                                '$daysLeft days of possibility remain',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (var index = 0; index < latest.length; index++)
                          Align(
                            alignment: [
                              const Alignment(-.82, .45),
                              const Alignment(.82, .24),
                              const Alignment(.48, .78),
                            ][index],
                            child: _OrbitEvent(
                              expense: latest[index],
                              hidden: widget.hidden,
                              onTap: () => widget.onOpen(latest[index]),
                            ),
                          ),
                        Align(
                          alignment: const Alignment(-.86, -.58),
                          child: _WorldDatum(
                            label: 'OBSERVED',
                            value: money(spent),
                            color: const Color(0xFFFF8066),
                          ),
                        ),
                        Align(
                          alignment: const Alignment(.85, -.58),
                          child: _WorldDatum(
                            label: 'ENTERED',
                            value: money(income),
                            color: const Color(0xFF65EAD1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.briefing != null)
                    _InterventionRibbon(
                      briefing: widget.briefing!,
                      onTap: () =>
                          widget.onMove(widget.briefing!.nextMove.type),
                    ),
                  if (widget.sync.phase != SyncPhase.idle)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        widget.sync.errorMessage ??
                            widget.sync.detail ??
                            'Sensing…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _worldState(double available, double spent, double income) {
    if (available <= 0) return 'Your world needs a correction.';
    if (income > 0 && spent / income > .75) return 'The field is narrowing.';
    return 'Your financial world is stable.';
  }
}

class _EvolutionSignal extends ConsumerWidget {
  const _EvolutionSignal();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(developmentUpdateProvider);
    if (state.phase != DevelopmentUpdatePhase.available &&
        state.phase != DevelopmentUpdatePhase.downloading &&
        state.phase != DevelopmentUpdatePhase.ready &&
        state.phase != DevelopmentUpdatePhase.permissionRequired) {
      return const SizedBox.shrink();
    }
    final ready =
        state.phase == DevelopmentUpdatePhase.ready ||
        state.phase == DevelopmentUpdatePhase.permissionRequired;
    return Material(
      color: const Color(0xFF111722).withValues(alpha: .96),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => showDevelopmentUpdateSheet(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.system_update_rounded,
                color: Color(0xFFC7FF4A),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready
                          ? 'Evolution ready to install'
                          : state.phase == DevelopmentUpdatePhase.downloading
                          ? 'Receiving evolution…'
                          : '${state.update?.versionName} available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (state.phase == DevelopmentUpdatePhase.downloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: LinearProgressIndicator(
                          value: state.progress,
                          minHeight: 2,
                          color: const Color(0xFFC7FF4A),
                          backgroundColor: Colors.white12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white54,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldControl extends StatelessWidget {
  const _WorldControl({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, size: 19, color: Colors.white70),
  );
}

class _OrbitEvent extends StatelessWidget {
  const _OrbitEvent({
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
        ? const Color(0xFF65EAD1)
        : categoryColor(expense.category);
    return Semantics(
      button: true,
      label:
          '${expense.displayMerchant}, ${expense.amount} ${expense.currency}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 132,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF090D16).withValues(alpha: .82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: .42)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color, blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.displayMerchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      hidden
                          ? maskAmount(expense.currency)
                          : '${expense.isIncome ? '+' : '−'}${formatAmount(expense.amount, expense.currency)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldDatum extends StatelessWidget {
  const _WorldDatum({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _InterventionRibbon extends StatelessWidget {
  const _InterventionRibbon({required this.briefing, required this.onTap});
  final MoneyBriefing briefing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFC7FF4A),
            size: 18,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  briefing.nextMove.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  briefing.nextMove.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_outward_rounded,
            size: 17,
            color: Colors.white70,
          ),
        ],
      ),
    ),
  );
}

class _WorldPainter extends CustomPainter {
  const _WorldPainter({
    required this.phase,
    required this.pressure,
    required this.dark,
  });
  final double phase, pressure;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF070B13),
    );
    final center = Offset(size.width / 2, size.height * .43);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(
            const Color(0xFF65EAD1),
            const Color(0xFFFF8066),
            pressure,
          )!.withValues(alpha: .18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .65));
    canvas.drawRect(Offset.zero & size, glow);
    final thread = Paint()
      ..color = Colors.white.withValues(alpha: .075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        center,
        58.0 + i * 43 + math.sin(phase * math.pi * 2 + i) * 5,
        thread,
      );
    }
    final axis = Paint()
      ..color = const Color(0xFFC7FF4A).withValues(alpha: .16)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axis);
  }

  @override
  bool shouldRepaint(covariant _WorldPainter old) =>
      old.phase != phase || old.pressure != pressure;
}

class _UnbornWorld extends StatelessWidget {
  const _UnbornWorld({required this.onSense});
  final VoidCallback onSense;
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF070B13),
    padding: const EdgeInsets.fromLTRB(32, 80, 32, 140),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NO FINANCIAL WORLD EXISTS YET',
          style: TextStyle(
            color: Color(0xFFC7FF4A),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        const Text(
          'Give Flow a signal.\nIt will build the world around you.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 35,
            height: 1.05,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onSense,
          icon: const Icon(Icons.sensors_rounded),
          label: const Text('Sense bank signals'),
        ),
        const Spacer(),
      ],
    ),
  );
}
