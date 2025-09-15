import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'labels.dart';

/// Supports:
///  • waveform: [1,16000] or [1,16000,1]  (1s @16k PCM -> float32 [-1,1])
///  • log-mel:  [1,96,64,1]               (96 frames × 64 bins)
class AudioClassifier {
  final int sampleRate = 16000;
  final int windowSize = 16000; // 1s @ 16k

  late final Interpreter _interpreter;
  late final List<int> _inShape;
  late final List<int> _outShape;

  bool _expectsLogMel = false;

  // ---- frontend cache ----
  static const int _winLength = 400;   // 25 ms
  static const int _hopLength = 160;   // 10 ms
  static const int _nFft = 512;
  static const int _nSpec = _nFft ~/ 2 + 1;
  static const int _nMels = 64;
  late final Float32List _hann;                 // length 400
  late final List<Float32List> _melBank;        // 64 × _nSpec

  // EMA smoothing (lower = snappier)
  final double emaAlpha = 0.2;
  Float32List? _emaProbs;

  // Reweight some classes to reduce Speech bias (tune as needed)
  final Map<String, double> _classScale = const {
    'Speech': 0.35,            // suppress speech dominance
    'Dog Bark': 1.15,
    'Cat Meow': 1.15,
    'Coughing': 1.15,
    'Baby Cry': 1.25,
    'Fire/Smoke Alarm': 1.40,
    'Doorbell': 1.20,
  };

  Future<void> load() async {
    final data = await rootBundle.load('assets/example_model.tflite');
    final bytes = data.buffer.asUint8List();

    _interpreter = await Interpreter.fromBuffer(
      bytes,
      options: InterpreterOptions()..threads = 2,
    );

    _inShape = _interpreter.getInputTensor(0).shape;
    _outShape = _interpreter.getOutputTensor(0).shape;

    _expectsLogMel = (_inShape.length == 4 &&
        _inShape[0] == 1 && _inShape[1] == 96 && _inShape[2] == 64 && _inShape[3] == 1);

    if (!(_outShape.length == 2 && _outShape.first == 1)) {
      throw StateError('Model output must be [1, numLabels], got $_outShape');
    }
    if (_outShape.last != soundLabels.length) {
      throw StateError('labels count (${soundLabels.length}) != model output ${_outShape.last}');
    }

    final inType = _interpreter.getInputTensor(0).type;
    final outType = _interpreter.getOutputTensor(0).type;
    if (inType != TensorType.float32 || outType != TensorType.float32) {
      throw UnsupportedError('This helper expects a float32 model.');
    }

    // ---- precompute frontend ----
    _hann = Float32List(_winLength);
    for (int i = 0; i < _winLength; i++) {
      _hann[i] = (0.5 - 0.5 * math.cos(2 * math.pi * i / _winLength)).toDouble();
    }
    _melBank = _buildMelBank(
      nMels: _nMels, nFft: _nFft, sr: sampleRate, fMin: 60.0, fMax: sampleRate / 2.0,
    );
  }

  Map<String, dynamic> infer(List<int> framePcm16) {
    if (framePcm16.length != windowSize) {
      throw ArgumentError('Expected $windowSize samples, got ${framePcm16.length}');
    }

    final floats = Float32List.fromList(framePcm16.map((s) => s / 32768.0).toList());

    Object input;
    if (_expectsLogMel) {
      final spec = _computeLogMel96x64(floats); // [96][64]
      final withChannel = spec.map((row) => row.map((v) => [v]).toList()).toList(); // [96][64][1]
      input = [withChannel]; // [1][96][64][1]
    } else if (_inShape.length == 2 && _inShape[0] == 1 && _inShape[1] == windowSize) {
      input = [floats.toList()];
    } else if (_inShape.length == 3 &&
        _inShape[0] == 1 && _inShape[1] == windowSize && _inShape[2] == 1) {
      input = [floats.map((f) => [f]).toList()];
    } else {
      throw StateError('Unexpected input shape: $_inShape.');
    }

    final numLabels = _outShape.last;
    final output = <List<double>>[List<double>.filled(numLabels, 0.0)];
    _interpreter.run(input, output);

    List<double> probs = output[0];
    probs = _softmaxIfNeeded(probs);
    probs = _ema(_emaProbs, probs, emaAlpha);
    _emaProbs = Float32List.fromList(probs);

    // De-bias by label, then renormalize
    probs = _reweightByLabel(probs);

    final topIdx = _argmax(probs);
    return {
      'label': soundLabels[topIdx],
      'score': probs[topIdx],
      'probs': Map<String, double>.fromIterables(soundLabels, probs),
      'index': topIdx,
    };
  }

