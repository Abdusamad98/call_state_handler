## Call State Handler
A Flutter plugin that detects active phone calls and VoIP/video calls (Google Meet, Zoom, WhatsApp, Teams, FaceTime, ...) on Android and iOS. Use it to pause or block parts of your app while the user is on a call.

## Features
- Detects when a phone call starts and ends (Android and iOS)
- Detects VoIP/video calls on Android and iOS
- **No permissions required**
- Does not modify your app's audio session
- Stream-based API that emits the current state to every new listener

## Platform support

| | Phone calls | VoIP / video calls |
|---|---|---|
| Android | ✅ | ✅ |
| iOS | ✅ | ✅ (apps that use CallKit, see below) |

## How It Works
### Android
The plugin checks the system audio mode (`AudioManager.getMode()`) once per second:
- `MODE_IN_CALL` / `MODE_RINGTONE` (and call screening/redirect modes) → `CallType.phoneCall`
- `MODE_IN_COMMUNICATION` → `CallType.videoCall`, reported only after the mode has been stable for about 3 seconds

This covers calls in apps such as WhatsApp, Telegram, Instagram/Messenger, Google Meet, Zoom, Teams, Skype, Viber and Discord, and usually Google Meet in Chrome, because they all switch into `MODE_IN_COMMUNICATION` during a call.

Limitations:
- Incoming VoIP calls are not detected while they ring. Apps play their own ringtone without changing the audio mode, so the call is reported once it is answered. Outgoing VoIP calls are reported while dialing. Ringing cellular calls are detected.
- VoIP calls are reported about 3 seconds after they start.
- Calls without audio are not detected, for example a Zoom meeting joined without connecting audio.
- The audio mode does not say which app set it, so some non-call features are reported as `videoCall` when they last longer than about 3 seconds. Examples are voice-message recording in other apps, voice chat in games, and some Bluetooth headsets. `setVoipDetectionEnabled(false)` only helps while *your* app records audio (see [Recording audio in your app](#recording-audio-in-your-app)).
- Some apps or devices leave the mode at `MODE_IN_COMMUNICATION` after a call ends. The plugin then keeps reporting `videoCall` until the mode is reset. If you block your UI during calls, consider giving users a way to dismiss the blocker.

### iOS
Calls are detected with CallKit's `CXCallObserver`. It sees every call the system knows about: cellular calls and calls from apps that report them to CallKit, such as FaceTime, WhatsApp, Telegram, Zoom, Google Meet, Microsoft Teams and Skype. Ringing, dialing, connected and held calls all count as active.

CallKit does not say which app owns a call, so the plugin asks CoreTelephony's `CTCallCenter`, which lists cellular calls only:
- a call that `CTCallCenter` also sees → `CallType.phoneCall`
- any other call → `CallType.videoCall` (VoIP, audio or video)

Limitations:
- Calls are detected only when the calling app reports them to CallKit. Meetings in a browser (e.g. Google Meet in Safari), and apps where the user or the region turned CallKit integration off (e.g. Zoom's "Integrate with iOS Call" setting), are not detected.
- iOS cannot tell a VoIP audio call from a video call, so both are `CallType.videoCall`.
- When a cellular call starts, it can be reported as `videoCall` for a moment before it becomes `phoneCall`.
- `setVoipDetectionEnabled(false)` hides VoIP calls on iOS too. Unlike Android, audio recording is never mistaken for a call on iOS, so you do not need to disable it while recording.
- Simulators have no telephony and no other calling apps; test on a real device.

> **China mainland App Store:** apps that link CallKit are rejected there. If your app is distributed in China mainland, stay on version 2.x of this plugin, which uses CoreTelephony only.

## Usage
### Basic Implementation

```dart
import 'package:call_state_handler/call_state_handler.dart';
import 'package:flutter/material.dart';

class CallMonitorExample extends StatefulWidget {
  const CallMonitorExample({super.key});

  @override
  State<CallMonitorExample> createState() => _CallMonitorExampleState();
}

class _CallMonitorExampleState extends State<CallMonitorExample> {
  final CallStateHandler _callStateHandler = CallStateHandler();

  @override
  void initState() {
    super.initState();
    _callStateHandler.initialize();
  }

  @override
  void dispose() {
    _callStateHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call Monitor Example')),
      body: StreamBuilder<CallState>(
        stream: _callStateHandler.onCallStateChanged,
        initialData: _callStateHandler.currentState,
        builder: (context, snapshot) {
          final callState = snapshot.data!;
          return Center(
            child: Text(
              callState.isCallActive
                  ? 'Call Active: ${callState.callType == CallType.phoneCall ? "Phone Call" : "Video Call"}'
                  : 'No Active Call',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          );
        },
      ),
    );
  }
}
```

### With BLoC/Cubit

```dart
import 'dart:async';

import 'package:call_state_handler/call_state_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CallMonitorCubit extends Cubit<CallState> {
  final CallStateHandler _callStateHandler = CallStateHandler();
  StreamSubscription<CallState>? _subscription;

  CallMonitorCubit() : super(const CallState.initial()) {
    _subscription = _callStateHandler.onCallStateChanged.listen(emit);
    _callStateHandler.initialize();
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _callStateHandler.dispose();
    return super.close();
  }
}
```

### Recording audio in your app
If your app records voice messages or otherwise uses the microphone, disable VoIP detection while recording. Otherwise the recording can be reported as a video call on Android (iOS is not affected):

```dart
await CallStateHandler().setVoipDetectionEnabled(false);
try {
  await recorder.start(...);
  // ...
  await recorder.stop();
} finally {
  // Always re-enable, even if recording fails; the flag is global.
  await CallStateHandler().setVoipDetectionEnabled(true);
}
```

Phone calls are still detected while VoIP detection is disabled.

### API notes
- `CallStateHandler()` is a singleton, and `initialize()`/`dispose()` are reference counted. Several widgets can use it at the same time, as long as each one balances its `initialize()` with one `dispose()`. Monitoring stops only when the last one disposes.
- `onCallStateChanged` emits the current state immediately to each new listener, then every change.
- `currentState` returns the latest known state synchronously.
- When the last `dispose()` stops monitoring, an inactive state is emitted, so a call-blocking UI is never left stuck. The stream stays usable, and you can call `initialize()` again later.

## Migrating from 2.x
- iOS uses CallKit again and reports VoIP/video calls as `CallType.videoCall`. Apps that link CallKit are rejected from the China mainland App Store; stay on 2.x if you distribute there.
- `setVoipDetectionEnabled` now also applies on iOS.
- No new permissions, `Info.plist` keys or entitlements are needed.

## Migrating from 1.x
- iOS no longer uses CallKit and no longer reports `CallType.videoCall`.
- Android no longer inspects the foreground app. You can remove the `PACKAGE_USAGE_STATS` and `QUERY_ALL_PACKAGES` permissions if you added them only for this plugin.
- The plugin no longer declares `READ_PHONE_STATE`, and `NSCallingCapabilityUsageDescription` is no longer needed.
- `CallState` now has value equality and a `const` constructor.

## Contributing
Contributions are welcome! If you find any issues or have suggestions for improvements:

Open an issue on GitHub
Fork the repository
Create a pull request with your changes

## MIT License

Copyright (c) 2025 Abdusamad

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

