// lib/audio_classifier.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'labels.dart';

/// Float32 audio classifier for 1s PCM16 @16kHz.
/// Expects model input shape [1,16000] or [1,16000,1] and output [1,numLabels].
class AudioClassifier {
  final int sampleRate = 16000;
  final int windowSize = 16000; // 1s at 16kHz

  late final Interpreter _interpreter;
  late final List<int> _inShape;
  late final List<int> _outShape;

  // EMA smoothing over successive windows (lower = snappier)
  final double emaAlpha = 0.25;
  Float32List? _emaProbs;
  int _framesSinceReset = 0;

  /// Loads assets/hear4me_model.tflite from bundle and prepares interpreter.
  Future<void> load() async {
    final data = await rootBundle.load('assets/hear4me_model.tflite');
    final bytes = data.buffer.asUint8List();

    _interpreter = await Interpreter.fromBuffer(
      bytes,
      options: InterpreterOptions()..threads = 2,
    );

    _inShape = _interpreter.getInputTensor(0).shape;
    _outShape = _interpreter.getOutputTensor(0).shape;

    // Validate shapes and types
    if (!(_outShape.length == 2 && _outShape.first == 1)) {
      throw StateError("Model output must be [1, numLabels], got $_outShape");
    }
    if (_outShape.last != soundLabels.length) {
      throw StateError(
        "Model output ${_outShape.last} != labels ${soundLabels.length}. "
            "labels.dart list must match the model's output order.",
      );
    }
    final inType = _interpreter.getInputTensor(0).type;
    final outType = _interpreter.getOutputTensor(0).type;
    if (inType != TensorType.float32 || outType != TensorType.float32) {
      throw UnsupportedError(
        "This helper expects a float32 model. "
            "Got input=$inType, output=$outType.",
      );
    }
  }

  /// Run inference on a 1s PCM16 window (exactly 16000 samples).
  /// Returns: {label, score, probs (Map<label,double>), index}
  Map<String, dynamic> infer(List<int> framePcm16) {
    if (framePcm16.length != windowSize) {
      throw ArgumentError("Expected $windowSize samples, got ${framePcm16.length}");
    }

    // Convert to Float32 [-1,1]
    final floats = Float32List.fromList(
      framePcm16.map((s) => s / 32768.0).toList(),
    );

    // --- Per-frame standardization (zero-mean, unit-RMS) ---
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

    // Match input shape: [1,16000] or [1,16000,1]
    Object input;
    if (_inShape.length == 2 && _inShape[0] == 1 && _inShape[1] == windowSize) {
      input = [floats.toList()]; // List<List<double>>
    } else if (_inShape.length == 3 &&
        _inShape[0] == 1 &&
        _inShape[1] == windowSize &&
        _inShape[2] == 1) {
      input = [floats.map((f) => [f]).toList()]; // List<List<List<double>>>
    } else {
      throw StateError(
        "Unexpected input shape: $_inShape. "
            "Expected [1,$windowSize] or [1,$windowSize,1]. "
            "If your model is spectrogram-shaped (e.g. [1,96,64,1]), you must add a feature pipeline.",
      );
    }

    // Output buffer [1, numLabels] float32
    final int numLabels = _outShape.last;
    final List<List<double>> output = [List.filled(numLabels, 0.0)];
    _interpreter.run(input, output);

    // Get probabilities (softmax if logits)
    List<double> probs = output[0];
    probs = _softmaxIfNeeded(probs);

    // EMA smoothing over time
    probs = _ema(_emaProbs, probs, emaAlpha);
    _emaProbs = Float32List.fromList(probs);

    // Periodically reset EMA to avoid stickiness
    _framesSinceReset++;
    if (_framesSinceReset >= 24) { // ~6s if hop=250ms
      _emaProbs = null;
      _framesSinceReset = 0;
    }

    // DEBUG: print top-k with indices to verify label order
    // debugDumpTopK(probs, k: 8);

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
    if (in01 && (sum > 0.95 && sum < 1.05)) return v;
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
