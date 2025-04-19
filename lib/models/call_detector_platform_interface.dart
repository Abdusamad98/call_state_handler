import 'package:call_state_handler/models/call_state.dart';
import 'package:call_state_handler/models/method_channel_call_detector.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class CallDetectorPlatform extends PlatformInterface {
  CallDetectorPlatform() : super(token: _token);

  static final Object _token = Object();
  static CallDetectorPlatform _instance = MethodChannelCallDetector();

  static CallDetectorPlatform get instance => _instance;

  static set instance(CallDetectorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<CallState> get callStateStream;

  Future<void> initialize();
  Future<void> dispose();
}
