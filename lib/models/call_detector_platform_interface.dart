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

  /// Emits the current state to every new listener, then each change.
  Stream<CallState> get callStateStream;

  /// The most recently known call state.
  CallState get currentState;

  /// Starts monitoring. Reference counted: each call must be balanced by a
  /// [dispose] call.
  Future<void> initialize();

  /// Balances one [initialize] call. Monitoring stops, and an inactive state
  /// is emitted, only when the last caller disposes.
  Future<void> dispose();

  /// Enables or disables VoIP/video call detection. Phone calls are always
  /// detected.
  Future<void> setVoipDetectionEnabled(bool enabled);
}
