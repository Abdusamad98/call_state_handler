// lib/src/models/call_state.dart
enum CallType { none, phoneCall, videoCall }

class CallState {
  final bool isCallActive;
  final CallType callType;

  CallState({required this.isCallActive, required this.callType});

  factory CallState.initial() {
    return CallState(isCallActive: false, callType: CallType.none);
  }

  @override
  String toString() {
    return 'CallState(isCallActive: $isCallActive, callType: $callType)';
  }
}
