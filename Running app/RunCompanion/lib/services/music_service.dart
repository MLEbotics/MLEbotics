import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

/// A track in the playlist.
class MusicTrack {
  final String title;
  final String source; // URL or file path
  final bool isStream; // true = internet radio / HTTP stream

  const MusicTrack({
    required this.title,
    required this.source,
    this.isStream = false,
  });
}

/// Singleton music service wrapping just_audio.
/// Plays through whatever output is active (phone speaker or BT speaker on robot).
class MusicService {
  static final MusicService instance = MusicService._();
  MusicService._();

  final AudioPlayer _player = AudioPlayer();
  final List<MusicTrack> _playlist = [];
  int _currentIndex = -1;

  // Observable state
  final StreamController<MusicTrack?> _currentTrackController =
      StreamController<MusicTrack?>.broadcast();
  Stream<MusicTrack?> get currentTrackStream => _currentTrackController.stream;
  MusicTrack? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _playlist.length
      ? _playlist[_currentIndex]
      : null;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  List<MusicTrack> get playlist => List.unmodifiable(_playlist);

  /// Initialise audio session (ducking, background, etc.)
  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Auto-advance to next track at end
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        next();
      }
    });
  }

  /// Add a streaming URL (internet radio, YouTube Music share link, etc.)
  void addStreamUrl(String title, String url) {
    _playlist.add(MusicTrack(title: title, source: url, isStream: true));
  }

  /// Add a local file path.
  void addLocalFile(String title, String path) {
    _playlist.add(MusicTrack(title: title, source: path));
  }

  /// Remove a track by index.
  void removeAt(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _playlist.removeAt(index);
    if (_currentIndex >= _playlist.length) {
      _currentIndex = _playlist.length - 1;
    }
    _currentTrackController.add(currentTrack);
  }

  /// Clear playlist.
  void clearPlaylist() {
    _playlist.clear();
    _currentIndex = -1;
    _currentTrackController.add(null);
    _player.stop();
  }

  /// Play a specific track index.
  Future<void> playAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    final track = _playlist[index];
    _currentTrackController.add(track);

    try {
      AudioSource source;
      if (track.isStream || track.source.startsWith('http')) {
        source = AudioSource.uri(Uri.parse(track.source));
      } else {
        source = AudioSource.file(track.source);
      }
      await _player.setAudioSource(source);
      await _player.play();
    } catch (e) {
      // Ignore playback errors silently — stream may be unavailable
    }
  }

  /// Play / resume.
  Future<void> play() async {
    if (_currentIndex < 0 && _playlist.isNotEmpty) {
      await playAt(0);
    } else {
      await _player.play();
    }
  }

  /// Pause.
  Future<void> pause() async => _player.pause();

  /// Toggle play/pause.
  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// Skip to next track.
  Future<void> next() async {
    if (_playlist.isEmpty) return;
    final next = (_currentIndex + 1) % _playlist.length;
    await playAt(next);
  }

  /// Go back to previous track (or restart if > 3 s in).
  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    if (_player.position.inSeconds > 3 || _currentIndex <= 0) {
      await _player.seek(Duration.zero);
      await _player.play();
    } else {
      await playAt(_currentIndex - 1);
    }
  }

  /// Set volume (0.0 – 1.0).
  Future<void> setVolume(double volume) async =>
      _player.setVolume(volume.clamp(0.0, 1.0));

  double get volume => _player.volume;

  /// Seek to position.
  Future<void> seek(Duration position) async => _player.seek(position);

  Future<void> dispose() async {
    await _player.dispose();
    await _currentTrackController.close();
  }

  // ── Default starter tracks ──────────────────────────────────────────────────
  /// Populate with a few free running-friendly stream URLs so the app works
  /// out of the box.  Replace with the runner's own music later.
  void loadDefaultTracks() {
    if (_playlist.isNotEmpty) return;
    // DI.FM Trance (free stream) — great running tempo
    addStreamUrl(
      'Di.FM – Trance Radio',
      'https://streams.ilovemusic.de/iloveradio17.mp3',
    );
    // Absolute Radio – Rock
    addStreamUrl(
      'Absolute Radio (Rock)',
      'https://icecast.thisisdax.com/AbsoluteRadioMP3',
    );
    // SomaFM – Groove Salad (ambient beats)
    addStreamUrl(
      'SomaFM – Groove Salad',
      'https://ice1.somafm.com/groovesalad-128-mp3',
    );
  }
}
