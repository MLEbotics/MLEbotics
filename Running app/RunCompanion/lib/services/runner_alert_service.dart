import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// A person to be alerted when the runner is approaching.
class AlertContact {
  final String name;
  final String phone; // E.164 or local, e.g. +447911123456

  const AlertContact({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
  factory AlertContact.fromJson(Map<String, dynamic> j) =>
      AlertContact(name: j['name'] as String, phone: j['phone'] as String);
}

/// Manages the list of ahead-contacts and fires SMS alerts to all of them.
class RunnerAlertService {
  static final instance = RunnerAlertService._();
  RunnerAlertService._();

  static const _prefKey = 'runner_alert_contacts';

  List<AlertContact> _contacts = [];
  List<AlertContact> get contacts => List.unmodifiable(_contacts);

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _contacts = list
          .map((e) => AlertContact.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      jsonEncode(_contacts.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> addContact(AlertContact contact) async {
    _contacts.add(contact);
    await _save();
  }

  Future<void> removeAt(int index) async {
    _contacts.removeAt(index);
    await _save();
  }

  // ── Alert ─────────────────────────────────────────────────────────────────

  /// Sends an SMS alert to all contacts.
  /// [direction] is 'left', 'right', or null (generic "keep clear").
  /// Returns the number of contacts messaged.
  Future<int> sendAlert({
    double distanceKm = 0,
    double paceKmh = 0,
    String? direction,
    String? customMessage,
  }) async {
    if (_contacts.isEmpty) return 0;

    final etaMins = (paceKmh > 0 && distanceKm > 0)
        ? (distanceKm / paceKmh * 60).round()
        : null;

    final msg =
        customMessage ??
        _buildMessage(
          distanceKm: distanceKm,
          etaMins: etaMins,
          direction: direction,
        );

    int sent = 0;
    for (final contact in _contacts) {
      final number = contact.phone.replaceAll(RegExp(r'\s+'), '');
      // sms: URI opens the default SMS app pre-filled
      final uri = Uri(
        scheme: 'sms',
        path: number,
        queryParameters: {'body': msg},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        sent++;
      }
    }
    return sent;
  }

  String _buildMessage({
    double distanceKm = 0,
    int? etaMins,
    String? direction,
  }) {
    final parts = <String>['🏃 Runner approaching!'];
    if (distanceKm > 0) {
      parts.add('${distanceKm.toStringAsFixed(1)} km away');
    }
    if (etaMins != null && etaMins > 0) {
      parts.add('ETA ~$etaMins min');
    }
    if (direction == 'left') {
      // Runner passing on the left — people step aside to their right
      parts.add('On your left, please! 🙏 Runner coming through — thank you!');
    } else if (direction == 'right') {
      // Runner passing on the right — people step aside to their left
      parts.add('On your right, please! 🙏 Runner coming through — thank you!');
    } else {
      parts.add(
        'Excuse me! 🙏 Runner coming through, please make way — thank you so much!',
      );
    }
    parts.add('— RunBot 🤖');
    return parts.join(' • ');
  }
}
