## Call State Handler
A Flutter plugin that detects active phone calls on Android and iOS, and VoIP/video calls (Google Meet, Zoom, WhatsApp, Teams, ...) on Android. Use it to pause or block parts of your app while the user is on a call.

## Features
- Detects when a phone call starts and ends (Android and iOS)
- Detects VoIP/video calls on Android
- **No CallKit** on iOS, so apps using this plugin can be distributed in the China mainland App Store
- **No permissions required**
- Does not modify your app's audio session
- Stream-based API that emits the current state to every new listener

## Platform support

| | Phone calls | VoIP / video calls |
|---|---|---|
| Android | ✅ | ✅ |
| iOS | ✅ | ❌ (see below) |

## How It Works
### Android
The plugin checks the system audio mode (`AudioManager.getMode()`) once per second:
- `MODE_IN_CALL` / `MODE_RINGTONE` (and call screening/redirect modes) → `CallType.phoneCall`
- `MODE_IN_COMMUNICATION` → `CallType.videoCall`, reported only after the mode has been stable for about 3 seconds

Some non-call features also switch the device into `MODE_IN_COMMUNICATION`, for example voice-message recorders, voice chat in games and some Bluetooth headsets. If your app records audio itself, turn VoIP detection off while recording (see [Recording audio in your app](#recording-audio-in-your-app)).

### iOS
Phone calls are detected with CoreTelephony's `CTCallCenter`.

iOS offers no reliable way to detect VoIP/video calls from other apps without CallKit. Apps that use CallKit are not allowed in the China mainland App Store, so this plugin does not use it and reports only regular phone calls on iOS. `setVoipDetectionEnabled` does nothing on iOS.

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
If your app records voice messages or otherwise uses the microphone, disable VoIP detection while recording. Otherwise the recording can be reported as a video call on Android:

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

