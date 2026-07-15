import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_provider.dart';
import '../providers/expense_provider.dart';
import '../services/development_update_service.dart';
import '../providers/notification_ingestion_provider.dart';
import '../services/bank_csv_importer.dart';
import '../services/ollama_cloud_service.dart';
import '../widgets/ui/command_ui.dart';
import '../widgets/development_update_ui.dart';
import 'audit_screen.dart';
import 'custom_categories_screen.dart';
import 'logs_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _intent = TextEditingController();
  late final TextEditingController _key;
  late final TextEditingController _url;
  late final TextEditingController _income;
  late final TextEditingController _buffer;
  late String _model;
  late String _currency;
  late int _lookback;
  String? _open;
  bool _obscure = true;
  bool _testing = false;
  bool _connected = false;
  bool _importing = false;
  String _response = 'Tell Flow what should change. No hunting through menus.';

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: ref.read(ollamaApiKeyProvider));
    _url = TextEditingController(text: ref.read(ollamaBaseUrlProvider));
    final plan = ref.read(monthlyPlanProvider);
    _income = TextEditingController(
      text: plan.income == 0 ? '' : '${plan.income}',
    );
    _buffer = TextEditingController(
      text: plan.buffer == 0 ? '' : '${plan.buffer}',
    );
    _currency = ref.read(preferredCurrencyProvider);
    _model = ref.read(ollamaModelProvider);
    _lookback = ref.read(syncLookbackProvider);
  }

  @override
  void dispose() {
    _intent.dispose();
    _key.dispose();
    _url.dispose();
    _income.dispose();
    _buffer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final private = ref.watch(privateModeProvider);
    final locked = ref.watch(appLockEnabledProvider);
    final capture = ref.watch(notificationParsingEnabledProvider);
    return CommandScaffold(
      eyebrow: 'Configuration without configuration screens',
      title: 'Flow DNA',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _IntentConsole(
              controller: _intent,
              response: _response,
              onSubmit: _applyIntent,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SectionLabel('Current genetic expression'),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Expression(
                  label: private ? 'AMOUNTS VEILED' : 'AMOUNTS VISIBLE',
                  active: private,
                  onTap: () =>
                      _applyIntent(private ? 'show amounts' : 'hide amounts'),
                ),
                _Expression(
                  label: locked ? 'IDENTITY LOCKED' : 'QUICK ENTRY',
                  active: locked,
                  onTap: () => _applyIntent(locked ? 'unlock app' : 'lock app'),
                ),
                _Expression(
                  label: capture ? 'SIGNALS LISTENING' : 'SIGNALS MANUAL',
                  active: capture,
                  onTap: () => _toggleCapture(!capture),
                ),
                _Expression(
                  label: '$_currency REALITY',
                  active: true,
                  onTap: () => setState(() => _open = 'reality'),
                ),
                _Expression(
                  label: '$_lookback DAY MEMORY',
                  active: true,
                  onTap: () => setState(() => _open = 'memory'),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionLabel('DNA strands')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: SliverList.list(
            children: [
              _DnaNode(
                code: '01',
                title: 'Reality model',
                description:
                    'Currency, income expectation, safety field, appearance.',
                open: _open == 'reality',
                onTap: () => setState(
                  () => _open = _open == 'reality' ? null : 'reality',
                ),
                child: _RealityControls(
                  currency: _currency,
                  income: _income,
                  buffer: _buffer,
                  themeMode: ref.watch(themeModeProvider),
                  onCurrency: (value) => setState(() => _currency = value),
                  onTheme: _setTheme,
                  onSave: _saveReality,
                ),
              ),
              _DnaNode(
                code: '02',
                title: 'Sensing memory',
                description:
                    'How Flow hears, remembers, and proves bank signals.',
                open: _open == 'memory',
                onTap: () =>
                    setState(() => _open = _open == 'memory' ? null : 'memory'),
                child: Column(
                  children: [
                    _ToggleLine(
                      label: 'Ambient notification sensing',
                      detail: capture
                          ? 'Listening with permission'
                          : 'Only manual SMS sync',
                      value: capture,
                      onChanged: _toggleCapture,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Remember the last $_lookback days'),
                        ),
                        Text(
                          '$_lookback',
                          style: const TextStyle(
                            color: Color(0xFFC7FF4A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _lookback.toDouble(),
                      min: 7,
                      max: 180,
                      divisions: 25,
                      onChanged: (value) =>
                          setState(() => _lookback = value.round()),
                      onChangeEnd: (_) => _saveMemory(),
                    ),
                    _BranchLink(
                      label: 'Inspect signal provenance',
                      onTap: () => _push(const AuditScreen()),
                    ),
                    _BranchLink(
                      label: _importing
                          ? 'Absorbing CSV…'
                          : 'Absorb a bank CSV',
                      onTap: _importing ? null : _importCsv,
                    ),
                  ],
                ),
              ),
              _DnaNode(
                code: '03',
                title: 'Intelligence engine',
                description: 'The private model used to understand and answer.',
                open: _open == 'intelligence',
                onTap: () => setState(
                  () => _open = _open == 'intelligence' ? null : 'intelligence',
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _key,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Private model key',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _model,
                      decoration: const InputDecoration(
                        labelText: 'Reasoning model',
                      ),
                      items: [
                        for (final value in ollamaModelChoices)
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (value) => setState(() => _model = value!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _url,
                      decoration: const InputDecoration(
                        labelText: 'Model endpoint',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _testing ? null : _test,
                            child: Text(
                              _testing
                                  ? 'Tracing connection…'
                                  : _connected
                                  ? 'Connection alive'
                                  : 'Test connection',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _saveAi,
                          child: const Text('Remember'),
                        ),
                      ],
                    ),
                    _BranchLink(
                      label: 'Open reasoning trace',
                      onTap: () => _push(const LogsScreen()),
                    ),
                  ],
                ),
              ),
              _DnaNode(
                code: '04',
                title: 'Personal language',
                description: 'The meanings Flow learns from your corrections.',
                open: _open == 'language',
                onTap: () => setState(
                  () => _open = _open == 'language' ? null : 'language',
                ),
                child: _BranchLink(
                  label: 'Enter your meaning system',
                  onTap: () => _push(const CustomCategoriesScreen()),
                ),
              ),
              if (githubDevelopmentUpdatesEnabled)
                _DnaNode(
                  code: '05',
                  title: 'Evolution channel',
                  description:
                      'Signed GitHub builds, verification, and installation.',
                  open: _open == 'evolution',
                  onTap: () => setState(
                    () => _open = _open == 'evolution' ? null : 'evolution',
                  ),
                  child: const DevelopmentUpdateDnaControl(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _applyIntent(String raw) async {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return;
    _intent.clear();
    if (text.contains('hide') && text.contains('amount')) {
      await ref.read(privateModeProvider.notifier).set(true);
      _say('Amounts are now veiled everywhere.');
    } else if ((text.contains('show') || text.contains('reveal')) &&
        text.contains('amount')) {
      await ref.read(privateModeProvider.notifier).set(false);
      _say('Amounts are visible again.');
    } else if (text.contains('dark')) {
      await _setTheme(ThemeMode.dark);
      _say('Flow now inhabits dark space.');
    } else if (text.contains('light')) {
      await _setTheme(ThemeMode.light);
      _say('Flow now inhabits light space.');
    } else if (text.contains('lock') && !text.contains('unlock')) {
      await ref.read(appLockEnabledProvider.notifier).setEnabled(true);
      _say('Identity protection is active.');
    } else if (text.contains('unlock')) {
      await ref.read(appLockEnabledProvider.notifier).setEnabled(false);
      _say('Identity protection is disabled.');
    } else if (RegExp(r'\b(inr|usd|eur|gbp|sgd|aed)\b').firstMatch(text)
        case final match?) {
      _currency = match.group(0)!.toUpperCase();
      await ref.read(preferredCurrencyProvider.notifier).setCurrency(_currency);
      _say('Your financial reality now speaks $_currency.');
    } else if (RegExp(r'(\d{1,3})\s*days?').firstMatch(text)
        case final match?) {
      _lookback = (int.tryParse(match.group(1)!) ?? 30).clamp(7, 180);
      await _saveMemory();
      _say('Signal memory now reaches back $_lookback days.');
    } else if (text.contains('ai') ||
        text.contains('model') ||
        text.contains('key')) {
      setState(() => _open = 'intelligence');
      _say('I opened the intelligence strand for the private credential.');
    } else {
      _say('I cannot safely translate that yet. Open a DNA strand below.');
    }
  }

  void _say(String value) => setState(() => _response = value);

  Future<void> _setTheme(ThemeMode mode) async {
    ref.read(themeModeProvider.notifier).setThemeMode(mode);
    await ref
        .read(secureStorageProvider)
        .write(key: 'theme_mode', value: mode.toString());
  }

  Future<void> _toggleCapture(bool value) async {
    await ref.read(notificationIngestionProvider.notifier).setEnabled(value);
  }

  Future<void> _saveReality() async {
    await ref.read(preferredCurrencyProvider.notifier).setCurrency(_currency);
    await ref
        .read(monthlyPlanProvider.notifier)
        .setPlan(
          income: double.tryParse(_income.text.trim()) ?? 0,
          buffer: double.tryParse(_buffer.text.trim()) ?? 0,
        );
    _say('Reality model recalibrated.');
  }

  Future<void> _saveMemory() async {
    ref.read(syncLookbackProvider.notifier).setDays(_lookback);
    await ref
        .read(secureStorageProvider)
        .write(key: 'sync_lookback_days', value: '$_lookback');
  }

  Future<void> _saveAi() async {
    final url = _url.text.trim().isEmpty
        ? defaultOllamaBaseUrl
        : _url.text.trim();
    await Future.wait([
      ref
          .read(secureStorageProvider)
          .write(key: ollamaApiKeyStorageKey, value: _key.text.trim()),
      ref
          .read(secureStorageProvider)
          .write(key: ollamaBaseUrlStorageKey, value: url),
      ref
          .read(secureStorageProvider)
          .write(key: ollamaModelStorageKey, value: _model),
    ]);
    ref.read(ollamaApiKeyProvider.notifier).set(_key.text.trim());
    ref.read(ollamaBaseUrlProvider.notifier).set(url);
    ref.read(ollamaModelProvider.notifier).set(_model);
    _say('The intelligence strand remembers this model.');
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final ok = await OllamaCloudService(
      apiKey: _key.text.trim(),
      baseUrl: _url.text.trim().isEmpty
          ? defaultOllamaBaseUrl
          : _url.text.trim(),
      model: _model,
    ).validateKey();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _connected = ok;
    });
    _say(
      ok
          ? 'The private intelligence connection is alive.'
          : 'The model did not answer. Check its key and endpoint.',
    );
  }

  Future<void> _importCsv() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    final path = picked?.files.firstOrNull?.path;
    if (path == null) return;
    setState(() => _importing = true);
    try {
      final expenses = await BankCsvImporter.parse(
        File(path),
        currency: _currency,
      );
      await ref.read(expenseListProvider.notifier).addExpenses(expenses);
      _say('Flow absorbed ${expenses.length} historical movements.');
    } catch (_) {
      _say('That history could not be absorbed safely. Nothing changed.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _IntentConsole extends StatelessWidget {
  const _IntentConsole({
    required this.controller,
    required this.response,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final String response;
  final ValueChanged<String> onSubmit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF090D16),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(8),
        topRight: Radius.circular(38),
        bottomLeft: Radius.circular(38),
        bottomRight: Radius.circular(8),
      ),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SPEAK AN INTENT',
          style: TextStyle(
            color: Color(0xFFC7FF4A),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          onSubmitted: onSubmit,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: '“Hide amounts” or “scan 60 days”…',
            hintStyle: const TextStyle(color: Colors.white30),
            suffixIcon: IconButton(
              onPressed: () => onSubmit(controller.text),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFFC7FF4A),
              ),
            ),
            border: InputBorder.none,
          ),
        ),
        const Divider(color: Colors.white12),
        Text(
          response,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    ),
  );
}

class _Expression extends StatelessWidget {
  const _Expression({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
    onPressed: onTap,
    avatar: Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
        shape: BoxShape.circle,
      ),
    ),
    label: Text(
      label,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .7,
      ),
    ),
  );
}

class _DnaNode extends StatelessWidget {
  const _DnaNode({
    required this.code,
    required this.title,
    required this.description,
    required this.open,
    required this.onTap,
    required this.child,
  });
  final String code, title, description;
  final bool open;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 320),
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: open
          ? Theme.of(context).colorScheme.primary.withValues(alpha: .07)
          : Theme.of(context).colorScheme.surface.withValues(alpha: .65),
      border: Border(
        left: BorderSide(
          color: open
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: open ? 2 : 1,
        ),
      ),
    ),
    child: Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                code,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(open ? Icons.remove_rounded : Icons.add_rounded),
            ],
          ),
        ),
        if (open) ...[const SizedBox(height: 20), child],
      ],
    ),
  );
}

