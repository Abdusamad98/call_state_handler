## 2.0.0

**Breaking changes**
* **iOS**: Removed CallKit. Apps using the plugin are no longer rejected for the China mainland App Store. Phone calls are now detected with CoreTelephony (`CTCallCenter`). VoIP/video calls are no longer reported on iOS.
* **iOS**: The plugin no longer changes or deactivates the app's `AVAudioSession`. Previously it could silence or stop the app's own audio.
* **Android**: Removed foreground-app detection. Opening apps such as WhatsApp or Instagram was wrongly reported as a video call.
* **Android**: Removed the unused `READ_PHONE_STATE` permission. The minimum SDK is now 21.

**Fixes**
* Fixed false "call active" states:
  * `MODE_IN_COMMUNICATION` is now debounced (~3 s) before it is reported as a video call.
  * `dispose()` no longer leaves listeners stuck on the last state.
* `initialize()`/`dispose()` are now reference counted. Previously, when one screen disposed, monitoring stopped for every other screen (for example after `pushReplacement`), and repeated `initialize()` calls duplicated subscriptions and polling loops.
* Each new listener now receives the current state immediately.
* **iOS**: The call state is re-checked when the app becomes active.
* Call type changes during a call are now emitted on Android.

**New**
* `CallStateHandler.setVoipDetectionEnabled(bool)`: disable VoIP detection while your app records audio.
* `CallStateHandler.currentState`.
* `CallState` has value equality and `const` constructors. `CallState` is exported from `package:call_state_handler/call_state_handler.dart`.
* Added an example app and unit tests.

## 1.1.0

* **NEW**: Enhanced video call detection for popular apps (Google Meet, Zoom, Microsoft Teams, Skype, WhatsApp, Discord, and more)
* **Android**: Added foreground app monitoring using UsageStatsManager and ActivityManager to detect video calling apps
* **iOS**: Added AVAudioSession monitoring to detect video calls from other apps
* **Android**: Added support for detecting 20+ video calling apps by package name
* **iOS**: Improved detection accuracy by monitoring audio session interruptions and route changes
* Updated documentation with new features and platform-specific setup instructions
* **Privacy-friendly**: Only requires `READ_PHONE_STATE` permission by default. Enhanced detection permissions are optional and documented for apps that need them

## 1.0.1

* Initial release !!!
* plugin_platform_interface upgraded to latest version. 