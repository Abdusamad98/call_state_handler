import 'dart:async';

import 'package:call_state_handler/models/call_detector_platform_interface.dart';
import 'package:call_state_handler/models/call_state.dart';

class CallStateHandler {
  static CallStateHandler? _instance;

  factory CallStateHandler() {
    _instance ??= CallStateHandler._();
    return _instance!;
  }

  CallStateHandler._();

  /// Stream that emits the current call state
  Stream<CallState> get onCallStateChanged =>
      CallDetectorPlatform.instance.callStateStream;

  /// Initialize the call detector
  Future<void> initialize() {
    return CallDetectorPlatform.instance.initialize();
  }

  /// Stop and clean up resources
  Future<void> dispose() {
    return CallDetectorPlatform.instance.dispose();
  }
}