class _RealityControls extends StatelessWidget {
  const _RealityControls({
    required this.currency,
    required this.income,
    required this.buffer,
    required this.themeMode,
    required this.onCurrency,
    required this.onTheme,
    required this.onSave,
  });
  final String currency;
  final TextEditingController income, buffer;
  final ThemeMode themeMode;
  final ValueChanged<String> onCurrency;
  final ValueChanged<ThemeMode> onTheme;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        spacing: 6,
        children: [
          for (final value in const ['INR', 'USD', 'EUR', 'GBP', 'SGD', 'AED'])
            ChoiceChip(
              label: Text(value),
              selected: currency == value,
              onSelected: (_) => onCurrency(value),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: income,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Expected monthly energy in',
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: buffer,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Untouchable safety field',
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('Adaptive')),
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
        ],
        selected: {themeMode},
        onSelectionChanged: (value) => onTheme(value.first),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onSave,
          child: const Text('Recalibrate reality'),
        ),
      ),
    ],
  );
}

class _ToggleLine extends StatelessWidget {
  const _ToggleLine({
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });
  final String label, detail;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

class _BranchLink extends StatelessWidget {
  const _BranchLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
    leading: Text(
      '↗',
      style: TextStyle(color: Theme.of(context).colorScheme.primary),
    ),
    title: Text(label),
  );
}
