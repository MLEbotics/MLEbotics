import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import '../services/music_service.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with TickerProviderStateMixin {
  final MusicService _music = MusicService.instance;
  late AnimationController _rotationController;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<MusicTrack?>? _trackSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  MusicTrack? _currentTrack;
  double _volume = 0.8;

  // For "add stream URL" dialog
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    // Load default tracks if empty
    _music.loadDefaultTracks();

    _currentTrack = _music.currentTrack;
    _playing = _music.isPlaying;
    _position = _music.position;
    _duration = _music.duration ?? Duration.zero;

    if (_playing) _rotationController.repeat();

    _trackSub = _music.currentTrackStream.listen((track) {
      if (mounted) setState(() => _currentTrack = track);
    });
    _playerStateSub = _music.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing =
            state.playing && state.processingState != ProcessingState.completed;
      });
      if (_playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });
    _positionSub = _music.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = _music.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _trackSub?.cancel();
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _addStreamUrl() async {
    _urlController.clear();
    _titleController.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Stream / URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Track name',
                hintText: 'e.g. My Running Mix',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Stream URL',
                hintText: 'https://…/stream.mp3',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: paste a Spotify / YouTube share link\nor any direct .mp3 / .ogg stream URL.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
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
    if (ok == true &&
        _urlController.text.trim().isNotEmpty &&
        _titleController.text.trim().isNotEmpty) {
      _music.addStreamUrl(
        _titleController.text.trim(),
        _urlController.text.trim(),
      );
      setState(() {});
    }
  }

  Future<void> _addLocalFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      if (file.path != null && file.name.isNotEmpty) {
        _music.addLocalFile(
          file.name.replaceAll(RegExp(r'\.[^.]+$'), ''), // strip extension
          file.path!,
        );
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _music.playlist;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        title: const Text(
          'Music Player',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // BT speaker indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speaker, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'BT Speaker',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Now Playing ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Rotating disc
                RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFF1E3A5F), Color(0xFF0D47A1)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.music_note,
                      size: 72,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Track name
                Text(
                  _currentTrack?.title ?? 'No track selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _currentTrack?.isStream == true
                      ? '🌐 Live Stream'
                      : (_currentTrack != null ? '📁 Local File' : ''),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                // Progress bar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.teal,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.teal,
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: (_duration.inMilliseconds > 0)
                        ? (_position.inMilliseconds / _duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (_currentTrack?.isStream == true)
                        ? null
                        : (val) {
                            final target = Duration(
                              milliseconds: (val * _duration.inMilliseconds)
                                  .round(),
                            );
                            _music.seek(target);
                          },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(_position),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    Text(
                      (_currentTrack?.isStream == true)
                          ? 'LIVE'
                          : _fmt(_duration),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Playback controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _music.previous,
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white70,
                        size: 36,
                      ),
                    ),
                    GestureDetector(
                      onTap: _music.togglePlayPause,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.teal, Color(0xFF00ACC1)],
                          ),
                        ),
                        child: Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _music.next,
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white70,
                        size: 36,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Volume
                Row(
                  children: [
                    const Icon(Icons.volume_down, color: Colors.grey, size: 18),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.teal.shade300,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.teal,
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                        ),
                        child: Slider(
                          value: _volume,
                          onChanged: (v) {
                            setState(() => _volume = v);
                            _music.setVolume(v);
                          },
                        ),
                      ),
                    ),
                    const Icon(Icons.volume_up, color: Colors.grey, size: 18),
                  ],
                ),
              ],
            ),
          ),

          // ── Playlist ──────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF12122A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Playlist  (${playlist.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _addStreamUrl,
                              icon: const Icon(
                                Icons.wifi,
                                size: 16,
                                color: Colors.teal,
                              ),
                              label: const Text(
                                'URL',
                                style: TextStyle(color: Colors.teal),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addLocalFile,
                              icon: const Icon(
                                Icons.folder_open,
                                size: 16,
                                color: Colors.teal,
                              ),
                              label: const Text(
                                'File',
                                style: TextStyle(color: Colors.teal),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: playlist.isEmpty
                        ? const Center(
                            child: Text(
                              'No tracks yet.\nAdd a stream URL or local file.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            itemCount: playlist.length,
                            itemBuilder: (ctx, i) {
                              final track = playlist[i];
                              final isCurrent =
                                  i ==
                                  _music.playlist.indexOf(
                                    _currentTrack ??
                                        const MusicTrack(title: '', source: ''),
                                  );
                              return ListTile(
                                leading: Icon(
                                  track.isStream
                                      ? Icons.wifi
                                      : Icons.audiotrack,
                                  color: isCurrent
                                      ? Colors.teal
                                      : Colors.white38,
                                ),
                                title: Text(
                                  track.title,
                                  style: TextStyle(
                                    color: isCurrent
                                        ? Colors.teal
                                        : Colors.white70,
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  track.isStream ? 'Stream' : 'Local',
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white30,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _music.removeAt(i);
                                    setState(() {});
                                  },
                                ),
                                onTap: () => _music.playAt(i),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
