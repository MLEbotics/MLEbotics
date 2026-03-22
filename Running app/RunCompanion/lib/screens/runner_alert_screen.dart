import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/runner_alert_service.dart';
import '../services/voice_service.dart';

/// Screen for managing "runner approaching" alert contacts and firing alerts.
///
/// Contacts are people ahead on the route (spectators, crew, checkpoint
/// marshals, friends at the finish). When the runner taps "Alert Now", every
/// contact gets an SMS saying the runner is on their way + estimated ETA.
/// The robot's BT speaker simultaneously announces it aloud.
class RunnerAlertScreen extends StatefulWidget {
  /// If provided, used to calculate ETA in the SMS body.
  final double distanceKm;
  final double paceKmh;

  const RunnerAlertScreen({super.key, this.distanceKm = 0, this.paceKmh = 0});

  @override
  State<RunnerAlertScreen> createState() => _RunnerAlertScreenState();
}

class _RunnerAlertScreenState extends State<RunnerAlertScreen> {
  final _alertService = RunnerAlertService.instance;
  final _voiceService = VoiceService();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _alertService.load().then((_) {
      if (mounted) setState(() => _loading = false);
    });
    _voiceService.init();
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _addContact() async {
    String name = '';
    String phone = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This person will receive an SMS when you tap "Alert Ahead".',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Spectator at 5 km mark',
                prefixIcon: Icon(Icons.person),
              ),
              onChanged: (v) => name = v,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: 'e.g. +447911123456',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              onChanged: (v) => phone = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok == true && name.trim().isNotEmpty && phone.trim().isNotEmpty) {
      await _alertService.addContact(
        AlertContact(name: name.trim(), phone: phone.trim()),
      );
      setState(() {});
    }
  }

  Future<void> _sendAlert() async {
    setState(() => _sending = true);

    // 1. Speak through the BT speaker on the robot
    await _voiceService.speak(
      'Attention: runner approaching! Please keep the route clear. Thank you!',
    );

    // 2. SMS all contacts
    final sent = await _alertService.sendAlert(
      distanceKm: widget.distanceKm,
      paceKmh: widget.paceKmh,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent > 0
              ? '✅ Alert sent to $sent contact${sent == 1 ? '' : 's'}'
              : _alertService.contacts.isEmpty
              ? 'No contacts added yet — add people below.'
              : 'Could not open SMS app.',
        ),
        backgroundColor: sent > 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _alertService.contacts;
    final etaMins = (widget.paceKmh > 0 && widget.distanceKm > 0)
        ? (widget.distanceKm / widget.paceKmh * 60).round()
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1E),
        foregroundColor: Colors.white,
        title: const Text(
          'Alert Ahead',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.tealAccent),
            tooltip: 'Add contact',
            onPressed: _addContact,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Alert banner ────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.campaign, color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        'Runner Approaching Alert',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contacts.isEmpty
                            ? 'Add contacts below first'
                            : '${contacts.length} contact${contacts.length == 1 ? '' : 's'} will be alerted by SMS',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      if (widget.distanceKm > 0 || etaMins != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            [
                              if (widget.distanceKm > 0)
                                '${widget.distanceKm.toStringAsFixed(1)} km away',
                              if (etaMins != null && etaMins > 0)
                                'ETA ~$etaMins min',
                            ].join('  •  '),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _sending ? null : _sendAlert,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.red,
                                  ),
                                )
                              : const Icon(Icons.campaign),
                          label: Text(
                            _sending
                                ? 'Alerting…'
                                : '🔔  Alert All Contacts Now',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Also announces on robot BT speaker:\n"Runner approaching! Please keep the route clear."',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // ── Contact list ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Contacts (${contacts.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addContact,
                        icon: const Icon(
                          Icons.add,
                          color: Colors.tealAccent,
                          size: 18,
                        ),
                        label: const Text(
                          'Add',
                          style: TextStyle(color: Colors.tealAccent),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: contacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.people_outline,
                                size: 56,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No contacts yet.',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add spectators, marshals or crew\nwho are ahead on the route.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _addContact,
                                icon: const Icon(Icons.person_add),
                                label: const Text('Add First Contact'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: contacts.length,
                          itemBuilder: (ctx, i) {
                            final c = contacts[i];
                            return Dismissible(
                              key: ValueKey('${c.name}${c.phone}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.red.shade900,
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) async {
                                await _alertService.removeAt(i);
                                setState(() {});
                              },
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal.withOpacity(0.2),
                                  child: Text(
                                    c.name.isNotEmpty
                                        ? c.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  c.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  c.phone,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Quick single-contact alert
                                    IconButton(
                                      icon: const Icon(
                                        Icons.send,
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                      tooltip: 'Alert this contact',
                                      onPressed: () async {
                                        final tempService =
                                            RunnerAlertService.instance;
                                        final singleContacts = [c];
                                        for (final contact in singleContacts) {
                                          final number = contact.phone
                                              .replaceAll(RegExp(r'\s+'), '');
                                          final msg =
                                              'Excuse me! 🙏 Runner coming through, please make way — thank you so much! — RunBot 🤖';
                                          final uri = Uri(
                                            scheme: 'sms',
                                            path: number,
                                            queryParameters: {'body': msg},
                                          );
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri);
                                          }
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      tooltip: 'Remove',
                                      onPressed: () async {
                                        await _alertService.removeAt(i);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
