import 'dart:async';

import 'package:call_state_handler/models/call_detector_platform_interface.dart';
import 'package:call_state_handler/models/call_state.dart';

export 'package:call_state_handler/models/call_state.dart';

class CallStateHandler {
  static CallStateHandler? _instance;

  factory CallStateHandler() {
    _instance ??= CallStateHandler._();
    return _instance!;
  }

  CallStateHandler._();

  /// Emits the current call state immediately on listen, then every change.
  Stream<CallState> get onCallStateChanged =>
      CallDetectorPlatform.instance.callStateStream;

  /// The most recently known call state.
  CallState get currentState => CallDetectorPlatform.instance.currentState;

  /// Starts monitoring. Reference counted, so several widgets can share the
  /// singleton: balance every [initialize] with one [dispose].
  Future<void> initialize() {
    return CallDetectorPlatform.instance.initialize();
  }

  /// Balances one [initialize] call. When the last caller disposes,
  /// monitoring stops and an inactive state is emitted. The stream stays
  /// usable, so [initialize] can be called again later.
  Future<void> dispose() {
    return CallDetectorPlatform.instance.dispose();
  }

  /// Enables or disables VoIP/video call detection (Android only; no-op on
  /// iOS). Disable it while your app records audio itself, e.g. voice
  /// messages, since recording can look like a VoIP call to the system.
  Future<void> setVoipDetectionEnabled(bool enabled) {
    return CallDetectorPlatform.instance.setVoipDetectionEnabled(enabled);
  }
}
