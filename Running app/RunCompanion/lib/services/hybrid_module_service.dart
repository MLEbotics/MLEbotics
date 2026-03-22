import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a cloud-delivered module definition that can update without
/// shipping a new binary.
class HybridModule {
  final String id;
  final String title;
  final String description;
  final String version;
  final DateTime? updatedAt;
  final List<HybridSection> sections;
  final bool fromCache;

  const HybridModule({
    required this.id,
    required this.title,
    required this.description,
    required this.version,
    required this.sections,
    this.updatedAt,
    this.fromCache = false,
  });
}

class HybridSyncState {
  final bool isSyncing;
  final bool usingCache;
  final DateTime? lastSync;
  final String? manifestVersion;
  final String? error;

  const HybridSyncState({
    this.isSyncing = false,
    this.usingCache = false,
    this.lastSync,
    this.manifestVersion,
    this.error,
  });

  HybridSyncState copyWith({
    bool? isSyncing,
    bool? usingCache,
    DateTime? lastSync,
    String? manifestVersion,
    String? error,
    bool clearError = false,
    bool clearManifestVersion = false,
  }) {
    return HybridSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      usingCache: usingCache ?? this.usingCache,
      lastSync: lastSync ?? this.lastSync,
      manifestVersion: clearManifestVersion
          ? null
          : (manifestVersion ?? this.manifestVersion),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class _HybridManifestData {
  final List<HybridModule> modules;
  final String? manifestVersion;
  const _HybridManifestData({required this.modules, this.manifestVersion});
}

enum HybridSectionKind { hero, text, bullets, callout, metrics, divider }

class HybridSection {
  final HybridSectionKind kind;
  final String? title;
  final String? subtitle;
  final String? body;
  final List<String>? bullets;
  final Map<String, dynamic>? payload;

  const HybridSection({
    required this.kind,
    this.title,
    this.subtitle,
    this.body,
    this.bullets,
    this.payload,
  });
}

/// Service that fetches, caches, and parses hybrid modules.
class HybridModuleService {
  HybridModuleService._();
  static final instance = HybridModuleService._();

  static const _prefManifestUrl = 'hybrid_manifest_url';
  static const _prefCache = 'hybrid_module_cache_v1';
  static const _prefLastSyncIso = 'hybrid_last_sync_iso';
  static const _prefManifestVersion = 'hybrid_manifest_version';
  static const defaultManifestUrl =
      'https://runningcompanion.web.app/modules.json';

  final ValueNotifier<HybridSyncState> syncState = ValueNotifier(
    const HybridSyncState(),
  );

  Timer? _autoRefreshTimer;
  bool _autoRefreshStarted = false;
  bool _hydratedMetadata = false;

  Future<String> _manifestUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_prefManifestUrl);
    return (url == null || url.trim().isEmpty) ? defaultManifestUrl : url;
  }

  Future<String> getManifestUrl() => _manifestUrl();

