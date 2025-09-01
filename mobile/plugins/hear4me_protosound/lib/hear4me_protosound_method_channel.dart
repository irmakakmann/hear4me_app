import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hear4me_protosound_platform_interface.dart';

/// An implementation of [Hear4meProtosoundPlatform] that uses method channels.
class MethodChannelHear4meProtosound extends Hear4meProtosoundPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('hear4me_protosound');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
