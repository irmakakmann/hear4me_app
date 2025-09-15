import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio_classifier.dart';
import 'labels.dart'; // uses soundLabels

class MicClassifierPage extends StatefulWidget {
  const MicClassifierPage({super.key});
  @override
  State<MicClassifierPage> createState() => _MicClassifierPageState();
}

class _MicClassifierPageState extends State<MicClassifierPage> {
  // mic + model
  final _cap = FlutterAudioCapture();
  final _clf = AudioClassifier();

  // state
  bool _ready = false;
  bool _listening = false;
  bool _busy = false; // avoid overlapping classify ticks
  Timer? _hopTimer;

  // audio ring-buffer (keep ~5s max)
  final List<int> _mono16 = <int>[];
  int _deviceSampleRate = 0; // actual mic SR we’ll resample from

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
    super.dispose();
  }

  Future<void> _init() async {
    // 1) mic permission
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
      // 2) init plugin (required) + load model
      await _cap.init();
      await _clf.load();

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('[InitError] $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Init failed: $e')));
    }
  }

  Future<void> _startListening() async {
    if (!_ready || _listening) return;

    const requestedRate = 16000;

    void onAudio(dynamic obj) {
      // plugin delivers Float32 samples [-1,1]
      Float32List f32;
      if (obj is Float32List) {
        f32 = obj;
      } else if (obj is List) {
        f32 = Float32List.fromList(obj.cast<double>());
      } else {
        debugPrint('[AUDIO] Unknown buffer type: ${obj.runtimeType}');
        return;
      }

      // Float32 -> Int16
      final i16 = Int16List(f32.length);
      for (var i = 0; i < f32.length; i++) {
        final s = (f32[i] * 32767.0).clamp(-32768.0, 32767.0);
        i16[i] = s.toInt();
      }

      // Resample to 16k if mic SR isn’t 16k
      final List<int> mono16;
      if (_deviceSampleRate == 0 || _deviceSampleRate == requestedRate) {
        mono16 = i16;
      } else {
        mono16 = _resampleI16Nearest(i16, _deviceSampleRate, requestedRate);
      }

      _mono16.addAll(mono16);
      if (_mono16.length > 80000) {
        _mono16.removeRange(0, _mono16.length - 80000); // cap ~5s
      }

      // debug heartbeat
      _chunks++;
      if (_chunks % 10 == 0) {
        _info = 'chunks=$_chunks len=${f32.length} sr=$_deviceSampleRate';
        if (mounted) setState(() {});
      }
    }

    void onError(Object e) {
      debugPrint('[AUDIO] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Audio error: $e')));
      }
      _stopListening();
    }

    try {
      await _cap.start(
        onAudio,
        onError,
        sampleRate: requestedRate, // device may ignore this
        bufferSize: 4096,          // larger buffer = fewer dropouts
      );

      // Many devices (esp. Huawei) actually record at 48k or 44.1k.
      // Force one to engage our resampler path. Try 48000 first.
      _deviceSampleRate = 48000;
      // _deviceSampleRate = 44100; // try this instead if needed

      _startLoop(); // begin periodic classification
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
      try {
        await _cap.stop();
      } catch (_) {}
    }
    if (mounted) setState(() => _listening = false);
  }

  void _classifyLatestWindow() {
    const win = 16000;
    if (_mono16.length < win) return;

    final frame = _mono16.sublist(_mono16.length - win);

    // Optional light gate (tune or comment out)
    final rms = math.sqrt(
      frame.fold<double>(0, (a, x) => a + (x * x)) / frame.length,
    );
    if (rms < 50) return;

    final res = _clf.infer(frame);
    final score = (res['score'] as num).toDouble();
    final probs = (res['probs'] as Map<String, double>);
    final entries = probs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Optional confidence gate
    if (score < 0.2) return;

    setState(() {
      _label = res['label'] as String;
      _score = score;
      _topK = entries.take(5).toList();
    });
  }

  // Fast nearest-neighbor resample int16
  List<int> _resampleI16Nearest(List<int> input, int inSr, int outSr) {
    if (inSr == outSr) return input;
    final ratio = outSr / inSr;
    final outLen = (input.length * ratio).floor();
    final out = List<int>.filled(outLen, 0);
    for (var i = 0; i < outLen; i++) {
      final src = (i / ratio).round().clamp(0, input.length - 1);
      out[i] = input[src];
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
