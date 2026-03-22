import 'package:flutter/material.dart';
import '../services/hybrid_module_service.dart';

class HybridModulesScreen extends StatefulWidget {
  const HybridModulesScreen({super.key});

  @override
  State<HybridModulesScreen> createState() => _HybridModulesScreenState();
}

class _HybridModulesScreenState extends State<HybridModulesScreen> {
  final _service = HybridModuleService.instance;
  final _urlCtrl = TextEditingController();
  bool _loading = true;
  List<HybridModule> _modules = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final url = await _service.getManifestUrl();
    if (mounted) _urlCtrl.text = url;
    await _loadModules();
  }

  Future<void> _loadModules({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final modules = await _service.loadModules(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _modules = modules;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveManifestUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    await _service.setManifestUrl(url);
    await _loadModules(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hybrid Modules'),
        actions: [
          IconButton(
            tooltip: 'Refresh from cloud',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadModules(forceRefresh: true),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ValueListenableBuilder<HybridSyncState>(
              valueListenable: _service.syncState,
              builder: (context, state, _) => _SyncStatusCard(
                state: state,
                onCheckNow: () => _loadModules(forceRefresh: true),
              ),
            ),
            const SizedBox(height: 12),
            _ManifestInput(controller: _urlCtrl, onSave: _saveManifestUrl),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _loadModules(forceRefresh: true),
                      child: _modules.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 60),
                                Icon(
                                  Icons.layers,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No modules available. Add one via the manifest URL.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : ListView.separated(
                              itemCount: _modules.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) =>
                                  _ModuleCard(module: _modules[i]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.state, required this.onCheckNow});

  final HybridSyncState state;
  final Future<void> Function() onCheckNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = state.isSyncing
        ? 'Checking for updates...'
        : state.lastSync != null
        ? 'Last synced ${_relativeTime(state.lastSync!)}'
        : 'Waiting for first sync';
    final versionText = state.manifestVersion != null
        ? 'Manifest v${state.manifestVersion}'
        : 'Manifest version unknown';
    final sourceText = state.usingCache ? 'Cached modules' : 'Live modules';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.65),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  state.isSyncing ? Icons.sync : Icons.cloud_done,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$versionText • $sourceText',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Auto-refresh every 15 minutes while the app is open.',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                TextButton.icon(
                  onPressed: state.isSyncing ? null : () => onCheckNow(),
                  icon: const Icon(Icons.refresh),
                  label: Text(state.isSyncing ? 'Checking...' : 'Check now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ManifestInput extends StatelessWidget {
  const _ManifestInput({required this.controller, required this.onSave});

  final TextEditingController controller;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cloud Manifest URL',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'https://example.com/modules.json',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => onSave(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Point this to your module CDN or Firebase Hosting endpoint. '
              'Modules are cached offline and auto-refresh when available.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});

  final HybridModule module;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        module.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(module.description),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text('v${module.version}'),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (module.updatedAt != null)
                      Text(
                        'Updated ${module.updatedAt!.toLocal().toIso8601String().substring(0, 10)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    if (module.fromCache)
                      const Text(
                        'Cached copy',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...module.sections.map((s) => _HybridSectionWidget(section: s)),
          ],
        ),
      ),
    );
  }
}

class _HybridSectionWidget extends StatelessWidget {
  const _HybridSectionWidget({required this.section});

  final HybridSection section;

  @override
  Widget build(BuildContext context) {
    switch (section.kind) {
      case HybridSectionKind.hero:
        return _HeroSection(section: section);
      case HybridSectionKind.bullets:
        return _BulletSection(section: section);
      case HybridSectionKind.callout:
        return _CalloutSection(section: section);
      case HybridSectionKind.metrics:
        return _MetricsSection(section: section);
      case HybridSectionKind.divider:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(),
        );
      case HybridSectionKind.text:
      default:
        return _TextSection(section: section);
    }
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.section});

  final HybridSection section;

  @override
  Widget build(BuildContext context) {
    final tag = section.payload?['tag'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0f766e), Color(0xFF115e59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (tag != null) const SizedBox(height: 8),
          if (section.title != null)
            Text(
              section.title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (section.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                section.subtitle!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          if (section.body != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                section.body!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.section});

  final HybridSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title != null)
            Text(
              section.title!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          if (section.body != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(section.body!),
            ),
        ],
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({required this.section});

  final HybridSection section;

  @override
  Widget build(BuildContext context) {
    final bullets = section.bullets ?? const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title != null)
            Text(
              section.title!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          const SizedBox(height: 6),
          ...bullets.map(
            (b) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(child: Text(b)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalloutSection extends StatelessWidget {
  const _CalloutSection({required this.section});

  final HybridSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title != null)
            Text(
              section.title!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          if (section.body != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(section.body!),
            ),
        ],
      ),
    );
  }
}

class _MetricsSection extends StatelessWidget {
  const _MetricsSection({required this.section});

  final HybridSection section;

  @override
  Widget build(BuildContext context) {
    final metrics = (section.payload?['metrics'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (metrics.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: metrics
            .map(
              (m) => Container(
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (m['value'] ?? '--').toString(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      (m['label'] ?? '').toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
