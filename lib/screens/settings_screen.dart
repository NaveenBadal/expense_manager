import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/notification_ingestion_provider.dart';
import '../services/development_update_service.dart';
import '../services/ollama_cloud_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/development_update_ui.dart';
import '../widgets/ui/flow_ui.dart';
import 'audit_screen.dart';
import 'custom_categories_screen.dart';
import 'logs_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _key;
  late final TextEditingController _url;
  late String _model;
  late String _currency;
  late int _lookback;
  bool _obscure = true;
  bool _testing = false;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: ref.read(ollamaApiKeyProvider));
    _url = TextEditingController(text: ref.read(ollamaBaseUrlProvider));
    _currency = ref.read(preferredCurrencyProvider);
    _model = ref.read(ollamaModelProvider);
    _lookback = ref.read(syncLookbackProvider);
  }

  @override
  void dispose() {
    _key.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final private = ref.watch(privateModeProvider);
    final locked = ref.watch(appLockEnabledProvider);
    final capture = ref.watch(notificationParsingEnabledProvider);
    final ingestion = ref.watch(notificationIngestionProvider);
    final themeMode = ref.watch(themeModeProvider);
    final aiConfigured = ref.watch(ollamaApiKeyProvider).trim().isNotEmpty;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentInset = screenWidth > AppBreakpoint.contentMax + 40
        ? (screenWidth - AppBreakpoint.contentMax) / 2
        : AppSpacing.lg;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Text('You', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(contentInset, 0, contentInset, 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              'Control Flow intelligence, data sources, privacy, and preferences.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const _SectionTitle('Flow intelligence'),
          _SettingsCard(
            children: [
              ListTile(
                leading: FlowOrb(
                  size: 42,
                  state: _testing
                      ? FlowOrbState.thinking
                      : _connected || aiConfigured
                      ? FlowOrbState.ready
                      : FlowOrbState.offline,
                ),
                title: const Text('Ollama Cloud'),
                subtitle: Text(
                  _connected
                      ? 'Connection verified · $_model'
                      : aiConfigured
                      ? 'Configured · $_model'
                      : 'Required for SMS understanding and agent answers',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showAiConnection,
              ),
            ],
          ),
          const _SectionTitle('Transaction sources'),
          _SettingsCard(
            children: [
              const ListTile(
                leading: Icon(Icons.sms_outlined),
                title: Text('Transaction SMS'),
                subtitle: Text(
                  'Primary source · Start or refresh analysis from Flow',
                ),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Notification continuity'),
                subtitle: Text(
                  capture
                      ? ingestion.accessEnabled
                            ? 'Automatically detect supported transaction notifications'
                            : 'Finish granting notification access in Android settings'
                      : 'Optional enhancement for future supported activity',
                ),
                value: capture,
                onChanged: _toggleCapture,
              ),
              const Divider(height: 1, indent: 56),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SMS history range'),
                          Text(
                            'Scan the last $_lookback days',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Slider(
                value: _lookback.toDouble(),
                min: 7,
                max: 180,
                divisions: 25,
                label: '$_lookback days',
                onChanged: (value) => setState(() => _lookback = value.round()),
                onChangeEnd: (_) => _saveMemory(),
              ),
            ],
          ),
          const _SectionTitle('Privacy and security'),
          _SettingsCard(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline_rounded),
                title: const Text('App lock'),
                subtitle: const Text(
                  'Require device authentication when Flow opens',
                ),
                value: locked,
                onChanged: (value) =>
                    ref.read(appLockEnabledProvider.notifier).setEnabled(value),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Data and AI privacy'),
                subtitle: const Text('See exactly what leaves this device'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showPrivacy,
              ),
            ],
          ),
          const _SectionTitle('Personalization'),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _ThemeModeSelector(
                  value: themeMode,
                  onChanged: _setTheme,
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_outlined),
                title: const Text('Show amounts'),
                subtitle: const Text(
                  'Display monetary values throughout the app',
                ),
                value: !private,
                onChanged: (value) =>
                    ref.read(privateModeProvider.notifier).set(!value),
              ),
            ],
          ),
          const _SectionTitle('Money and organization'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Primary currency'),
                subtitle: Text('$_currency · Used when SMS has no currency'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showMoneyPreferences,
              ),
            ],
          ),
          const _SectionTitle('Advanced'),
          _SettingsCard(
            children: [
              ExpansionTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Diagnostics and organization'),
                subtitle: const Text('Import audit, categories, and AI logs'),
                children: [
                  ListTile(
                    leading: const Icon(Icons.fact_check_outlined),
                    title: const Text('Import history'),
                    onTap: () => _push(const AuditScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('Category library'),
                    onTap: () => _push(const CustomCategoriesScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.terminal_outlined),
                    title: const Text('AI activity log'),
                    onTap: () => _push(const LogsScreen()),
                  ),
                  if (githubDevelopmentUpdatesEnabled)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: DevelopmentUpdateSettingsCard(),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Flow keeps your financial records on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMoneyPreferences() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FlowSheetHeader(
                  leading: Icon(Icons.payments_outlined),
                  title: 'Primary currency',
                  description:
                      'Used for new transactions, monthly guides, and spending limits. Existing records keep their original currency.',
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: [
                    for (final value in const [
                      'INR',
                      'USD',
                      'EUR',
                      'GBP',
                      'SGD',
                      'AED',
                    ])
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _currency = value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await _saveCurrency();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Save currency'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAiConnection() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FlowSheetHeader(
                  leading: FlowOrb(size: 44),
                  title: 'Connect Ollama Cloud',
                  description:
                      'Used for Flow answers and transaction SMS understanding when you start them.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _key,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'API key',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show API key' : 'Hide API key',
                      onPressed: () {
                        setState(() => _obscure = !_obscure);
                        setSheetState(() {});
                      },
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _model,
                  decoration: const InputDecoration(labelText: 'Model'),
                  items: [
                    for (final value in ollamaModelChoices)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _model = value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Endpoint'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing
                            ? null
                            : () async {
                                await _test();
                                setSheetState(() {});
                              },
                        child: Text(_testing ? 'Testing…' : 'Test'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final valid = await _test(notify: false);
                          if (!valid) {
                            _notify(
                              'Connection failed. Nothing was saved. Check the key and endpoint.',
                            );
                            setSheetState(() {});
                            return;
                          }
                          await _saveAi();
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        child: const Text('Verify and save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _notify(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _setTheme(ThemeMode mode) async {
    ref.read(themeModeProvider.notifier).setThemeMode(mode);
    await ref
        .read(secureStorageProvider)
        .write(key: 'theme_mode', value: mode.toString());
  }

  Future<void> _toggleCapture(bool value) async {
    if (value) {
      final proceed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.notifications_active_outlined),
              title: const Text('Allow transaction capture?'),
              content: const Text(
                'Android will ask you to grant notification access. Flow keeps supported bank notification text on this device and ignores unrelated notifications.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Android settings'),
                ),
              ],
            ),
          ) ??
          false;
      if (!proceed) return;
    }
    await ref.read(notificationIngestionProvider.notifier).setEnabled(value);
  }

  Future<void> _saveCurrency() async {
    await ref.read(preferredCurrencyProvider.notifier).setCurrency(_currency);
    _notify('Primary currency saved.');
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
    _notify('AI connection saved.');
  }

  Future<bool> _test({bool notify = true}) async {
    setState(() => _testing = true);
    final service = OllamaCloudService(
      apiKey: _key.text.trim(),
      baseUrl: _url.text.trim().isEmpty
          ? defaultOllamaBaseUrl
          : _url.text.trim(),
      model: _model,
    );
    final ok = await service.validateKey();
    service.close();
    if (!mounted) return false;
    setState(() {
      _testing = false;
      _connected = ok;
    });
    if (notify) {
      _notify(
        ok
            ? 'Ollama is connected.'
            : 'Connection failed. Check the key and endpoint.',
      );
    }
    return ok;
  }

  Future<void> _showPrivacy() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlowSheetHeader(
              leading: Icon(Icons.privacy_tip_outlined),
              title: 'Data and AI privacy',
              description:
                  'A clear map of what Flow processes and where your financial evidence stays.',
            ),
            SizedBox(height: 24),
            _PrivacyFact(
              icon: Icons.sms_outlined,
              title: 'SMS extraction',
              detail:
                  'Selected bank SMS text is sent to your configured Ollama endpoint to extract transaction details.',
            ),
            SizedBox(height: 20),
            _PrivacyFact(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Assistant questions',
              detail:
                  'Ordinary questions share only structured MCP results. Original SMS is shared only when you request re-analysis and approve it.',
            ),
            SizedBox(height: 20),
            _PrivacyFact(
              icon: Icons.storage_outlined,
              title: 'On this device',
              detail:
                  'Transactions, filters, settings, and verification evidence remain local unless an AI request explicitly needs them.',
            ),
          ],
        ),
      ),
    ),
  );

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = [
    (ThemeMode.system, Icons.brightness_auto_outlined, 'System'),
    (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
    (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final adaptive =
        MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (adaptive) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final option in _options)
            ChoiceChip(
              selected: value == option.$1,
              avatar: Icon(option.$2, size: 18),
              label: Text(option.$3),
              onSelected: (_) => onChanged(option.$1),
            ),
        ],
      );
    }
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: [
        for (final option in _options)
          ButtonSegment(
            value: option.$1,
            icon: Icon(option.$2),
            label: Text(option.$3),
          ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      shape: ExpressiveShape.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    ),
  );
}

class _PrivacyFact extends StatelessWidget {
  const _PrivacyFact({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
