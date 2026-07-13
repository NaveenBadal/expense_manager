import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/expense_provider.dart';
import '../screens/action_inbox_screen.dart';
import '../screens/settings_screen.dart';
import 'expense_form_sheet.dart';

class GlobalQuickActionButton extends ConsumerWidget {
  const GlobalQuickActionButton({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(syncProvider).isActive;
    final button = small
        ? FloatingActionButton.small(
            heroTag: 'global-quick-action-small',
            tooltip: 'Quick action',
            onPressed: syncing ? null : () => _show(context, ref),
            child: syncing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
          )
        : FloatingActionButton(
            heroTag: 'global-quick-action',
            tooltip: 'Quick action',
            onPressed: syncing ? null : () => _show(context, ref),
            child: syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
          );
    return button;
  }

  Future<void> _show(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Add movement'),
                subtitle: const Text('Record money in or money out'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _add(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bolt_rounded),
                title: const Text('Sync bank messages'),
                subtitle: const Text('Import new transactions'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref.read(syncProvider.notifier).sync();
                },
              ),
              ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: const Text('Action inbox'),
                subtitle: const Text('Review decisions that need you'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ActionInboxScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Settings'),
                subtitle: const Text('Plan, privacy, and automation'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ExpenseFormSheet(
        onSave: (value) async {
          await ref.read(expenseListProvider.notifier).addExpense(value);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }
}

extension on SyncState {
  bool get isActive =>
      phase == SyncPhase.requestingPermissions ||
      phase == SyncPhase.fetchingSms ||
      phase == SyncPhase.analyzing;
}
