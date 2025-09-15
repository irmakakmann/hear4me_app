import 'package:flutter/material.dart';
import 'mic_classifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MicClassifierPage(),
  ));
}