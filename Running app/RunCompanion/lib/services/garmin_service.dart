import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ── BLE GATT UUIDs ────────────────────────────────────────────────────────────
// Heart Rate Service
const _hrServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
const _hrMeasurementUuid = '00002a37-0000-1000-8000-00805f9b34fb';

// Running Speed & Cadence Service
const _rscServiceUuid = '00001814-0000-1000-8000-00805f9b34fb';
const _rscMeasurementUuid = '00002a53-0000-1000-8000-00805f9b34fb';

// ── Data model ────────────────────────────────────────────────────────────────
class GarminData {
  final int heartRate; // bpm
  final int cadence; // steps/min
  final double speedKmh; // km/h
  final double distanceKm; // total since connect
  final bool connected;

  const GarminData({
    this.heartRate = 0,
    this.cadence = 0,
    this.speedKmh = 0,
    this.distanceKm = 0,
    this.connected = false,
  });

  GarminData copyWith({
    int? heartRate,
    int? cadence,
    double? speedKmh,
    double? distanceKm,
    bool? connected,
  }) => GarminData(
    heartRate: heartRate ?? this.heartRate,
    cadence: cadence ?? this.cadence,
    speedKmh: speedKmh ?? this.speedKmh,
    distanceKm: distanceKm ?? this.distanceKm,
    connected: connected ?? this.connected,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────
class GarminService {
  // Public reactive data stream
  final _dataController = StreamController<GarminData>.broadcast();
  Stream<GarminData> get dataStream => _dataController.stream;

  GarminData _current = const GarminData();
  BluetoothDevice? _device;
  final List<StreamSubscription> _subs = [];

  bool get isConnected => _current.connected;
  GarminData get current => _current;

  // Garmin watch name patterns to match during scan
  static const _garminPatterns = [
    'garmin',
    'forerunner',
    'fenix',
    'vivoactive',
    'venu',
    'instinct',
    'edge',
    'epix',
  ];

  // ── Scanning ──────────────────────────────────────────────────────────────

  /// Scan for Garmin devices and return the first one found (or null if timeout)
  Future<BluetoothDevice?> scanForGarmin({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // BLE not available on web
    if (kIsWeb) return null;

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      final foundDevice = await FlutterBluePlus.onScanResults
          .firstWhere((results) => results.any(_isGarmin), orElse: () => [])
          .timeout(timeout, onTimeout: () => []);

      await FlutterBluePlus.stopScan();

      final match = foundDevice.firstWhere(
        _isGarmin,
        orElse: () => foundDevice.first, // unreachable but type-safe
      );
      return match.device;
    } catch (_) {
      await FlutterBluePlus.stopScan();
      return null;
    }
  }

  bool _isGarmin(ScanResult r) {
    final name = r.device.platformName.toLowerCase();
    return _garminPatterns.any((p) => name.contains(p));
  }

  // ── Connect ───────────────────────────────────────────────────────────────

  Future<bool> connectTo(BluetoothDevice device) async {
    if (kIsWeb) return false;
    try {
      _device = device;
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 12),
      );

      // Listen for disconnection
      _subs.add(
        device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            _emit(_current.copyWith(connected: false));
          }
        }),
      );

      final services = await device.discoverServices();
      bool anySubscribed = false;

      for (final service in services) {
        final uuid = service.serviceUuid.toString().toLowerCase();

        if (uuid.contains('180d')) {
          // Heart Rate
          for (final c in service.characteristics) {
            if (c.characteristicUuid.toString().toLowerCase().contains(
              '2a37',
            )) {
              await c.setNotifyValue(true);
              _subs.add(c.onValueReceived.listen(_parseHr));
              anySubscribed = true;
            }
          }
        }

        if (uuid.contains('1814')) {
          // Running Speed & Cadence
          for (final c in service.characteristics) {
            if (c.characteristicUuid.toString().toLowerCase().contains(
              '2a53',
            )) {
              await c.setNotifyValue(true);
              _subs.add(c.onValueReceived.listen(_parseRsc));
              anySubscribed = true;
            }
          }
        }
      }

      _emit(_current.copyWith(connected: true));
      return anySubscribed;
    } catch (e) {
      debugPrint('GarminService connect error: $e');
      return false;
    }
  }

  /// Scan and auto-connect to the first Garmin device found
  Future<bool> autoConnect() async {
    if (kIsWeb) return false;
    final device = await scanForGarmin();
    if (device == null) return false;
    return connectTo(device);
  }

  // ── Disconnect ────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _device?.disconnect();
    _device = null;
    _emit(const GarminData(connected: false));
  }

  void dispose() {
    disconnect();
    _dataController.close();
  }

  // ── BLE parsers ───────────────────────────────────────────────────────────

  // Heart Rate Measurement (0x2A37)
  // Byte 0: flags  — bit0: HR format (0=uint8, 1=uint16)
  void _parseHr(List<int> bytes) {
    if (bytes.isEmpty) return;
    final flags = bytes[0];
    final hrFormat = flags & 0x01;
    final hr = hrFormat == 0 ? bytes[1] : (bytes[1] + (bytes[2] << 8));
    _emit(_current.copyWith(heartRate: hr));
  }

  // RSC Measurement (0x2A53)
  // Byte 0: flags — bit0: stride length present, bit1: total distance present
  // Bytes 1-2:  Instantaneous Speed (uint16, units: 1/256 m/s)
  // Byte 3:     Instantaneous Cadence (uint8, rpm = strides/min)
  // Bytes 4-5:  Stride Length (uint16, cm) — if flag bit0 set
  // Bytes 6-9:  Total Distance (uint32, dm) — if flag bit1 set
  void _parseRsc(List<int> bytes) {
    if (bytes.length < 4) return;
    final flags = bytes[0];

    final rawSpeed = bytes[1] | (bytes[2] << 8);
    final speedMs = rawSpeed / 256.0;
    final speedKmh = speedMs * 3.6;

    final cadence = bytes[3] * 2; // strides/min → steps/min (×2)

    double distKm = _current.distanceKm;
    if ((flags & 0x02) != 0 && bytes.length >= 10) {
      final rawDist =
          bytes[6] | (bytes[7] << 8) | (bytes[8] << 16) | (bytes[9] << 24);
      distKm = rawDist / 10000.0; // dm → km
    }

    _emit(
      _current.copyWith(
        speedKmh: speedKmh,
        cadence: cadence,
        distanceKm: distKm,
      ),
    );
  }

  void _emit(GarminData data) {
    _current = data;
    if (!_dataController.isClosed) _dataController.add(data);
  }
}