  // ---------- fast log-mel using cached window + mel bank ----------

  List<List<double>> _computeLogMel96x64(Float32List x) {
    final re = Float32List(_nFft);
    final im = Float32List(_nFft);

    final frames = List.generate(96, (_) => Float32List(_nSpec));
    final lastStart = x.length - _winLength;
    int start = lastStart - (95 * _hopLength);
    if (start < 0) start = 0;

    for (int f = 0; f < 96; f++) {
      final s0 = start + f * _hopLength;

      re.fillRange(0, re.length, 0.0);
      im.fillRange(0, im.length, 0.0);
      for (int i = 0; i < _winLength; i++) {
        final idx = s0 + i;
        final v = (idx >= 0 && idx < x.length) ? x[idx] : 0.0;
        re[i] = v * _hann[i];
      }

      _fftInPlace(re, im);

      for (int k = 0; k < _nSpec; k++) {
        final rr = re[k], ii = im[k];
        frames[f][k] = (rr * rr + ii * ii) / _nFft;
      }
    }

    final mel = List.generate(96, (_) => List<double>.filled(_nMels, 0.0));
    for (int t = 0; t < 96; t++) {
      final frame = frames[t];
      for (int m = 0; m < _nMels; m++) {
        double s = 0.0;
        final filt = _melBank[m];
        for (int k = 0; k < _nSpec; k++) {
          s += frame[k] * filt[k];
        }
        // dB scaling (common in training), clamp to [-80, 0]
        final db = 10.0 * (math.log(s + 1e-6) / math.ln10);
        mel[t][m] = db.clamp(-80.0, 0.0);
      }
    }

    _perFreqNormalize(mel); // helps align with many training pipelines
    return mel;
  }

  List<Float32List> _buildMelBank({
    required int nMels,
    required int nFft,
    required int sr,
    required double fMin,
    required double fMax,
  }) {
    final nSpec = nFft ~/ 2 + 1;

    double hzToMel(double f) => 2595.0 * math.log(1.0 + f / 700.0) / math.ln10;
    double melToHz(double m) => 700.0 * (math.pow(10.0, m / 2595.0) - 1.0);

    final mMin = hzToMel(fMin);
    final mMax = hzToMel(fMax);
    final melPts = List<double>.generate(nMels + 2, (i) => mMin + (mMax - mMin) * i / (nMels + 1));
    final hzPts = melPts.map(melToHz).toList();

    final bin = hzPts.map((hz) => (((nFft + 1) * hz) / sr).floor()).toList();

    final filters = List.generate(nMels, (_) => Float32List(nSpec));

    for (int m = 1; m <= nMels; m++) {
      final f0 = bin[m - 1].clamp(0, nSpec - 1).toInt();
      final f1 = bin[m].clamp(0, nSpec - 1).toInt();
      final f2 = bin[m + 1].clamp(0, nSpec - 1).toInt();

      final denomRise = (f1 - f0).abs() + 1e-9;
      for (int k = f0; k <= f1; k++) {
        filters[m - 1][k] = ((k - f0) / denomRise).toDouble();
      }
      final denomFall = (f2 - f1).abs() + 1e-9;
      for (int k = f1; k <= f2; k++) {
        filters[m - 1][k] = ((f2 - k) / denomFall).toDouble();
      }
    }
    return filters;
  }

