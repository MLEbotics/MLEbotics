import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Records video from the robot's ESP32 camera during a run.
///
/// Architecture:
///   ESP32 camera → MJPEG stream (port 81) → Flutter parses JPEG frames
///   → writes raw concatenated JPEGs to temp file → after run, ffmpeg
///   encodes to MP4 → saved to phone gallery.
///
/// Start recording: [startRecording]
/// Stop and save:   [stopRecording]
/// Status updates:  listen to [statusStream]
class CameraRecordingService {
  // Robot's camera MJPEG endpoint (separate from control server on port 80)
  static const String _cameraUrl = 'http://runner-companion.local:81/camera';

  bool _isRecording = false;
  HttpClient? _httpClient;
  RandomAccessFile? _rawFile;
  String? _rawFramesPath; // temp file: concatenated raw JPEG bytes
  int _frameCount = 0;

  bool get isRecording => _isRecording;
  int get frameCount => _frameCount;

  final _statusController = StreamController<CameraRecordingStatus>.broadcast();
  Stream<CameraRecordingStatus> get statusStream => _statusController.stream;

  // ── Start ─────────────────────────────────────────────────────────────────

  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _rawFramesPath = '${tempDir.path}/run_frames_$timestamp.bin';

      final file = File(_rawFramesPath!);
      _rawFile = await file.open(mode: FileMode.write);
      _frameCount = 0;
      _isRecording = true;

      _emit(CameraRecordingStatus.recording(frames: 0));

      // Kick off the stream in the background — errors are surfaced via statusStream
      _streamMjpeg();
    } catch (e) {
      _isRecording = false;
      _emit(CameraRecordingStatus.error('Could not start: $e'));
    }
  }

  // ── MJPEG reader ──────────────────────────────────────────────────────────

  Future<void> _streamMjpeg() async {
    _httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(hours: 3);

    try {
      final request = await _httpClient!.getUrl(Uri.parse(_cameraUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        _isRecording = false;
        _emit(
          CameraRecordingStatus.error('Camera returned ${response.statusCode}'),
        );
        return;
      }

      // Parse raw bytes from the MJPEG multipart stream.
      // Strategy: scan for JPEG SOI (FF D8) → EOI (FF D9) markers.
      // This is more robust than parsing HTTP multipart headers.
      final List<int> buf = [];
      bool inJpeg = false;

      await for (final chunk in response) {
        if (!_isRecording) break;

        buf.addAll(chunk);

        // Extract as many complete frames as possible from the buffer
        while (true) {
          if (!inJpeg) {
            // Hunt for JPEG start-of-image marker
            int soi = _indexOf16(buf, 0xFF, 0xD8);
            if (soi < 0) {
              // Discard everything except the last byte (might be split marker)
              if (buf.length > 1) buf.removeRange(0, buf.length - 1);
              break;
            }
            if (soi > 0) buf.removeRange(0, soi); // discard pre-SOI garbage
            inJpeg = true;
          }

          if (inJpeg) {
            // Hunt for JPEG end-of-image marker starting after SOI
            int eoi = _indexOf16(buf, 0xFF, 0xD9, startFrom: 2);
            if (eoi < 0) break; // incomplete frame — wait for more data

            // Extract complete JPEG frame [0 .. eoi+1]
            final frameBytes = Uint8List.fromList(buf.sublist(0, eoi + 2));
            buf.removeRange(0, eoi + 2);
            inJpeg = false;

            // Write to temp file
            await _rawFile?.writeFrom(frameBytes);
            _frameCount++;

            // Update UI every 10 frames (~1 second at 10 fps)
            if (_frameCount % 10 == 0) {
              _emit(CameraRecordingStatus.recording(frames: _frameCount));
            }
          }
        }
      }
    } catch (e) {
      if (_isRecording) {
        _emit(CameraRecordingStatus.error('Stream error: $e'));
      }
    } finally {
      if (_isRecording) {
        // Stream ended unexpectedly — still try to save what we have
        await stopRecording();
      }
    }
  }

  // ── Stop + encode ─────────────────────────────────────────────────────────

  /// Stops the MJPEG stream, encodes collected frames to MP4, and saves
  /// the video to the phone's gallery.
  ///
  /// Returns the saved file path on success, null on failure.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;

    _emit(CameraRecordingStatus.saving(frames: _frameCount));

    // Close raw file first
    await _rawFile?.flush();
    await _rawFile?.close();
    _rawFile = null;

    // Kill HTTP connection
    _httpClient?.close(force: true);
    _httpClient = null;

    if (_frameCount < 5 || _rawFramesPath == null) {
      _emit(
        CameraRecordingStatus.error('Not enough footage ($frameCount frames)'),
      );
      _cleanup();
      return null;
    }

    return _encodeAndSave(_rawFramesPath!, _frameCount);
  }

  // ── Encode → gallery save ───────────────────────────────────────────────
  // Video encoding is not available in this build (ffmpeg_kit discontinued).

  Future<String?> _encodeAndSave(String rawPath, int frames) async {
    final duration = (frames / 10.0).toStringAsFixed(1);
    try { File(rawPath).deleteSync(); } catch (_) {}
    // TODO: re-enable MP4 encoding when a replacement for
    // ffmpeg_kit_flutter_min_gpl is available.
    _emit(CameraRecordingStatus.error(
      'Video encoding not available in this build ($frames frames, ${duration}s captured).',
    ));
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Find first occurrence of [b0, b1] in [buf] starting at [startFrom].
  /// Returns the index of [b0], or -1 if not found.
  int _indexOf16(List<int> buf, int b0, int b1, {int startFrom = 0}) {
    for (int i = startFrom; i < buf.length - 1; i++) {
      if (buf[i] == b0 && buf[i + 1] == b1) return i;
    }
    return -1;
  }

  void _cleanup() {
    if (_rawFramesPath != null) {
      try {
        File(_rawFramesPath!).deleteSync();
      } catch (_) {}
      _rawFramesPath = null;
    }
  }

  void _emit(CameraRecordingStatus status) {
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void dispose() {
    _isRecording = false;
    _httpClient?.close(force: true);
    _rawFile?.close();
    _cleanup();
    _statusController.close();
  }
}

// ── Status model ──────────────────────────────────────────────────────────────

enum CameraRecordingState { idle, recording, saving, saved, error }

class CameraRecordingStatus {
  final CameraRecordingState state;
  final int frames;
  final String duration; // e.g. "42.0" seconds
  final String message;

  const CameraRecordingStatus._({
    required this.state,
    this.frames = 0,
    this.duration = '',
    this.message = '',
  });

  factory CameraRecordingStatus.idle() =>
      const CameraRecordingStatus._(state: CameraRecordingState.idle);

  factory CameraRecordingStatus.recording({required int frames}) =>
      CameraRecordingStatus._(
        state: CameraRecordingState.recording,
        frames: frames,
        message: 'Recording… $frames frames',
      );

  factory CameraRecordingStatus.saving({required int frames}) =>
      CameraRecordingStatus._(
        state: CameraRecordingState.saving,
        frames: frames,
        message: 'Encoding $frames frames…',
      );

  factory CameraRecordingStatus.saved({
    required int frames,
    required String duration,
  }) => CameraRecordingStatus._(
    state: CameraRecordingState.saved,
    frames: frames,
    duration: duration,
    message: 'Saved to gallery (${duration}s, $frames frames)',
  );

  factory CameraRecordingStatus.error(String msg) =>
      CameraRecordingStatus._(state: CameraRecordingState.error, message: msg);

  @override
  String toString() => message;
}
