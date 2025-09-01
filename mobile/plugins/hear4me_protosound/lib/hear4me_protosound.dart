import 'dart:async';
import 'package:flutter/services.dart';

class Hear4MeProtoSound {
  static const MethodChannel _m = MethodChannel('hear4me_protosound');
  static const EventChannel _events = EventChannel('hear4me_protosound/events');

  static Future<void> initialize({String modelAsset = 'protosound_model.ptl'}) {
    return _m.invokeMethod('initialize', {'modelAsset': modelAsset});
  }

  static Future<void> addTrainingSample({
    required String locationId,
    required String classId,
    String? wavPath,
  }) {
    return _m.invokeMethod('addTrainingSample', {
      'locationId': locationId,
      'classId': classId,
      if (wavPath != null) 'wavPath': wavPath,
    });
  }

  static Future<Map<String, dynamic>> train(String locationId) async {
    final res = await _m.invokeMethod('train', {'locationId': locationId});
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> startRecognition({
    required String locationId,
    double openSetThreshold = 0.6,
    double loudnessDb = 45.0,
  }) {
    return _m.invokeMethod('startRecognition', {
      'locationId': locationId,
      'openSetThreshold': openSetThreshold,
      'loudnessDb': loudnessDb,
    });
  }

  static Future<void> stopRecognition() {
    return _m.invokeMethod('stopRecognition');
  }

  static Stream<Map> detections() {
    return _events
        .receiveBroadcastStream()
        .map((e) => Map<String, dynamic>.from(e as Map));
  }
}
