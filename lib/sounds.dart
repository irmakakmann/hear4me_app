// lib/sounds.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio_classifier.dart';
import 'labels.dart';

class SoundsScreen extends StatefulWidget {
  const SoundsScreen({super.key});
  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> {
  // ---- Classifier & capture (UNCHANGED behavior) ----
  final _clf = AudioClassifier();
  final _cap = FlutterAudioCapture();

  // BLE (Nordic UART) for the watch
  final _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  DiscoveredDevice? _watch;

  // Nordic UART UUIDs (must match watch firmware)
  final Uuid _nusService = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  final Uuid _nusTx     = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

  // State
  bool _ready = false;
  bool _listening = false;
  bool _busy = false;
  bool _useWatch = true;      // toggle watch mic / phone mic

  // Buffer of latest PCM16 @16k
  final List<int> _mono16 = <int>[];
  Timer? _hopTimer;
  int _pkts = 0;
  String _status = 'idle';

  // Live results
  String? _label;
  double? _score;
  List<MapEntry<String, double>> _topK = const [];

  // ---- Your existing profile toggles ----
  bool doorbellEnabled = true;
  bool smokeAlarmEnabled = true;
  bool phoneRingEnabled = true;
  bool carHornEnabled = true;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  @override
  void dispose() {
    _stopListening();
    _notifySub?.cancel();
    _connSub?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _initAll() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,   // some Androids require this to scan
      Permission.microphone,
    ].request();

    try { await _cap.init(); } catch (_) {}

    // IMPORTANT: we’re not changing your classifier at all
    await _clf.load();

    if (!mounted) return;
    setState(() => _ready = true);
  }

