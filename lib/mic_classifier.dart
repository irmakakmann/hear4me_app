import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio_classifier.dart';
import 'labels.dart';

class MicClassifierPage extends StatefulWidget {
  const MicClassifierPage({super.key});
  @override
  State<MicClassifierPage> createState() => _MicClassifierPageState();
}

class _MicClassifierPageState extends State<MicClassifierPage> {
  // ---- classifier (unchanged) ----
  final _clf = AudioClassifier();

  // ---- phone mic (optional) ----
  final _cap = FlutterAudioCapture();

  // ---- BLE (Nordic UART) ----
  final _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  DiscoveredDevice? _watch;

  // NUS UUIDs (must match your .ino)
  final Uuid _nusService = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  final Uuid _nusRx     = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E"); // phone->watch (unused here)
  final Uuid _nusTx     = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E"); // watch->phone (notify)

  // ---- state ----
  bool _ready = false;
  bool _listening = false;
  bool _busy = false;
  bool _useWatch = true; // ← default to watch input
  Timer? _hopTimer;

  // Ring buffer for 16k, 1ch, PCM16
  final List<int> _mono16 = <int>[];
  int _deviceSampleRate = 16000; // watch sends 16k already

  // ui/debug
  int _chunks = 0;
  String _info = '';

  // results
  String? _label;
  double? _score;
  List<MapEntry<String, double>> _topK = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _stopListening();
    _teardownBle();
    super.dispose();
  }

  Future<void> _init() async {
    // Permissions:
    // - mic (if you still use phone mic path)
    // - BLE scan/connect (Android 12+), location for older Android
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // On older Android versions (SDK < 31) location is needed for BLE scans:
      Permission.location,
      // mic (for phone mic mode)
      Permission.microphone,
    ].request();

    try {
      await _cap.init(); // harmless even if you don't use phone mic
    } catch (_) {}

    await _clf.load();
    if (!mounted) return;
    setState(() => _ready = true);
  }

  // -------------------- BLE (NUS) --------------------

  Future<void> _connectWatchNus() async {
    // Scan for device named "ESP32_Audio" or advertising NUS service
    _watch = null;
    _scanSub?.cancel();
    _scanSub = _ble
        .scanForDevices(withServices: [_nusService], scanMode: ScanMode.lowLatency)
        .listen((d) {
      if (_watch != null) return;
      if (d.name == 'ESP32_Audio' || d.serviceUuids.contains(_nusService)) {
        _watch = d;
        _scanSub?.cancel();
      }
    });

    // Give scan a couple seconds (simple heuristic)
    await Future.delayed(const Duration(seconds: 3));
    await _scanSub?.cancel();

    if (_watch == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Watch not found')));
      }
      return;
    }

    // Connect
    _connSub?.cancel();
    final deviceId = _watch!.id;
    _connSub = _ble
        .connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 15))
        .listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
        // Request higher MTU (watch code uses 20 B, but no harm):
        try {
          await _ble.requestMtu(deviceId: deviceId, mtu: 247);
        } catch (_) {}

        // Subscribe to TX notifications
        final chr = QualifiedCharacteristic(
          deviceId: deviceId,
          serviceId: _nusService,
          characteristicId: _nusTx,
        );
        _notifySub?.cancel();
        _notifySub = _ble.subscribeToCharacteristic(chr).listen(_onNusPacket);

        if (mounted) {
          setState(() => _info = 'Watch connected');
        }
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        _notifySub?.cancel(); _notifySub = null;
        if (mounted) setState(() => _info = 'Watch disconnected');
      }
    });
  }

  void _onNusPacket(List<int> data) {
    if (data.length < 4) return;
    final len = data[2] | (data[3] << 8);
    if (len <= 0 || 4 + len > data.length) return;

    final payload = data.sublist(4, 4 + len); // raw PCM16LE
    final i16 = Int16List.view(
        Uint8List.fromList(payload).buffer, 0, len ~/ 2
    );
    _mono16.addAll(i16);
    if (_mono16.length > 80000) {
      _mono16.removeRange(0, _mono16.length - 80000);
    }

    _chunks++;
    if (_chunks % 10 == 0 && mounted) {
      _info = 'watch pkts=$_chunks buf=${_mono16.length}';
      setState(() {});
    }
  }


  Future<void> _teardownBle() async {
    await _notifySub?.cancel(); _notifySub = null;
    await _connSub?.cancel();   _connSub = null;
    await _scanSub?.cancel();   _scanSub = null;
  }

  // -------------------- Control --------------------

  Future<void> _startListening() async {
    if (!_ready || _listening) return;

    if (_useWatch) {
      await _connectWatchNus();
      _deviceSampleRate = 16000; // TTGO firmware sends 16 kHz PCM16
      _startLoop();
      setState(() => _listening = true);
      return;
    }

    // Fallback: phone mic path (unchanged)
    const requestedRate = 16000;

    void onError(Object e) {
      debugPrint('[AUDIO] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Audio error: $e')));
      }
      _stopListening();
    }

    void onAudio(dynamic obj) {
      final f32 = (obj is Float32List)
          ? obj
          : Float32List.fromList((obj as List).cast<double>());

      // If your phone delivers 48k, you can resample here (we used a linear resampler earlier).
      // For simplicity, assume 16k:
      final i16 = Int16List(f32.length);
      for (var i = 0; i < f32.length; i++) {
        final s = (f32[i] * 32767.0).clamp(-32768.0, 32767.0);
        i16[i] = s.toInt();
      }
      _mono16.addAll(i16);
      if (_mono16.length > 80000) {
        _mono16.removeRange(0, _mono16.length - 80000);
      }

      _chunks++;
      if (_chunks % 10 == 0 && mounted) {
        _info = 'phone chunks=$_chunks';
        setState(() {});
      }
    }

    try {
      await _cap.start(
        onAudio, onError,
        sampleRate: requestedRate,
        bufferSize: 4096,
      );
      _deviceSampleRate = 16000;
      _startLoop();
      setState(() => _listening = true);
    } catch (e) {
      debugPrint('[AUDIO] Start failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Start mic failed: $e')));
      }
      _stopListening();
    }
  }

  void _startLoop() {
    _hopTimer?.cancel();
    _hopTimer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      if (_busy) return;
      _busy = true;
      try {
        _classifyLatestWindow();
      } finally {
        _busy = false;
      }
    });
  }

  Future<void> _stopListening() async {
    _hopTimer?.cancel();
    _hopTimer = null;

    if (_useWatch) {
      await _teardownBle();
    } else {
      try { await _cap.stop(); } catch (_) {}
    }

    if (mounted) setState(() => _listening = false);
  }

  void _classifyLatestWindow() {
    const win = 16000;
    if (_mono16.length < win) return;

    final frame = _mono16.sublist(_mono16.length - win);

    // Silence gate helps avoid random flips
    final rms = math.sqrt(frame.fold<double>(0, (a, x) => a + (x * x)) / frame.length);
    if (rms < 60) return;

    final res = _clf.infer(frame);
    final probs = (res['probs'] as Map<String, double>);

    // If you hard-banned "Speech" in the classifier, skip this filter.
    final entries = probs.entries
        .where((e) => e.key != 'Speech') // ignore Speech for display/alerts
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return;

    final top = entries.first;
    if (top.value < 0.18) return;

    setState(() {
      _label = top.key;
      _score = top.value;
      _topK = entries.take(5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Audio (Watch → Phone)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_ready ? 'Model loaded ✅' : 'Loading model…'),
          const SizedBox(height: 12),
          Row(children: [
            Switch(
              value: _useWatch,
              onChanged: _listening ? null : (v) => setState(() => _useWatch = v),
            ),
            const Text('Use watch mic'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton(
              onPressed: _ready && !_listening ? _startListening : null,
              child: const Text('Start'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _listening ? _stopListening : null,
              child: const Text('Stop'),
            ),
          ]),
          const SizedBox(height: 12),
          Text(_info, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          if (_label != null) ...[
            Text('Top: $_label', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Score: ${_score?.toStringAsFixed(3)}'),
            const SizedBox(height: 12),
            const Text('Top-5', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._topK.map((e) => Text('${e.key}: ${e.value.toStringAsFixed(3)}')),
          ] else
            const Text('Waiting for audio…'),
          const Spacer(),
          Text('Labels (${soundLabels.length}): ${soundLabels.take(6).join(", ")}…',
              style: const TextStyle(color: Colors.grey)),
        ]),
      ),
    );
  }
}
