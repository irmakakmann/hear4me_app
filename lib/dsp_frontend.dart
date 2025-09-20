// lib/dsp_frontend.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

class SpectrogramFrontend {
  final int sampleRate;  // 16000
  final int fftSize;     // 512
  final int frameLen;    // 400 (25 ms)
  final int hopLen;      // 160 (10 ms)
  final int nMels;       // 64
  final bool useMFCC;    // true = DCT(log-mel) → MFCC

  // Window for STFT (length = fftSize; first frameLen has Hann, rest zeros)
  late final Float64List _window512;

  // Mel filterbank [nMels][fftBins] where fftBins = fftSize/2 + 1
  late final List<List<double>> _melFb;

  // DCT-II matrix [nMels][nMels] if MFCC enabled
  late final List<List<double>>? _dct;

  SpectrogramFrontend({
    this.sampleRate = 16000,
    this.fftSize = 512,
    this.frameLen = 400,
    this.hopLen = 160,
    this.nMels = 64,
    this.useMFCC = false, // set to true if your model expects MFCCs
  }) {
    // Build a 512-length window: Hann(400) + 0-padding to 512
    _window512 = Float64List(fftSize);
    for (int i = 0; i < frameLen; i++) {
      _window512[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (frameLen - 1)));
    }
    // (remaining entries default to 0.0)

    _melFb = _makeMelFilterbank(
      sampleRate: sampleRate,
      nFft: fftSize,
      nMels: nMels,
      fMin: 20.0,
      fMax: sampleRate / 2.0,
    );

    _dct = useMFCC ? _makeDct(nMels) : null;
  }

  /// Compute 96×64 features (row-major: time x feature), flattened to Float32List.
  /// Input: 1s mono PCM16 normalized to [-1,1] (Float32List length 16000).
  Float32List compute(Float32List pcm) {
    // fftea expects a List<double>
    final audio = List<double>.from(pcm);

    // STFT with hop = hopLen, window = _window512 (512-point FFT)
    final stft = STFT(fftSize, _window512);

    // Collect magnitude spectra per frame (non-redundant bins only)
    final framesMag = <Float64List>[];
    stft.run(
      audio,
          (Float64x2List complex) {
        // Keep [0..Nyquist] bins and take magnitudes
        final mags = complex.discardConjugates().magnitudes(); // length = fftSize/2 + 1
        framesMag.add(mags);
      },
      hopLen, // chunkStride = hop
    );

    // Project to mel + log (or MFCC)
    final nFrames = framesMag.length; // ~97 with 1s@16k, 512 FFT, 160 hop
    final feats = List.generate(nFrames, (_) => List<double>.filled(nMels, 0.0));

    for (int t = 0; t < nFrames; t++) {
      final mags = framesMag[t];
      // Use power spectrum (magnitude^2). If training used magnitude, drop the square.
      for (int m = 0; m < nMels; m++) {
        final fb = _melFb[m];
        double s = 0.0;
        // fb.length == mags.length == fftSize/2 + 1
        for (int k = 0; k < fb.length; k++) {
          final v = mags[k];
          s += fb[k] * (v * v);
        }
        feats[t][m] = math.log(s + 1e-6);
      }
    }

    // Optional MFCC (DCT-II over mel axis)
    if (_dct != null) {
      final dct = _dct!;
      for (int t = 0; t < nFrames; t++) {
        final lm = feats[t];
        final mfcc = List<double>.filled(nMels, 0.0);
        for (int i = 0; i < nMels; i++) {
          final row = dct[i];
          double acc = 0.0;
          for (int j = 0; j < nMels; j++) {
            acc += row[j] * lm[j];
          }
          mfcc[i] = acc;
        }
        feats[t] = mfcc;
      }
    }

    // Slice/pad to exactly 96 frames
    const outT = 96;
    final clamped = List.generate(outT, (t) => feats[t < nFrames ? t : (nFrames - 1)]);

    // Flatten to Float32 (96 * 64)
    final flat = Float32List(outT * nMels);
    for (int t = 0; t < outT; t++) {
      for (int m = 0; m < nMels; m++) {
        flat[t * nMels + m] = clamped[t][m].toDouble();
      }
    }
    return flat;
  }

  // ---------- helpers ----------

  List<List<double>> _makeMelFilterbank({
    required int sampleRate,
    required int nFft,
    required int nMels,
    double fMin = 0.0,
    double? fMax,
  }) {
    fMax ??= sampleRate / 2.0;
    final int fftBins = nFft ~/ 2 + 1;

    double hz2mel(double f) => 2595.0 * math.log(1 + f / 700.0) / math.ln10;
    double mel2hz(double m) => 700.0 * (math.pow(10, m / 2595.0) - 1);

    final mMin = hz2mel(fMin);
    final mMax = hz2mel(fMax);
    final mPts = List<double>.generate(nMels + 2, (i) => mMin + (mMax - mMin) * i / (nMels + 1));
    final fPts = mPts.map(mel2hz).toList();
    final bin = fPts.map((f) => (f * (nFft + 1) / sampleRate).floor()).toList();

    final fb = List.generate(nMels, (_) => List<double>.filled(fftBins, 0.0));
    for (int m = 1; m <= nMels; m++) {
      final a = bin[m - 1];
      final b = bin[m];
      final c = bin[m + 1];

      for (int k = a; k < b; k++) {
        if (k >= 0 && k < fftBins) {
          final denom = (b - a).clamp(1, 1 << 30);
          fb[m - 1][k] = (k - a) / denom;
        }
      }
      for (int k = b; k < c; k++) {
        if (k >= 0 && k < fftBins) {
          final denom = (c - b).clamp(1, 1 << 30);
          fb[m - 1][k] = (c - k) / denom;
        }
      }
    }
    return fb;
  }

  List<List<double>> _makeDct(int n) {
    // Orthonormal DCT-II matrix (n x n)
    final m = List.generate(n, (_) => List<double>.filled(n, 0.0));
    const double pi = math.pi;
    final scale0 = 1 / math.sqrt(n);
    final scale = math.sqrt(2 / n);
    for (int i = 0; i < n; i++) {
      final s = (i == 0) ? scale0 : scale;
      for (int j = 0; j < n; j++) {
        m[i][j] = s * math.cos(pi / n * (j + 0.5) * i);
      }
    }
    return m;
  }
}
