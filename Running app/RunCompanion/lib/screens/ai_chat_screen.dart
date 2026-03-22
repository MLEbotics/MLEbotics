import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';

// ── AI Chat Screen ────────────────────────────────────────────────────────────
// Full conversational screen — text + voice in/out.
// Works mid-run: supply WorkoutContext so Gemini knows live stats.

class AiChatScreen extends StatefulWidget {
  final WorkoutContext? workoutContext;

  const AiChatScreen({super.key, this.workoutContext});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final _aiService = AiService();
  final _voiceService = VoiceService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<ChatMessage> _messages = [];
  bool _loading = false;
  final bool _voiceMode = false; // toggle TTS read-aloud
  bool _listening = false;
  bool _speakReplies = true; // speak AI replies out loud
  bool _apiKeyMissing = false;

  late AnimationController _micPulse;

  @override
  void initState() {
    super.initState();
    _micPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _init();
  }

  Future<void> _init() async {
    await Future.wait([_aiService.init(), _voiceService.init()]);
    final key = await _aiService.getApiKey();
    if (mounted) {
      setState(() => _apiKeyMissing = key == null || key.isEmpty);
    }

    // Welcome message
    if (!_apiKeyMissing) {
      _addMessage(
        "Hey! I'm RunBot 🤖🏃 — your AI running companion. Ask me anything:"
        " workout status, pacing advice, nutrition, or just chat!\n"
        "Tip: tap 🎤 to talk to me hands-free.",
        isUser: false,
      );
    }
  }

  @override
  void dispose() {
    _micPulse.dispose();
    _voiceService.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addMessage(String text, {required bool isUser}) {
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: isUser, time: DateTime.now()),
      );
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _textCtrl.clear();
    _addMessage(trimmed, isUser: true);
    setState(() => _loading = true);

    final reply = await _aiService.chat(
      trimmed,
      context: widget.workoutContext,
    );

    setState(() => _loading = false);
    _addMessage(reply, isUser: false);

    // Speak reply if enabled
    if (_speakReplies) {
      await _voiceService.speak(reply);
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _voiceService.stopListening();
      setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);

    final ok = await _voiceService.startListening(
      onCommand: (_) {}, // commands handled in pace screen; here just chat
      onTranscript: (text) {
        setState(() => _listening = false);
        if (text.isNotEmpty) _send(text);
      },
    );

    if (!ok && mounted) {
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone not available on this device/browser.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showApiKeyDialog() async {
    final ctrl = TextEditingController(
      text: await _aiService.getApiKey() ?? '',
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Gemini API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get a free API key from Google AI Studio (aistudio.google.com)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
            onPressed: () async {
              await _aiService.setApiKey(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() => _apiKeyMissing = ctrl.text.trim().isEmpty);
                if (!_apiKeyMissing && _messages.isEmpty) {
                  _addMessage(
                    "Hey! I'm RunBot 🤖🏃 — your AI running companion. Ask me anything!\n"
                    "Tap 🎤 to talk to me hands-free.",
                    isUser: false,
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.smart_toy, size: 22),
            SizedBox(width: 8),
            Text('RunBot AI'),
          ],
        ),
        actions: [
          // Speak toggle
          Tooltip(
            message: _speakReplies
                ? 'Mute voice replies'
                : 'Enable voice replies',
            child: IconButton(
              icon: Icon(
                _speakReplies ? Icons.volume_up : Icons.volume_off,
                color: _speakReplies ? Colors.greenAccent : Colors.white38,
              ),
              onPressed: () => setState(() => _speakReplies = !_speakReplies),
            ),
          ),
          // New conversation
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Start new conversation',
            onPressed: () {
              _aiService.resetChat();
              setState(() => _messages.clear());
              _addMessage(
                "New conversation started! What can I help you with?",
                isUser: false,
              );
            },
          ),
          // API key
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: 'Gemini API Key',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Live workout context banner ───────────────────────────
          if (widget.workoutContext != null && widget.workoutContext!.isRunning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.teal.shade700,
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_run,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live: ${widget.workoutContext!.elapsed.inMinutes}m  '
                    '${widget.workoutContext!.distanceKm.toStringAsFixed(2)}km  '
                    '${widget.workoutContext!.paceKmh.toStringAsFixed(1)}km/h'
                    '${widget.workoutContext!.heartRate > 0 ? '  ❤ ${widget.workoutContext!.heartRate}bpm' : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),

          // ── API key missing banner ────────────────────────────────
          if (_apiKeyMissing)
            GestureDetector(
              onTap: _showApiKeyDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: Colors.orange.shade700,
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap here to add your free Gemini API key to enable AI chat.',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),

          // ── Message list ──────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (_, i) {
                if (_loading && i == _messages.length) {
                  return _TypingBubble();
                }
                final msg = _messages[i];
                return _MessageBubble(message: msg);
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Mic button
                AnimatedBuilder(
                  animation: _micPulse,
                  builder: (_, child) => Transform.scale(
                    scale: _listening ? 1.0 + _micPulse.value * 0.15 : 1.0,
                    child: child,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _listening
                          ? Colors.red.withValues(alpha: 0.15)
                          : const Color(0xFF1A237E).withValues(alpha: 0.1),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _listening ? Icons.mic : Icons.mic_none,
                        color: _listening
                            ? Colors.red
                            : const Color(0xFF1A237E),
                      ),
                      tooltip: _listening
                          ? 'Stop listening'
                          : 'Speak to RunBot',
                      onPressed: _toggleListening,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Text field
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: _listening
                          ? 'Listening…'
                          : 'Ask RunBot anything…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF0F2F5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 6),
                // Send button
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF0288D1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => _send(_textCtrl.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1A237E),
              child: const Icon(Icons.smart_toy, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1A237E) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal.shade100,
              child: const Icon(Icons.person, size: 16, color: Colors.teal),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF1A237E),
            child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 7,
                    height: 7 + _ctrl.value * 4 * ((i + 1) / 3),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        Colors.grey.shade300,
                        const Color(0xFF1A237E),
                        _ctrl.value,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