  // -------------------- BLE watch connect --------------------
  Future<void> _connectWatchNus() async {
    _watch = null;
    setState(() => _status = 'scanning…');

    _scanSub?.cancel();
    _scanSub = _ble
        .scanForDevices(withServices: [_nusService], scanMode: ScanMode.lowLatency)
        .listen((d) {
      if (_watch == null &&
          (d.name == 'ESP32_Audio' || d.serviceUuids.contains(_nusService))) {
        _watch = d;
        _scanSub?.cancel();
      }
    });

    await Future.delayed(const Duration(seconds: 3));
    await _scanSub?.cancel();

    if (_watch == null) {
      setState(() => _status = 'watch not found');
      return;
    }

    setState(() => _status = 'connecting…');
    final deviceId = _watch!.id;

    _connSub?.cancel();
    _connSub = _ble
        .connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 15))
        .listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
        try { await _ble.requestMtu(deviceId: deviceId, mtu: 247); } catch (_) {}
        final chr = QualifiedCharacteristic(
          deviceId: deviceId,
          serviceId: _nusService,
          characteristicId: _nusTx,
        );
        _notifySub?.cancel();
        _notifySub = _ble.subscribeToCharacteristic(chr).listen(_onNusPacket);
        setState(() => _status = 'connected');
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        setState(() => _status = 'disconnected');
      }
    });
  }

  // ---- Supports BOTH legacy 20-byte packets and new big-packet format ----
  void _onNusPacket(List<int> data) {
    if (data.isEmpty) return;

    if (data.length == 20) {
      // LEGACY: 20-byte pkt = [seq_lo, seq_hi] + 18B payload = 9 samples (PCM16LE)
      final payload = data.sublist(2, 20);
      if (payload.length != 18) return;
      final i16 = Int16List(9);
      for (int i = 0; i < 9; i++) {
        final lo = payload[2 * i];
        final hi = payload[2 * i + 1];
        int v = (hi << 8) | lo;           // little-endian
        if (v >= 0x8000) v -= 0x10000;    // sign-correct to int16
        i16[i] = v;
      }
      _mono16.addAll(i16);
    } else if (data.length >= 4) {
      // NEW: big-packet = [seq_lo, seq_hi, len_lo, len_hi] + payload (PCM16LE)
      final len = data[2] | (data[3] << 8);
      if (len > 0 && 4 + len <= data.length) {
        final payload = data.sublist(4, 4 + len);
        // interpret payload bytes as little-endian int16
        final i16 = Int16List.view(Uint8List.fromList(payload).buffer, 0, len ~/ 2);
        _mono16.addAll(i16);
      }
    } else {
      // Unknown format → ignore
      return;
    }

    if (_mono16.length > 80000) {
      _mono16.removeRange(0, _mono16.length - 80000);
    }

    _pkts++;
    if (_pkts % 10 == 0 && mounted) {
      setState(() => _status = 'pkts=$_pkts buf=${_mono16.length}');
    }
  }

  // -------------------- Start/Stop --------------------
  Future<void> _startListening() async {
    if (!_ready || _listening) return;

    _mono16.clear();
    _pkts = 0;

    if (_useWatch) {
      await _connectWatchNus();
      _startLoop();
      setState(() => _listening = true);
      return;
    }

    // Phone mic path (same as before)
    const requestedRate = 16000;

    void onError(Object e) {
      setState(() => _status = 'audio error: $e');
      _stopListening();
    }

    void onAudio(dynamic obj) {
      final f32 = (obj is Float32List)
          ? obj
          : Float32List.fromList((obj as List).cast<double>());
      final i16 = Int16List(f32.length);
      for (var i = 0; i < f32.length; i++) {
        final s = (f32[i] * 32767.0).clamp(-32768.0, 32767.0);
        i16[i] = s.toInt();
      }
      _mono16.addAll(i16);
      if (_mono16.length > 80000) {
        _mono16.removeRange(0, _mono16.length - 80000);
      }
      _pkts++;
      if (_pkts % 10 == 0 && mounted) {
        setState(() => _status = 'phone chunks=$_pkts');
      }
    }

    try {
      await _cap.start(onAudio, onError, sampleRate: requestedRate, bufferSize: 4096);
      _startLoop();
      setState(() => _listening = true);
    } catch (e) {
      setState(() => _status = 'mic start failed: $e');
      _stopListening();
    }
  }

  void _startLoop() {
    _hopTimer?.cancel();
    // same cadence you had before (don’t change the classifier)
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

    try { await _notifySub?.cancel(); } catch (_) {}
    try { await _connSub?.cancel(); }   catch (_) {}
    try { await _scanSub?.cancel(); }   catch (_) {}
    _notifySub = null; _connSub = null; _scanSub = null;

    try { await _cap.stop(); } catch (_) {}

    if (!mounted) return;
    setState(() => _listening = false);
  }

  void _classifyLatestWindow() {
    const win = 16000; // 1 second @16k
    if (_mono16.length < win) return;

    // last 1s frame — no extra gating or reweighting
    final frame = _mono16.sublist(_mono16.length - win);

    final res = _clf.infer(frame);
    final probs = (res['probs'] as Map<String, double>);

    final entries = probs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = entries.isNotEmpty ? entries.first : null;
    if (top == null) return;

    setState(() {
      _label = top.key;
      _score = top.value;
      _topK = entries.take(5).toList();
    });
  }

  // -------------------- Your UI helpers (profiles & alerts) --------------------
  Widget _buildSoundProfileToggle({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String pattern,
    required bool isEnabled,
    required Function(bool) onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24.0)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.graphic_eq, size: 12, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(pattern, style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
          ),
          Switch(
            value: isEnabled,
            onChanged: (v) => onToggle(v),
            activeColor: Colors.white,
            activeTrackColor: Colors.green,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem({
    required String title,
    required String time,
    required String decibels,
    required String priority,
    required Color iconColor,
    required IconData icon,
  }) {
    final priorityColor = priority == 'High'
        ? Colors.orange
        : priority == 'Medium'
        ? Colors.blue
        : Colors.green;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12.0),
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8.0)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text(time, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.volume_up, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(decibels, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16.0)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning, size: 14, color: priorityColor),
              const SizedBox(width: 4),
              Text(priority, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: priorityColor)),
            ]),
          ),
        ],
      ),
    );
  }

  // -------------------- BUILD --------------------
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Live Listening card =====
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.graphic_eq),
                  const SizedBox(width: 8),
                  const Text('Live Listening',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Switch(
                    value: _useWatch,
                    onChanged: _listening ? null : (v) => setState(() => _useWatch = v),
                  ),
                  const SizedBox(width: 4),
                  Text(_useWatch ? 'Watch mic' : 'Phone mic'),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  FilledButton.icon(
                    onPressed: _ready && !_listening ? _startListening : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _listening ? _stopListening : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _ready ? _status : 'Loading model…',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  child: (_label != null)
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top: $_label',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Score: ${_score?.toStringAsFixed(3)}'),
                      const SizedBox(height: 10),
                      const Text('Top-5',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ..._topK.map((e) =>
                          Text('${e.key}: ${e.value.toStringAsFixed(3)}')),
                    ],
                  )
                      : const Text('Waiting for audio…'),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 24),

          // ===== Sound Profiles =====
          const Text('Sound Profiles',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),

          _buildSoundProfileToggle(
            title: 'Doorbell',
            description: 'Front door bell',
            icon: Icons.door_front_door,
            iconColor: Colors.brown,
            pattern: 'Pattern 1',
            isEnabled: doorbellEnabled,
            onToggle: (v) => setState(() => doorbellEnabled = v),
          ),
          const SizedBox(height: 12),
          _buildSoundProfileToggle(
            title: 'Smoke Alarm',
            description: 'Fire/smoke alarm',
            icon: Icons.local_fire_department,
            iconColor: Colors.red,
            pattern: 'Pattern 3',
            isEnabled: smokeAlarmEnabled,
            onToggle: (v) => setState(() => smokeAlarmEnabled = v),
          ),
          const SizedBox(height: 12),
          _buildSoundProfileToggle(
            title: 'Phone Ring',
            description: 'Phone ringing',
            icon: Icons.phone,
            iconColor: Colors.black87,
            pattern: 'Pattern 2',
            isEnabled: phoneRingEnabled,
            onToggle: (v) => setState(() => phoneRingEnabled = v),
          ),
          const SizedBox(height: 12),
          _buildSoundProfileToggle(
            title: 'Car Horn',
            description: 'Vehicle horn outside',
            icon: Icons.directions_car,
            iconColor: Colors.red,
            pattern: 'Pattern 4',
            isEnabled: carHornEnabled,
            onToggle: (v) => setState(() => carHornEnabled = v),
          ),

          const SizedBox(height: 24),

          // ===== Recent Alerts =====
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Alerts',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              TextButton(onPressed: () {}, child: const Text('See All')),
            ],
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            title: 'Doorbell',
            time: 'Today, 2:15 PM',
            decibels: '82 dB',
            priority: 'High',
            iconColor: Colors.brown,
            icon: Icons.door_front_door,
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            title: 'Car Horn',
            time: 'Today, 5:15 PM',
            decibels: '86 dB',
            priority: 'High',
            iconColor: Colors.red,
            icon: Icons.directions_car,
          ),
        ],
      ),
    );
  }
}
