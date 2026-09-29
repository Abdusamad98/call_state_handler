# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`call_state_handler` is a published Flutter plugin (pub.dev) that detects active phone calls on Android (Kotlin) and iOS (Swift), and VoIP/video calls on Android only. Its main consumer shows a "blocker" UI while the user is on a call, so **false positives (reporting a call when there is none) are the worst bug class**.

## Commands

```bash
flutter pub get
flutter analyze                  # lints: package:flutter_lints/flutter.yaml
dart format lib test
flutter test                     # Dart unit tests (mock method + event channels)
flutter test test/method_channel_call_detector_test.dart --plain-name "initialize is reference counted"   # one test
flutter pub publish --dry-run

# Native code only compiles through the example app:
cd example && flutter build apk --debug
cd example && flutter build ios --debug --no-codesign
```

Release checklist: bump `version` in `pubspec.yaml` **and** `ios/call_state_handler.podspec`, then add a `CHANGELOG.md` entry.

## Hard constraints

- **Never use CallKit on iOS** (no `import CallKit`, no `CXCallObserver`). Apps that link it are rejected from the China mainland App Store. After an iOS change, verify with `otool -L example/build/ios/iphoneos/Runner.app/Frameworks/call_state_handler.framework/call_state_handler`. It should list only CoreTelephony and system libraries.
- **Never modify the host app's `AVAudioSession`** (category, activation). Host apps have their own players and recorders.
- **Android must not require permissions.** Detection uses only `AudioManager.getMode()`. Foreground-app detection (UsageStats/ActivityManager) was removed in 2.0.0 because it caused false positives.

## Architecture

It follows the federated plugin pattern (`plugin_platform_interface`), but all code lives in a single package:

- `lib/call_state_handler.dart`: the public singleton `CallStateHandler`. It exposes `initialize`, `dispose`, `onCallStateChanged`, `currentState` and `setVoipDetectionEnabled`, and re-exports `CallState`/`CallType`.
- `lib/models/call_detector_platform_interface.dart`: `CallDetectorPlatform`. Tests can swap `CallDetectorPlatform.instance`.
- `lib/models/method_channel_call_detector.dart`: the default implementation. Invariants the tests rely on:
  - One broadcast controller that is **never closed**. `dispose()` emits `CallState.initial()` rather than closing, so listeners never get stuck on an "active" state.
  - `callStateStream` uses `Stream.multi` to replay `_currentState` to each new listener.
  - `initialize()`/`dispose()` are **reference counted** and serialized through `_pending`. Several widgets share the singleton, and Flutter runs a new route's `initState` before the old route's `dispose`. Native monitoring starts on the first `initialize` and stops on the last `dispose`.
  - `initialize()` subscribes to the event channel *before* invoking native `initialize`.
  - `callStateStream` is a cached `late final` field, so `StreamBuilder`s don't resubscribe on every rebuild.
  - Consecutive equal states are dropped (`CallState` has value equality).

### Platform channel contract

These names are hardcoded in Dart, `android/.../CallDetectorPlugin.kt` and `ios/Classes/CallDetectorPlugin.swift`. If you change one, change all three.

- Method channel `com.example.call_detector/methods`: `initialize`, `dispose`, `setVoipDetectionEnabled({enabled: bool})`.
- Event channel `com.example.call_detector/events`: each event is a map `{isCallActive: bool, callType: "none"|"phoneCall"|"videoCall"}`. Both platforms send the current state from `onListen`.

### Android (`CallDetectorPlugin.kt`)

- Polls `AudioManager.mode` every 1 s on the main looper.
- In-call, ringtone, call screening and call redirect modes → `phoneCall`.
- `MODE_IN_COMMUNICATION` / `MODE_COMMUNICATION_REDIRECT` → `videoCall`, but only when VoIP detection is enabled **and** the mode has lasted `VOIP_DEBOUNCE_CHECKS` consecutive checks. Voice-message recorders set this mode too.
- `setVoipDetectionEnabled` resets the debounce counter.
- Emits whenever `isCallActive` or `callType` changes.

### iOS (`CallDetectorPlugin.swift`)

- `CTCallCenter.callEventHandler` (called on a background queue, then dispatched to main) → any call in `currentCalls` that is not `CTCallStateDisconnected` → `phoneCall`. The state is also re-checked on `UIApplication.didBecomeActiveNotification`.
- There is no VoIP detection, and `setVoipDetectionEnabled` is a no-op. CTCallCenter is deprecated, but it is the only CallKit-free option. Real-device testing is required, because simulators have no telephony.
