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