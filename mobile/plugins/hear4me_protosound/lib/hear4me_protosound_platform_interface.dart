import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hear4me_protosound_method_channel.dart';

abstract class Hear4meProtosoundPlatform extends PlatformInterface {
  /// Constructs a Hear4meProtosoundPlatform.
  Hear4meProtosoundPlatform() : super(token: _token);

  static final Object _token = Object();

  static Hear4meProtosoundPlatform _instance = MethodChannelHear4meProtosound();

  /// The default instance of [Hear4meProtosoundPlatform] to use.
  ///
  /// Defaults to [MethodChannelHear4meProtosound].
  static Hear4meProtosoundPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [Hear4meProtosoundPlatform] when
  /// they register themselves.
  static set instance(Hear4meProtosoundPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
