import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/expense_provider.dart';
import '../services/categorization_service.dart';
import '../services/gemini_model_catalog_service.dart';
import 'logs_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _keyController;
  late TextEditingController _modelController;
  late int _lookbackDays;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: ref.read(apiKeyProvider) ?? '');
    _modelController = TextEditingController(text: ref.read(geminiModelProvider));
    _lookbackDays = ref.read(syncLookbackProvider);
    _themeMode = ref.read(themeModeProvider);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _applyThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    ref.read(themeModeProvider.notifier).setThemeMode(mode);
    await ref.read(secureStorageProvider).write(
      key: 'theme_mode',
      value: mode.toString(),
    );
  }

  Future<void> _saveConfiguration() async {
    final key = _keyController.text.trim();
    final model = _modelController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid API key')),
      );
      return;
    }
    if (model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Gemini model name')),
      );
      return;
    }

    final storage = ref.read(secureStorageProvider);
    await storage.write(key: 'gemini_api_key', value: key);
    await storage.write(key: geminiModelStorageKey, value: model);
    await storage.write(key: 'sync_lookback_days', value: _lookbackDays.toString());
    await storage.write(key: 'theme_mode', value: _themeMode.toString());

    ref.read(apiKeyProvider.notifier).setKey(key);
    ref.read(geminiModelProvider.notifier).setModel(model);
    ref.read(syncLookbackProvider.notifier).setDays(_lookbackDays);
    ref.read(themeModeProvider.notifier).setThemeMode(_themeMode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved. Sync will now use "$model".')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currentKey = _keyController.text.trim();
    final availableModelsAsync = ref.watch(availableGeminiModelsProvider(currentKey));
    final remoteModels = availableModelsAsync.asData?.value ?? const <GeminiModelCatalogItem>[];
    final selectedRemoteModel = remoteModels.cast<GeminiModelCatalogItem?>().firstWhere(
          (model) => model?.name == _modelController.text.trim(),
          orElse: () => null,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _HeroSettingsCard(
            title: 'AI-powered SMS expense tracking',
            subtitle: 'Configure Gemini, tune sync depth, and shape how the app feels before each scan.',
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Gemini',
            subtitle: 'API access and runtime model selection. Preview model calls use API version $defaultGeminiApiVersion.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _keyController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'Enter your API key here',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                Text(
                  'Available models',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                availableModelsAsync.when(
                  data: (models) => _ModelDropdown(
                    selectedModel: _modelController.text.trim(),
                    models: models,
                    onSelected: (value) {
                      if (value == null || value.isEmpty) return;
                      setState(() {
                        _modelController.text = value;
                      });
                    },
                    onRefresh: () => ref.invalidate(availableGeminiModelsProvider(currentKey)),
                  ),
                  loading: () => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text('Loading Gemini models from ListModels...')),
                      ],
                    ),
                  ),
                  error: (error, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_outlined, color: scheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            currentKey.isEmpty
                                ? 'Enter API key to fetch Gemini models.'
                                : 'Could not fetch Gemini model catalog. Fallback presets still work.',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Retry',
                          onPressed: currentKey.isEmpty
                              ? null
                              : () => ref.invalidate(availableGeminiModelsProvider(currentKey)),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _modelController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Gemini model name',
                    hintText: defaultGeminiModel,
                    helperText: 'Search the dropdown or type any model ID manually. Next sync uses this value.',
                    prefixIcon: const Icon(Icons.tune_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Reset to default',
                      onPressed: () {
                        setState(() {
                          _modelController.text = defaultGeminiModel;
                        });
                      },
                      icon: const Icon(Icons.restart_alt_rounded),
                    ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedRemoteModel != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedRemoteModel.displayName,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (selectedRemoteModel.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(selectedRemoteModel.description),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (selectedRemoteModel.inputTokenLimit != null)
                              _InfoChip(
                                icon: Icons.input_rounded,
                                label: 'Input ${selectedRemoteModel.inputTokenLimit}',
                              ),
                            if (selectedRemoteModel.outputTokenLimit != null)
                              _InfoChip(
                                icon: Icons.output_rounded,
                                label: 'Output ${selectedRemoteModel.outputTokenLimit}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (selectedRemoteModel != null) const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined, color: scheme.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Current runtime model: ${_modelController.text.trim().isEmpty ? defaultGeminiModel : _modelController.text.trim()}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Remote catalog uses Gemini `models.list` on `$defaultGeminiApiVersion`. Requests also use `$defaultGeminiApiVersion` explicitly.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Appearance',
            subtitle: 'Bolder Material 3 controls fit this app better than plain dropdown rows.',
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
                  onSelectionChanged: (selection) {
                    _applyThemeMode(selection.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Sync window',
            subtitle: 'Use presets to control scan cost and AI workload.',
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
                  onSelected: (_) {
                    setState(() {
                      _lookbackDays = value;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Developer',
            subtitle: 'Inspect prompts and responses when model behavior looks off.',
            child: ListTile(
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
          colors: [
            scheme.primaryContainer,
            scheme.tertiaryContainer,
          ],
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

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.selectedModel,
    required this.models,
    required this.onSelected,
    required this.onRefresh,
  });

  final String selectedModel;
  final List<GeminiModelCatalogItem> models;
  final ValueChanged<String?> onSelected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: models.isEmpty ? null : () => _showModelSheet(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.surface.withValues(alpha: 0.75),
                  child: Icon(Icons.model_training_outlined, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gemini model catalog',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedModel.isEmpty ? 'Choose model from live Gemini catalog.' : selectedModel,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to open searchable bottom sheet.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Refresh model catalog',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    const SizedBox(height: 8),
                    Icon(Icons.keyboard_arrow_up_rounded, color: scheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          models.isEmpty
              ? 'No `generateContent` models returned.'
              : '${models.length} generateContent models available from Gemini.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _showModelSheet(BuildContext context) async {
    final searchController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final query = searchController.text.trim().toLowerCase();
            final filtered = models.where((model) {
              if (query.isEmpty) return true;
              return model.name.toLowerCase().contains(query) ||
                  model.displayName.toLowerCase().contains(query) ||
                  model.description.toLowerCase().contains(query);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.82,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose Gemini model',
                                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${filtered.length} of ${models.length} models from Gemini `ListModels`',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Refresh model catalog',
                            onPressed: () {
                              Navigator.pop(context);
                              onRefresh();
                            },
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: searchController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search model id, display name, or description',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No models match search.',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final model = filtered[index];
                                  final selected = model.name == selectedModel;
                                  return _ModelSheetTile(
                                    model: model,
                                    selected: selected,
                                    onTap: () {
                                      onSelected(model.name);
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _ModelSheetTile extends StatelessWidget {
  const _ModelSheetTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final GeminiModelCatalogItem model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected
          ? scheme.tertiaryContainer.withValues(alpha: 0.72)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.36),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: selected
                    ? scheme.primary.withValues(alpha: 0.14)
                    : scheme.surface,
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.auto_awesome_outlined,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (model.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        model.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (model.inputTokenLimit != null)
                          _InfoChip(
                            icon: Icons.input_rounded,
                            label: 'In ${model.inputTokenLimit}',
                          ),
                        if (model.outputTokenLimit != null)
                          _InfoChip(
                            icon: Icons.output_rounded,
                            label: 'Out ${model.outputTokenLimit}',
                          ),
                      ],
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
