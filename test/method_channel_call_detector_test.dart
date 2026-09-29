import 'dart:async';

import 'package:call_state_handler/call_state_handler.dart';
import 'package:call_state_handler/models/method_channel_call_detector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TestDefaultBinaryMessenger get messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelCallDetector detector;
  late List<MethodCall> methodCalls;
  late StreamController<Object?> nativeEvents;
  late int eventListenCount;

  setUp(() {
    detector = MethodChannelCallDetector();
    methodCalls = [];
    nativeEvents = StreamController<Object?>.broadcast();
    eventListenCount = 0;

    messenger.setMockMethodCallHandler(MethodChannelCallDetector.methodChannel,
        (call) async {
      methodCalls.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      MethodChannelCallDetector.eventChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          eventListenCount++;
          nativeEvents.stream.listen(sink.success);
        },
      ),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
        MethodChannelCallDetector.methodChannel, null);
    messenger.setMockStreamHandler(
        MethodChannelCallDetector.eventChannel, null);
    nativeEvents.close();
  });

  Future<void> sendNative(bool active, String type) async {
    nativeEvents.add({'isCallActive': active, 'callType': type});
    await pumpEventQueue();
  }

  test('new listener immediately receives the current state', () async {
    final states = <CallState>[];
    detector.callStateStream.listen(states.add);
    await pumpEventQueue();

    expect(states, [const CallState.initial()]);
  });

  test('maps native events and drops duplicates', () async {
    final states = <CallState>[];
    detector.callStateStream.listen(states.add);
    await detector.initialize();

    await sendNative(true, 'phoneCall');
    await sendNative(true, 'phoneCall');
    await sendNative(true, 'videoCall');
    await sendNative(false, 'none');
    await sendNative(true, 'unknown');

    expect(states, [
      const CallState.initial(),
      const CallState(isCallActive: true, callType: CallType.phoneCall),
      const CallState(isCallActive: true, callType: CallType.videoCall),
      const CallState.initial(),
      const CallState(isCallActive: true, callType: CallType.none),
    ]);
    expect(detector.currentState,
        const CallState(isCallActive: true, callType: CallType.none));
  });

  test('initialize is reference counted', () async {
    await Future.wait([detector.initialize(), detector.initialize()]);
    await detector.initialize();
    await pumpEventQueue();

    expect(methodCalls.where((c) => c.method == 'initialize'), hasLength(1));
    expect(eventListenCount, 1);
  });

  test('dispose resets to inactive and the stream keeps working', () async {
    final states = <CallState>[];
    detector.callStateStream.listen(states.add);
    await detector.initialize();
    await sendNative(true, 'videoCall');

    await detector.dispose();
    expect(detector.currentState, const CallState.initial());

    await detector.initialize();
    await sendNative(true, 'phoneCall');

    expect(states, [
      const CallState.initial(),
      const CallState(isCallActive: true, callType: CallType.videoCall),
      const CallState.initial(),
      const CallState(isCallActive: true, callType: CallType.phoneCall),
    ]);
    expect(methodCalls.map((c) => c.method),
        ['initialize', 'dispose', 'initialize']);
  });

  test('monitoring stops only when the last caller disposes', () async {
    final states = <CallState>[];
    detector.callStateStream.listen(states.add);

    // New screen initializes before the old one disposes (pushReplacement).
    await detector.initialize();
    await detector.initialize();
    await sendNative(true, 'phoneCall');
    await detector.dispose();

    expect(detector.currentState,
        const CallState(isCallActive: true, callType: CallType.phoneCall));
    expect(methodCalls.map((c) => c.method), ['initialize']);

    await detector.dispose();
    await detector.dispose(); // extra dispose is ignored

    expect(detector.currentState, const CallState.initial());
    expect(methodCalls.map((c) => c.method), ['initialize', 'dispose']);
    expect(states.last, const CallState.initial());
  });

  test('stream getter returns the same instance', () {
    expect(
        identical(detector.callStateStream, detector.callStateStream), isTrue);
  });

  test('late listener gets the active state, not the initial one', () async {
    await detector.initialize();
    await sendNative(true, 'phoneCall');

    final first = await detector.callStateStream.first;
    expect(first,
        const CallState(isCallActive: true, callType: CallType.phoneCall));
  });

  test('setVoipDetectionEnabled forwards the flag', () async {
    await detector.setVoipDetectionEnabled(false);

    expect(methodCalls.single.method, 'setVoipDetectionEnabled');
    expect(methodCalls.single.arguments, {'enabled': false});
  });
}
