import 'dart:async';

import 'package:call_state_handler/src/models/call_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'call_detector_platform_interface.dart';

class MethodChannelCallDetector extends CallDetectorPlatform {
  final MethodChannel _methodChannel = const MethodChannel(
    'com.example.call_detector/methods',
  );
  final EventChannel _eventChannel = const EventChannel(
    'com.example.call_detector/events',
  );

  StreamController<CallState>? _callStateController;
  StreamSubscription? _eventSubscription;

  @override
  Stream<CallState> get callStateStream {
    _callStateController ??= StreamController<CallState>.broadcast();
    return _callStateController!.stream;
  }

  @override
  Future<void> initialize() async {
    try {
      await _methodChannel.invokeMethod('initialize');
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleCallStateEvent,
      );
    } catch (e) {
      debugPrint('Error initializing call detector: $e');
      rethrow;
    }
  }

  void _handleCallStateEvent(dynamic event) {
    if (event is Map) {
      final bool isCallActive = event['isCallActive'] as bool? ?? false;
      final String callTypeStr = event['callType'] as String? ?? 'none';

      CallType callType;
      switch (callTypeStr) {
        case 'phoneCall':
          callType = CallType.phoneCall;
          break;
        case 'videoCall':
          callType = CallType.videoCall;
          break;
        default:
          callType = CallType.none;
      }

      final callState = CallState(
        isCallActive: isCallActive,
        callType: callType,
      );

      _callStateController?.add(callState);
    }
  }

  @override
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _callStateController?.close();
    _callStateController = null;
    await _methodChannel.invokeMethod('dispose');
  }
}
