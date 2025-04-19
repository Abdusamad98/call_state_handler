## Call State Handler
A Flutter plugin that detects phone calls and video calls on both Android and iOS platforms. This plugin helps you monitor call states in your app, allowing you to take appropriate actions when calls start or end.

## Features
Detect when a phone call is active or ended
Distinguish between regular phone calls and video/VoIP calls
Works on both Android and iOS platforms
Simple Stream-based API for reactive UI updates
Low battery consumption
No special permissions required

## Platform-specific Setup
## Android
No additional setup required for Android.
## iOS
Update your Info.plist file to include the following:

<key>NSCallingCapabilityUsageDescription</key>
<string>App needs call detection to pause activities during calls</string>


## How It Works
## Android
Uses the Android AudioManager to detect changes in audio session mode, which changes during phone calls and VoIP/video calls.
## iOS
Implements CallKit's CXCallObserver to monitor call states on iOS devices.



## Usage
## Basic Implementation
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

## With BLoC/Cubit

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:call_state_handler/call_detector.dart';

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

