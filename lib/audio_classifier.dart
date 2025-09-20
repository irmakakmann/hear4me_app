// lib/audio_classifier.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'labels.dart';
import 'dsp_frontend.dart';

/// Float32 audio classifier for 1s PCM16 @16kHz.
/// Supports input [1,16000], [1,16000,1], or spectrogram [1,96,64,1].
class AudioClassifier {
  final int sampleRate = 16000;
  final int windowSize = 16000; // 1s @ 16kHz

  late final Interpreter _interpreter;
  late final List<int> _inShape;
  late final List<int> _outShape;
  late final TensorType _inType;
  late final TensorType _outType;

  // Spectrogram frontend (only used when model needs [1,96,64,1])
  bool _needsSpectrogram = false;
  SpectrogramFrontend? _frontend;

  // EMA smoothing over successive windows (lower = snappier)
  final double emaAlpha = 0.25;
  Float32List? _emaProbs;
  int _framesSinceReset = 0;

  /// Loads assets/hear4me_model.tflite and prepares interpreter.
  Future<void> load() async {
    // Load bytes
    final data = await rootBundle.load('assets/hear4me_model.tflite');
    final bytes = data.buffer.asUint8List();

    // Create interpreter
    _interpreter = await Interpreter.fromBuffer(
      bytes,
      options: InterpreterOptions()..threads = 2,
    );

    // Shapes & types
    _inShape = _interpreter.getInputTensor(0).shape;
    _outShape = _interpreter.getOutputTensor(0).shape;
    _inType = _interpreter.getInputTensor(0).type;
    _outType = _interpreter.getOutputTensor(0).type;

    // Sanity checks
    if (!(_outShape.length == 2 && _outShape.first == 1)) {
      throw StateError("Model output must be [1, numLabels], got $_outShape");
    }
    if (_outShape.last != soundLabels.length) {
      throw StateError(
        "Model output ${_outShape.last} != labels ${soundLabels.length}. "
            "Update labels.dart to match the model.",
      );
    }
    if (_inType != TensorType.float32 || _outType != TensorType.float32) {
      throw UnsupportedError(
        "Expected float32 model. Got input=$_inType, output=$_outType.",
      );
    }

    // Detect spectrogram model
    _needsSpectrogram = _inShape.length == 4 &&
        _inShape[0] == 1 &&
        _inShape[1] == 96 &&
        _inShape[2] == 64 &&
        _inShape[3] == 1;

    if (_needsSpectrogram) {
      // Configure the frontend. Start with log-mel (useMFCC=false).
      // If your accuracy looks off and SoundWatch used MFCCs, flip to true.
      _frontend = SpectrogramFrontend(
        sampleRate: sampleRate,
        fftSize: 512,
        frameLen: 400,
        hopLen: 160,
        nMels: 64,
        useMFCC: false,
      );
    }

    // Helpful log
    // ignore: avoid_print
    print('[TFL] model loaded '
        '(bytes=${bytes.length}) '
        'in=$_inShape out=$_outShape '
        'needsSpectrogram=$_needsSpectrogram');
  }

  /// Run inference on a 1s PCM16 window (exactly 16000 samples).
  /// Returns: {label, score, probs(Map<label,double>), index}
  Map<String, dynamic> infer(List<int> framePcm16) {
    if (framePcm16.length != windowSize) {
      throw ArgumentError("Expected $windowSize samples, got ${framePcm16.length}");
    }

    // Convert to Float32 [-1,1]
    final floats = Float32List.fromList(
      framePcm16.map((s) => s / 32768.0).toList(),
    );

    // Per-frame standardization (can disable if your training expected raw)
    double mean = 0;
    for (var i = 0; i < floats.length; i++) mean += floats[i];
    mean /= floats.length;
    double sq = 0;
    for (var i = 0; i < floats.length; i++) {
      final v = floats[i] - mean;
      sq += v * v;
    }
    final rms = math.sqrt(sq / floats.length).clamp(1e-6, 1e9);
    for (var i = 0; i < floats.length; i++) {
      floats[i] = (floats[i] - mean) / rms;
    }

    // Build input tensor based on model input shape
    final Object input;
    if (_needsSpectrogram) {
      // PCM → 96×64 log-mel (or MFCC), flattened
      final feats = _frontend!.compute(floats); // len = 96*64
      // reshape to [1,96,64,1] using nested Dart lists
      final shaped = List.generate(96, (t) =>
          List.generate(64, (m) => [feats[t * 64 + m]])
      );
      input = [shaped];
    } else if (_inShape.length == 2 &&
        _inShape[0] == 1 &&
        _inShape[1] == windowSize) {
      input = [floats.toList()]; // [1,16000]
    } else if (_inShape.length == 3 &&
        _inShape[0] == 1 &&
        _inShape[1] == windowSize &&
        _inShape[2] == 1) {
      input = [floats.map((f) => [f]).toList()]; // [1,16000,1]
    } else {
      throw StateError(
        "Unsupported input shape: $_inShape. "
            "Supported: [1,$windowSize], [1,$windowSize,1], or [1,96,64,1].",
      );
    }

    // Output buffer [1, numLabels] float32
    final int numLabels = _outShape.last;
    final List<List<double>> output = [List.filled(numLabels, 0.0)];
    _interpreter.run(input, output);

    // Probabilities (softmax if logits)
    List<double> probs = _softmaxIfNeeded(output[0]);

    // EMA smoothing over time
    probs = _ema(_emaProbs, probs, emaAlpha);
    _emaProbs = Float32List.fromList(probs);

    // Periodically reset EMA to avoid stickiness
    _framesSinceReset++;
    if (_framesSinceReset >= 24) {
      _emaProbs = null;
      _framesSinceReset = 0;
    }

    final int topIdx = _argmax(probs);
    return {
      "label": soundLabels[topIdx],
      "score": probs[topIdx],
      "probs": Map<String, double>.fromIterables(soundLabels, probs),
      "index": topIdx,
    };
  }

  // -------- helpers --------
  static int _argmax(List<double> x) {
    var maxV = -double.infinity, maxI = 0;
    for (var i = 0; i < x.length; i++) {
      if (x[i] > maxV) { maxV = x[i]; maxI = i; }
    }
    return maxI;
  }

  static List<double> _softmaxIfNeeded(List<double> v) {
    final sum = v.fold<double>(0.0, (a, b) => a + b);
    final in01 = v.every((x) => x >= -1e-6 && x <= 1.000001);
    if (in01 && (sum > 0.95 && sum < 1.05)) return v; // already probs
    final m = v.reduce(math.max);
    final exps = v.map((x) => math.exp(x - m)).toList();
    final exSum = exps.fold<double>(0.0, (a, b) => a + b);
    if (exSum == 0) return List<double>.filled(v.length, 0);
    return exps.map((e) => e / exSum).toList();
  }

  static List<double> _ema(Float32List? prev, List<double> now, double a) {
    if (prev == null || prev.length != now.length) return now;
    final out = List<double>.filled(now.length, 0);
    for (var i = 0; i < now.length; i++) {
      out[i] = a * now[i] + (1 - a) * prev[i];
    }
    return out;
  }

  // Optional debug helper to verify label order vs indices
  void debugDumpTopK(List<double> probs, {int k = 5}) {
    final idxs = List<int>.generate(probs.length, (i) => i)
      ..sort((a, b) => probs[b].compareTo(probs[a]));
    final top = idxs.take(k);
    for (final i in top) {
      // ignore: avoid_print
      print('[TFL] $i -> ${soundLabels[i]} (${probs[i].toStringAsFixed(3)})');
    }
  }
}