  static void _perFreqNormalize(List<List<double>> mel) {
    final T = mel.length;
    final M = mel[0].length;
    for (int m = 0; m < M; m++) {
      double mean = 0.0;
      for (int t = 0; t < T; t++) mean += mel[t][m];
      mean /= T;
      double sumSq = 0.0;
      for (int t = 0; t < T; t++) {
        final d = mel[t][m] - mean; sumSq += d * d;
      }
      final std = math.sqrt(sumSq / T + 1e-9);
      for (int t = 0; t < T; t++) {
        mel[t][m] = (mel[t][m] - mean) / std;
      }
    }
  }

  // Reweight per label + optionally ban some labels, then renormalize
  List<double> _reweightByLabel(List<double> probs) {
    // Banlist: anything here gets probability 0.0
    const banned = {'Speech'}; // ← hard-ban Speech

    final scaled = List<double>.from(probs);
    double sum = 0.0;
    for (int i = 0; i < scaled.length; i++) {
      final lbl = soundLabels[i];
      final bool isBanned = banned.contains(lbl);
      final mult = isBanned ? 0.0 : (_classScale[lbl] ?? 1.0);
      scaled[i] *= mult;
      sum += scaled[i];
    }

    // If we zeroed everything (edge case), fall back to original
    if (sum <= 1e-12) return probs;

    for (int i = 0; i < scaled.length; i++) {
      scaled[i] /= sum;
    }
    return scaled;
  }

  // FFT (radix-2, in-place)
  static void _fftInPlace(Float32List re, Float32List im) {
    final n = re.length;
    if (n == 0) return;

    int j = 0;
    for (int i = 0; i < n; i++) {
      if (i < j) {
        final tr = re[i]; re[i] = re[j]; re[j] = tr;
        final ti = im[i]; im[i] = im[j]; im[j] = ti;
      }
      int m = n >> 1;
      while (m >= 1 && j >= m) { j -= m; m >>= 1; }
      j += m;
    }

    for (int len = 2; len <= n; len <<= 1) {
      final half = len >> 1;
      final ang = -2.0 * math.pi / len;
      final wlenCos = math.cos(ang);
      final wlenSin = math.sin(ang);
      for (int i = 0; i < n; i += len) {
        double wr = 1.0, wi = 0.0;
        for (int k = 0; k < half; k++) {
          final uRe = re[i + k], uIm = im[i + k];
          final vRe = re[i + k + half] * wr - im[i + k + half] * wi;
          final vIm = re[i + k + half] * wi + im[i + k + half] * wr;

          re[i + k] = uRe + vRe;
          im[i + k] = uIm + vIm;
          re[i + k + half] = uRe - vRe;
          im[i + k + half] = uIm - vIm;

          final nxtWr = wr * wlenCos - wi * wlenSin;
          final nxtWi = wr * wlenSin + wi * wlenCos;
          wr = nxtWr; wi = nxtWi;
        }
      }
    }
  }

  // ----- helpers -----
  static int _argmax(List<double> x) {
    var maxV = -double.infinity, maxI = 0;
    for (var i = 0; i < x.length; i++) {
      if (x[i] > maxV) { maxV = x[i]; maxI = i; }
    }
    return maxI;
  }

  static List<double> _softmaxIfNeeded(List<double> v) {
    final sum = v.fold<double>(0.0, (a, b) => a + b);
    final looksLikeProbs = v.every((x) => x >= -1e-6 && x <= 1.000001);
    if (looksLikeProbs && (sum > 0.95 && sum < 1.05)) return v;

    final m = v.reduce(math.max);
    final exps = v.map((x) => math.exp(x - m)).toList();
    final exSum = exps.fold<double>(0.0, (a, b) => a + b);
    if (exSum == 0) return List<double>.filled(v.length, 0.0);
    return exps.map((e) => e / exSum).toList();
  }

  static List<double> _ema(Float32List? prev, List<double> now, double a) {
    if (prev == null || prev.length != now.length) return now;
    final out = List<double>.filled(now.length, 0.0);
    for (var i = 0; i < now.length; i++) {
      out[i] = a * now[i] + (1 - a) * prev[i];
    }
    return out;
  }
}
