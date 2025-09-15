import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio_classifier.dart';
import 'labels.dart';

class MicClassifierPage extends StatefulWidget {
  const MicClassifierPage({super.key});
  @override
  State<MicClassifierPage> createState() => _MicClassifierPageState();
}

class _MicClassifierPageState extends State<MicClassifierPage> {
  final _cap = FlutterAudioCapture();
  final _clf = AudioClassifier();

  bool _ready = false;
  bool _listening = false;
  bool _busy = false;
  Timer? _hopTimer;

  final List<int> _mono16 = <int>[];
  int _deviceSampleRate = 0;

  int _chunks = 0;
  String _info = '';

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
    super.dispose();
  }

  Future<void> _init() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      return;
    }
    try {
      await _cap.init();     // required
      await _clf.load();     // loads model, prepares frontend
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('[InitError] $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Init failed: $e')),
      );
    }
  }

  Future<void> _startListening() async {
    if (!_ready || _listening) return;

    const requestedRate = 16000;

    void onError(Object e) {
      debugPrint('[AUDIO] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio error: $e')),
        );
      }
      _stopListening();
    }

    void onAudio(dynamic obj) {
      // plugin delivers Float32 samples [-1,1]
      Float32List f32 = (obj is Float32List)
          ? obj
          : Float32List.fromList((obj as List).cast<double>());

      // High-quality resample on Float32 first
      final f32_16k = (_deviceSampleRate == 0 || _deviceSampleRate == requestedRate)
          ? f32
          : _resampleF32Linear(f32, _deviceSampleRate, requestedRate);

      // Then convert to Int16
      final i16 = Int16List(f32_16k.length);
      for (var i = 0; i < f32_16k.length; i++) {
        final s = (f32_16k[i] * 32767.0).clamp(-32768.0, 32767.0);
        i16[i] = s.toInt();
      }

      _mono16.addAll(i16);
      if (_mono16.length > 80000) {
        _mono16.removeRange(0, _mono16.length - 80000); // ~5s cap
      }

      _chunks++;
      if (_chunks % 10 == 0 && mounted) {
        _info = 'chunks=$_chunks len=${f32.length} sr=$_deviceSampleRate';
        setState(() {});
      }
    }

    try {
      await _cap.start(
        onAudio,
        onError,
        sampleRate: requestedRate, // device may ignore this
        bufferSize: 4096,          // larger buffer reduces dropouts
      );

      // Try true 16k first; if results are weird, try forcing 48000 or 44100:
      _deviceSampleRate = requestedRate;
      // _deviceSampleRate = 48000;
      // _deviceSampleRate = 44100;

      _startLoop();
      setState(() => _listening = true);
    } catch (e) {
      debugPrint('[AUDIO] Start failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Start mic failed: $e')),
        );
      }
      _stopListening();
    }
  }

  void _startLoop() {
    _hopTimer?.cancel();
    _hopTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
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
    if (_listening) {
      try { await _cap.stop(); } catch (_) {}
    }
    if (mounted) setState(() => _listening = false);
  }

  void _classifyLatestWindow() {
    const win = 16000;
    if (_mono16.length < win) return;

    final frame = _mono16.sublist(_mono16.length - win);

    // Stronger silence gate avoids random Speech in quiet
    final rms = math.sqrt(frame.fold<double>(0, (a, x) => a + (x * x)) / frame.length);
    if (rms < 60) return;

    final res = _clf.infer(frame);
    final probs = (res['probs'] as Map<String, double>);
    final entries = probs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var top = entries[0];
    final second = entries.length > 1 ? entries[1] : top;

    // Anti-speech rule: if Speech barely wins, prefer runner-up
    const double speechHardMin = 0.60;  // require ≥0.60 to trust Speech
    const double minSecond = 0.25;      // runner-up must be at least this
    const double margin = 0.15;         // Speech must beat runner-up by this

    if (top.key == 'Speech') {
      final speechStrong = top.value >= speechHardMin;
      final runnerViable = second.value >= minSecond;
      final notByMuch = (top.value - second.value) < margin;
      if (!speechStrong && runnerViable && notByMuch) {
        top = second;
      }
    }

    // Light confidence gate (post-reweight)
    if (top.value < 0.18) return;

    setState(() {
      _label = top.key;
      _score = top.value;
      _topK = entries.take(5).toList();
    });
  }

  // Linear resample Float32 -> Float32
  Float32List _resampleF32Linear(Float32List input, int inSr, int outSr) {
    if (inSr == outSr) return input;
    final outLen = (input.length * outSr / inSr).floor();
    final out = Float32List(outLen);
    final step = inSr / outSr;
    double src = 0.0;
    for (int i = 0; i < outLen; i++) {
      final i0 = src.floor();
      final i1 = (i0 + 1 < input.length) ? i0 + 1 : i0;
      final frac = src - i0;
      out[i] = input[i0] * (1.0 - frac) + input[i1] * frac;
      src += step;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Audio Classifier')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_ready ? 'Model loaded ✅' : 'Loading model…',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _ready && !_listening ? _startListening : null,
                  child: const Text('Start mic'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _listening ? _stopListening : null,
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(_info, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            if (_label != null) ...[
              Text('Top: $_label',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text('Score: ${_score?.toStringAsFixed(3)}'),
              const SizedBox(height: 12),
              const Text('Top-5', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._topK.map((e) => Text('${e.key}: ${e.value.toStringAsFixed(3)}')),
            ] else
              const Text('Waiting for audio…'),
            const Spacer(),
            Text(
              'Labels (${soundLabels.length}): ${soundLabels.take(6).join(", ")}…',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
