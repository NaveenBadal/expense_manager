import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../domain/transaction.dart';
import '../../features/activity/transaction_editor_sheet.dart';
import '../format/money_format.dart';
import '../flow_categories.dart';
import '../motion/flow_motion_widgets.dart';
import '../sheets/confirm_delete_sheet.dart';
import '../tokens/flow_metrics.dart';
import '../tokens/flow_palette.dart';
import '../tokens/flow_type.dart';

/// One transaction, in full.
///
/// This is where trust is won or lost: the app claims it read something from
/// a message, and this screen puts the claim and the evidence side by side —
/// the source text, what was taken from it, how sure the model was, and the
/// record's siblings at the same merchant. It is a route rather than a
/// sheet so that chat and any future surface can link into it and back.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final int transactionId;

  /// Pushes the detail for [id] onto the root navigator, so it opens above
  /// whatever is on screen — including the chat sheet — and pops back to it.
  static Future<void> open(BuildContext context, int id) =>
      Navigator.of(context, rootNavigator: true).push(
        FlowPageRoute<void>(
          builder: (route) => TransactionDetailScreen(transactionId: id),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider).requireValue;
    final flow = context.flow;

    // Watched live rather than passed in: an edit made from this screen
    // re-renders it, and a deletion elsewhere cannot leave it showing a
    // record that no longer exists.
    final item = app.transactions
        .where((value) => value.id == transactionId)
        .firstOrNull;
    if (item == null) return const _GoneScreen();

    final hidden = app.preferences.hideAmounts;
    final incoming = item.direction == TransactionDirection.incoming;
    final pending = item.reviewState == ReviewState.needsReview;
    final similar = _similar(app.transactions, item);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FlowSpace.sm,
                FlowSpace.xs,
                FlowSpace.sm,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: flow.ink,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Edit details',
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (sheet) =>
                          TransactionEditorSheet(transaction: item),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    color: flow.inkSoft,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () async {
                      final confirmed = await confirmDeleteTransactions(
                        context,
                        count: 1,
                      );
                      if (!confirmed || !context.mounted) return;
                      await ref
                          .read(appControllerProvider.notifier)
                          .deleteTransaction(transactionId);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: flow.inkSoft,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  FlowSpace.xl,
                  FlowSpace.sm,
                  FlowSpace.xl,
                  FlowSpace.xl + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  // ------------------------------------------------- hero
                  Text(
                    incoming ? 'Money in' : 'Money out',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: flow.inkSoft),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    hidden
                        ? '••••••'
                        : '${incoming ? '+' : '−'}'
                              '${formatMoney(item.amountMinor, item.currency)}',
                    style: FlowType.amountHero.copyWith(
                      color: incoming ? flow.income : flow.ink,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.sm),
                  Text(
                    item.merchant,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _when(item.occurredAt),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: flow.inkSoft),
                  ),
                  if ((item.account ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.account!.trim(),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: flow.inkSoft),
                      ),
                    ),

                  if (pending) ...[
                    const SizedBox(height: FlowSpace.lg),
                    _ConfirmCallout(
                      onConfirm: () {
                        unawaited(HapticFeedback.lightImpact());
                        ref
                            .read(appControllerProvider.notifier)
                            .confirmTransaction(item);
                      },
                    ),
                  ],

                  // --------------------------------------------- category
                  const SizedBox(height: FlowSpace.xl),
                  Text(
                    'Category',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: flow.inkSoft),
                  ),
                  const SizedBox(height: FlowSpace.sm),
                  Wrap(
                    spacing: FlowSpace.sm,
                    runSpacing: FlowSpace.sm,
                    children: [
                      // The model may assign a category outside the standard
                      // vocabulary (a refund, say). Without this the record's
                      // own category would be invisible here and the chips
                      // would read as "uncategorised".
                      for (final category in [
                        if (!kFlowCategories.any(
                          (value) =>
                              value.toLowerCase() ==
                              item.category.toLowerCase(),
                        ))
                          item.category,
                        ...kFlowCategories,
                      ])
                        _CategoryChip(
                          label: category,
                          selected:
                              category.toLowerCase() ==
                              item.category.toLowerCase(),
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            ref
                                .read(appControllerProvider.notifier)
                                .saveTransaction(
                                  item.copyWith(
                                    category: category,
                                    reviewState: ReviewState.confirmed,
                                    confidence: 1,
                                  ),
                                );
                          },
                        ),
                    ],
                  ),

                  // ------------------------------------------- provenance
                  const SizedBox(height: FlowSpace.xl),
                  Text(
                    'How it got here',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: flow.inkSoft),
                  ),
                  const SizedBox(height: FlowSpace.sm),
                  _ProvenanceCard(item: item),

                  if ((item.sourceText ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: FlowSpace.lg),
                    Text(
                      'Read from this message',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: flow.inkSoft),
                    ),
                    const SizedBox(height: FlowSpace.xs),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(FlowSpace.md),
                      decoration: BoxDecoration(
                        color: flow.sunken,
                        borderRadius: FlowRadius.sm,
                      ),
                      child: SelectableText(
                        item.sourceText!.trim(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: flow.inkSoft,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],

                  if ((item.note ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: FlowSpace.lg),
                    Text(
                      'Note',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: flow.inkSoft),
                    ),
                    const SizedBox(height: FlowSpace.xs),
                    Text(
                      item.note!.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],

                  // ---------------------------------------------- similar
                  if (similar.isNotEmpty) ...[
                    const SizedBox(height: FlowSpace.xl),
                    Text(
                      'More at ${item.merchant}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: FlowSpace.xs),
                    for (final other in similar)
                      _SimilarRow(item: other, hidden: hidden),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Other records at the same merchant, newest first. Six is enough to
  /// answer "is this amount normal here" without becoming a second ledger.
  static List<MoneyTransaction> _similar(
    List<MoneyTransaction> all,
    MoneyTransaction item,
  ) {
    final merchant = item.merchant.trim().toLowerCase();
    final matches = [
      for (final other in all)
        if (other.id != item.id &&
            other.merchant.trim().toLowerCase() == merchant)
          other,
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return matches.take(6).toList();
  }

  static String _when(DateTime value) =>
      DateFormat('EEEE, d MMM yyyy · h:mm a').format(value);
}

/// The one decision a pending record asks for, stated as a question rather
/// than buried in chrome.
class _ConfirmCallout extends StatelessWidget {
  const _ConfirmCallout({required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    return Container(
      padding: const EdgeInsets.all(FlowSpace.lg),
      decoration: BoxDecoration(
        color: flow.raised,
        borderRadius: FlowRadius.md,
        border: Border.all(color: flow.attention.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Neutral on purpose: review can be flagged for reasons other than
          // low confidence, so this must not claim the model "was not sure"
          // next to a provenance card reading 96%.
          Text(
            'This one is waiting on you',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Check the reading below, then confirm it or fix the category.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: flow.inkSoft),
          ),
          const SizedBox(height: FlowSpace.md),
          FilledButton.icon(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(FlowDensity.minimumTarget),
              backgroundColor: flow.accent,
              foregroundColor: flow.onAccent,
              shape: const RoundedRectangleBorder(borderRadius: FlowRadius.sm),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Looks right'),
          ),
        ],
      ),
    );
  }
}

class _ProvenanceCard extends StatelessWidget {
  const _ProvenanceCard({required this.item});
  final MoneyTransaction item;

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    final manual = item.source == TransactionSource.manual;
    final pending = item.reviewState == ReviewState.needsReview;

    final source = switch (item.source) {
      TransactionSource.message => 'Read from a message',
      TransactionSource.notification => 'Read from a notification',
      TransactionSource.manual => 'Entered by hand',
    };
    final status = pending
        ? 'Waiting for your confirmation'
        : manual
        ? 'Yours, so nothing to confirm'
        : 'Confirmed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FlowSpace.lg),
      decoration: BoxDecoration(
        color: flow.raised,
        borderRadius: FlowRadius.md,
        border: Border.all(color: flow.line),
      ),
      child: Column(
        children: [
          _ProvenanceRow(
            icon: manual ? Icons.edit_outlined : Icons.sms_outlined,
            label: 'Source',
            value: source,
          ),
          // Confidence is a claim about a machine's reading; a manual entry
          // makes no such claim and stating one would be theatre.
          if (!manual) ...[
            const SizedBox(height: FlowSpace.md),
            _ProvenanceRow(
              icon: Icons.percent_rounded,
              label: 'Confidence',
              value: _confidence(item.confidence),
            ),
          ],
          const SizedBox(height: FlowSpace.md),
          _ProvenanceRow(
            icon: pending
                ? Icons.help_outline_rounded
                : Icons.check_circle_outline_rounded,
            label: 'Status',
            value: status,
            valueColor: pending ? flow.attention : null,
          ),
        ],
      ),
    );
  }

  static String _confidence(double value) {
    final percent = (value.clamp(0, 1) * 100).round();
    final word = switch (percent) {
      >= 90 => 'high',
      >= 70 => 'fair',
      _ => 'low',
    };
    return '$percent% — $word';
  }
}

class _ProvenanceRow extends StatelessWidget {
  const _ProvenanceRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    return Row(
      children: [
        Icon(icon, size: 17, color: flow.inkFaint),
        const SizedBox(width: FlowSpace.md),
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: flow.inkSoft),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: valueColor),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, current category' : 'Set category to $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: FlowRadius.pill,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.md,
            vertical: FlowSpace.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? flow.accent : flow.raised,
            borderRadius: FlowRadius.pill,
            border: Border.all(color: selected ? flow.accent : flow.line),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? flow.onAccent : flow.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _SimilarRow extends StatelessWidget {
  const _SimilarRow({required this.item, required this.hidden});
  final MoneyTransaction item;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    final incoming = item.direction == TransactionDirection.incoming;
    return InkWell(
      onTap: item.id == null
          ? null
          : () => TransactionDetailScreen.open(context, item.id!),
      child: Container(
        constraints: const BoxConstraints(minHeight: FlowDensity.compactRow),
        padding: const EdgeInsets.symmetric(vertical: FlowSpace.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('d MMM yyyy').format(item.occurredAt),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    item.category,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: flow.inkFaint),
                  ),
                ],
              ),
            ),
            Text(
              hidden
                  ? '••••'
                  : '${incoming ? '+' : '−'}'
                        '${formatMoney(item.amountMinor, item.currency)}',
              style: FlowType.amountRow.copyWith(
                color: incoming ? flow.income : flow.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the record was deleted while this route was open.
class _GoneScreen extends StatelessWidget {
  const _GoneScreen();

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FlowSpace.sm,
                FlowSpace.xs,
                FlowSpace.sm,
                0,
              ),
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                color: flow.ink,
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(FlowSpace.xl),
                  child: Text(
                    'This transaction is no longer in your record.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: flow.inkSoft),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
