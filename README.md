## Call State Handler
A Flutter plugin that detects phone calls and video calls on both Android and iOS platforms. This plugin helps you monitor call states in your app, allowing you to take appropriate actions when calls start or end.

## Features
Detect when a phone call is active or ended  

Distinguish between regular phone calls and video/VoIP calls  

**Detect video calls from popular apps** including:
- Google Meet
- Zoom
- Microsoft Teams
- Skype
- WhatsApp
- Facebook Messenger
- Discord
- And many more video calling apps

Works on both Android and iOS platforms  

Simple Stream-based API for reactive UI updates  

Low battery consumption  

Minimal permissions required (see Platform-specific Setup)

## Platform-specific Setup
## Android
The plugin requires only one permission:
- `READ_PHONE_STATE` - For detecting phone calls (already included in the plugin)

**Optional Enhanced Detection:**
For better video call detection accuracy, you can optionally add these permissions to your app's `AndroidManifest.xml`:

```xml
<!-- Optional: For detecting foreground video calling apps -->
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" />
<!-- Android 11+ -->
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
```

**Important Notes:**
- `PACKAGE_USAGE_STATS` requires users to manually grant it in **Settings > Apps > Special access > Usage access**
- `QUERY_ALL_PACKAGES` requires Play Store justification for Android 11+
- **The plugin works perfectly without these permissions** - it will use audio mode detection instead
- These permissions only enhance detection accuracy for video calling apps

**Recommendation:** Start without these permissions. The plugin detects video calls via audio mode (`MODE_IN_COMMUNICATION`). Only add these if you need enhanced foreground app detection.

## iOS
Update your Info.plist file to include the following:
```
<key>NSCallingCapabilityUsageDescription</key>
<string>App needs call detection to pause activities during calls</string>
```

**Note**: iOS has limitations detecting video calls from other apps due to sandboxing. The plugin uses AVAudioSession monitoring to detect when video calling apps are active, but detection may not be as precise as on Android.

## How It Works
## Android
- **Phone Calls**: Uses Android AudioManager to detect changes in audio session mode (`MODE_IN_CALL`, `MODE_RINGTONE`)
- **Video Calls**: Combines audio mode detection with foreground app monitoring:
  - Monitors audio session mode (`MODE_IN_COMMUNICATION` indicates VoIP/video calls)
  - Detects when known video calling apps (Google Meet, Zoom, etc.) are in the foreground
  - Uses ActivityManager/UsageStatsManager to identify active video calling apps
  - Provides accurate detection by combining both methods

## iOS
- **Phone Calls**: Implements CallKit's `CXCallObserver` to monitor phone call states
- **Video Calls**: Uses AVAudioSession monitoring to detect when video calling apps are active:
  - Monitors audio session interruptions (when other apps take audio control)
  - Checks audio route changes (microphone/speaker activation)
  - Detects when video calling apps use audio input/output simultaneously
  - Note: iOS sandboxing limits precise detection, but the plugin provides reasonable accuracy



## Usage
## Basic Implementation

```
class CallMonitorExample extends StatefulWidget {
  @override
  _CallMonitorExampleState createState() => _CallMonitorExampleState();
}

class _CallMonitorExampleState extends State<CallMonitorExample> {
  final CallDetector _callDetector = CallDetector();
  
  @override
  void initState() {
    super.initState();
    _initializeCallDetector();
  }
  
  Future<void> _initializeCallDetector() async {
    await _callDetector.initialize();
  }
  
  @override
  void dispose() {
    _callDetector.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Call Monitor Example')),
      body: StreamBuilder<CallState>(
        stream: _callDetector.onCallStateChanged,
        initialData: CallState(isCallActive: false, callType: CallType.none),
        builder: (context, snapshot) {
          final callState = snapshot.data!;
          
          return Center(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: callState.isCallActive ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                callState.isCallActive 
                    ? 'Call Active: ${callState.callType == CallType.phoneCall ? "Phone Call" : "Video Call"}' 
                    : 'No Active Call',
                style: Theme.of(context).textTheme.headline6,
              ),
            ),
          );
        },
      ),
    );
  }
}
```
## With BLoC/Cubit

```
class CallMonitorCubit extends Cubit<CallState> {
  final CallDetector _callDetector = CallDetector();
  StreamSubscription<CallState>? _subscription;

  CallMonitorCubit() : super(CallState(isCallActive: false, callType: CallType.none)) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _callDetector.initialize();
    _subscription = _callDetector.onCallStateChanged.listen((callState) {
      emit(callState);
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _callDetector.dispose();
    return super.close();
  }
}


```
## Error Handling
The plugin automatically handles most error cases. If you encounter any issues, make sure to:

Call initialize() before using the detector
Handle the disposal properly with dispose() when you're done
Check platform compatibility for your specific use case

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

