import 'dart:async';

import 'package:call_state_handler/models/call_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'call_detector_platform_interface.dart';

class MethodChannelCallDetector extends CallDetectorPlatform {
  @visibleForTesting
  static const MethodChannel methodChannel = MethodChannel(
    'com.example.call_detector/methods',
  );
  @visibleForTesting
  static const EventChannel eventChannel = EventChannel(
    'com.example.call_detector/events',
  );

  final StreamController<CallState> _controller =
      StreamController<CallState>.broadcast();
  StreamSubscription<dynamic>? _eventSubscription;
  CallState _currentState = const CallState.initial();

  /// Number of initialize() calls not yet balanced by dispose(). Several
  /// widgets may share the singleton; native monitoring stops only when the
  /// last one disposes.
  int _refCount = 0;

  /// Serializes initialize()/dispose() so concurrent calls cannot interleave.
  Future<void> _pending = Future<void>.value();

  @override
  CallState get currentState => _currentState;

  // Cached so widgets that read the stream in build() do not resubscribe on
  // every rebuild.
  @override
  late final Stream<CallState> callStateStream =
      Stream<CallState>.multi((listener) {
    listener.add(_currentState);
    final subscription = _controller.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  }, isBroadcast: true);

  @override
  Future<void> initialize() => _serialized(() async {
        _refCount++;
        if (_refCount > 1) return;
        // Subscribe before starting native monitoring so no event is missed.
        final subscription = eventChannel.receiveBroadcastStream().listen(
          _handleCallStateEvent,
          onError: (Object error) {
            debugPrint('call_state_handler: event channel error: $error');
          },
        );
        _eventSubscription = subscription;
        try {
          await methodChannel.invokeMethod<void>('initialize');
        } catch (_) {
          _refCount--;
          _eventSubscription = null;
          await subscription.cancel();
          rethrow;
        }
      });

  @override
  Future<void> dispose() => _serialized(() async {
        if (_refCount == 0) return;
        _refCount--;
        if (_refCount > 0) return;
        final subscription = _eventSubscription;
        _eventSubscription = null;
        await subscription?.cancel();
        _emit(const CallState.initial());
        await methodChannel.invokeMethod<void>('dispose');
      });

  Future<void> _serialized(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.catchError((_) {});
    return result;
  }

  @override
  Future<void> setVoipDetectionEnabled(bool enabled) {
    return methodChannel.invokeMethod<void>(
      'setVoipDetectionEnabled',
      {'enabled': enabled},
    );
  }

  void _handleCallStateEvent(dynamic event) {
    if (event is! Map) return;
    final isCallActive = event['isCallActive'] as bool? ?? false;
    final callType = switch (event['callType']) {
      'phoneCall' => CallType.phoneCall,
      'videoCall' => CallType.videoCall,
      _ => CallType.none,
    };
    _emit(
      isCallActive
          ? CallState(isCallActive: true, callType: callType)
          : const CallState.initial(),
    );
  }

  void _emit(CallState state) {
    if (state == _currentState) return;
    _currentState = state;
    _controller.add(state);
  }
}
