enum CallType { none, phoneCall, videoCall }

class CallState {
  final bool isCallActive;
  final CallType callType;

  const CallState({required this.isCallActive, required this.callType});

  const CallState.initial()
      : isCallActive = false,
        callType = CallType.none;

  @override
  bool operator ==(Object other) =>
      other is CallState &&
      other.isCallActive == isCallActive &&
      other.callType == callType;

  @override
  int get hashCode => Object.hash(isCallActive, callType);

  @override
  String toString() {
    return 'CallState(isCallActive: $isCallActive, callType: $callType)';
  }
}
