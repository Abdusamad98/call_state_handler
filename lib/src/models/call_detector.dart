import 'dart:async';

import 'package:call_state_handler/src/models/call_detector_platform_interface.dart';
import 'package:call_state_handler/src/models/call_state.dart';

class CallDetector {
  static CallDetector? _instance;

  factory CallDetector() {
    _instance ??= CallDetector._();
    return _instance!;
  }

  CallDetector._();

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