  Future<void> setManifestUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefManifestUrl, url.trim());
  }

  Future<List<HybridModule>> loadModules({bool forceRefresh = false}) async {
    await _ensureHydratedMetadata();
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cached = prefs.getString(_prefCache);
      if (cached != null && cached.isNotEmpty) {
        try {
          final manifest = _parseManifest(cached, fromCache: true);
          _markCacheServed(prefs);
          return manifest.modules;
        } catch (e, st) {
          debugPrint('Hybrid module cache parse error: $e\n$st');
        }
      }
    }

    syncState.value = syncState.value.copyWith(
      isSyncing: true,
      usingCache: false,
      clearError: true,
    );

    final url = await _manifestUrl();
    String? failureMsg;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        prefs.setString(_prefCache, response.body);
        final manifest = _parseManifest(response.body);
        _recordSuccessfulSync(prefs, manifest.manifestVersion);
        return manifest.modules;
      }
      failureMsg = 'HTTP ${response.statusCode}';
      debugPrint('Hybrid module fetch failed: ${response.statusCode}');
    } catch (e, st) {
      failureMsg = e.toString();
      debugPrint('Hybrid module fetch error: $e\n$st');
    }

    syncState.value = syncState.value.copyWith(isSyncing: false);

    // Fallback to cached data if available
    final cached = prefs.getString(_prefCache);
    if (cached != null && cached.isNotEmpty) {
      try {
        final manifest = _parseManifest(cached, fromCache: true);
        _markCacheServed(
          prefs,
          error: 'Showing cached modules ($failureMsg)',
        );
        return manifest.modules;
      } catch (e) {
        debugPrint('Hybrid fallback parse error: $e');
      }
    }

    // Final fallback to bundled manifest
    final manifest = _parseManifest(_fallbackManifest, fromCache: true);
    syncState.value = syncState.value.copyWith(
      isSyncing: false,
      usingCache: true,
      error: 'Fallback manifest loaded',
    );
    return manifest.modules;
  }

  void ensureAutoRefresh({Duration interval = const Duration(minutes: 15)}) {
    if (_autoRefreshStarted) return;
    _autoRefreshStarted = true;
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(interval, (_) {
      unawaited(loadModules(forceRefresh: true));
    });
    unawaited(loadModules());
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    _autoRefreshStarted = false;
  }

  Future<void> _ensureHydratedMetadata() async {
    if (_hydratedMetadata) return;
    final prefs = await SharedPreferences.getInstance();
    _hydratedMetadata = true;
    final lastSyncIso = prefs.getString(_prefLastSyncIso);
    final manifestVersion = prefs.getString(_prefManifestVersion);
    final lastSync = lastSyncIso != null
        ? DateTime.tryParse(lastSyncIso)
        : null;
    final normalizedVersion =
        (manifestVersion != null && manifestVersion.isNotEmpty)
        ? manifestVersion
        : null;
    syncState.value = syncState.value.copyWith(
      lastSync: lastSync,
      manifestVersion: normalizedVersion,
      clearManifestVersion: normalizedVersion == null,
    );
  }

  void _recordSuccessfulSync(SharedPreferences prefs, String? manifestVersion) {
    final normalizedVersion =
        (manifestVersion != null && manifestVersion.trim().isNotEmpty)
        ? manifestVersion.trim()
        : null;
    final now = DateTime.now();
    prefs.setString(_prefLastSyncIso, now.toIso8601String());
    if (normalizedVersion != null) {
      prefs.setString(_prefManifestVersion, normalizedVersion);
    } else {
      prefs.remove(_prefManifestVersion);
    }
    syncState.value = syncState.value.copyWith(
      isSyncing: false,
      usingCache: false,
      lastSync: now,
      manifestVersion: normalizedVersion,
      clearError: true,
      clearManifestVersion: normalizedVersion == null,
    );
  }

  void _markCacheServed(SharedPreferences prefs, {String? error}) {
    final lastSyncIso = prefs.getString(_prefLastSyncIso);
    final manifestVersion = prefs.getString(_prefManifestVersion);
    final lastSync = lastSyncIso != null
        ? DateTime.tryParse(lastSyncIso)
        : null;
    final normalizedVersion =
        (manifestVersion != null && manifestVersion.isNotEmpty)
        ? manifestVersion
        : null;
    syncState.value = syncState.value.copyWith(
      isSyncing: false,
      usingCache: true,
      lastSync: lastSync,
      manifestVersion: normalizedVersion,
      error: error,
      clearError: error == null,
      clearManifestVersion: normalizedVersion == null,
    );
  }

  _HybridManifestData _parseManifest(String raw, {bool fromCache = false}) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final modules = (decoded['modules'] as List<dynamic>? ?? []).map((e) {
      final data = e as Map<String, dynamic>;
      final sections = (data['sections'] as List<dynamic>? ?? [])
          .map((section) => _parseSection(section as Map<String, dynamic>))
          .toList();
      return HybridModule(
        id:
            data['id'] as String? ??
            'module_${DateTime.now().millisecondsSinceEpoch}',
        title: data['title'] as String? ?? 'Untitled Module',
        description: data['description'] as String? ?? '',
        version: data['version'] as String? ?? '0.0.0',
        updatedAt: data['updatedAt'] != null
            ? DateTime.tryParse(data['updatedAt'] as String)
            : null,
        sections: sections,
        fromCache: fromCache,
      );
    }).toList();
    final manifestVersionRaw =
        (decoded['manifestVersion'] ?? decoded['version']) as String?;
    final manifestVersion = manifestVersionRaw?.trim();
    final normalizedVersion =
        (manifestVersion != null && manifestVersion.isNotEmpty)
        ? manifestVersion
        : null;
    return _HybridManifestData(
      modules: modules,
      manifestVersion: normalizedVersion,
    );
  }

  HybridSection _parseSection(Map<String, dynamic> data) {
    final kind = _kindFromString(data['kind'] as String? ?? 'text');
    return HybridSection(
      kind: kind,
      title: data['title'] as String?,
      subtitle: data['subtitle'] as String?,
      body: data['body'] as String?,
      bullets: (data['bullets'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      payload: data['payload'] as Map<String, dynamic>?,
    );
  }

  HybridSectionKind _kindFromString(String value) {
    switch (value.toLowerCase()) {
      case 'hero':
        return HybridSectionKind.hero;
      case 'bullets':
        return HybridSectionKind.bullets;
      case 'callout':
        return HybridSectionKind.callout;
      case 'metrics':
        return HybridSectionKind.metrics;
      case 'divider':
        return HybridSectionKind.divider;
      default:
        return HybridSectionKind.text;
    }
  }
}

const _fallbackManifest = '''
{
  "manifestVersion": "1.0.0",
  "modules": [
    {
      "id": "cloud_modules",
      "title": "Cloud Module Host",
      "description": "Explains how the hybrid module host works inside the app.",
      "version": "1.0.0",
      "updatedAt": "2026-02-27T00:00:00.000Z",
      "sections": [
        {
          "kind": "hero",
          "title": "Hybrid Modules",
          "subtitle": "Native core + cloud-updated UI logic",
          "body": "Ship robot-critical code natively while loading the rest from our control plane.",
          "payload": {"tag": "Default"}
        },
        {
          "kind": "text",
          "title": "Why it matters",
          "body": "We can update investor decks, compliance flows, or onboarding screens instantly without resubmitting to the stores."
        },
        {
          "kind": "bullets",
          "title": "Live surfaces",
          "bullets": [
            "Investor storytelling screens",
            "Safety briefings for race partners",
            "Per-customer branding blocks"
          ]
        }
      ]
    },
    {
      "id": "voice_modules",
      "title": "Voice + Alerting Story",
      "description": "Summarises the differentiators for collaborators.",
      "version": "1.0.0",
      "updatedAt": "2026-02-27T00:00:00.000Z",
      "sections": [
        {
          "kind": "hero",
          "title": "Voice + Public Alerting",
          "subtitle": "Hands-free safety + SMS broadcasts",
          "payload": {"tag": "Core"}
        },
        {
          "kind": "bullets",
          "title": "Highlights",
          "bullets": [
            "Owner-only STT commands (stop, pace, resume, alert)",
            "Robot speaker announces runner approaching",
            "SMS to saved contacts with ETA + direction"
          ]
        }
      ]
    }
  ]
}
''';
