Call State Handler
A Flutter plugin that detects phone calls and video calls on both Android and iOS platforms. This plugin helps you monitor call states in your app, allowing you to take appropriate actions when calls start or end.
Features

Detect when a phone call is active or ended
Distinguish between regular phone calls and video/VoIP calls
Works on both Android and iOS platforms
Simple Stream-based API for reactive UI updates
Low battery consumption
No special permissions required

Getting Started
Add Dependency
dependencies:
call_state_handler: ^1.0.0




## Usage

import 'package:call_state_handler/call_detector.dart';
import 'package:flutter/material.dart';

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

```dart
const like = 'sample';
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
