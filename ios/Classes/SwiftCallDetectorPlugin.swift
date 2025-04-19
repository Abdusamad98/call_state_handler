import Flutter
import UIKit
import CallKit

public class SwiftCallDetectorPlugin: NSObject, FlutterPlugin {
    private var callObserver: CXCallObserver?
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "com.example.call_detector/methods", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "com.example.call_detector/events", binaryMessenger: registrar.messenger())

        let instance = SwiftCallDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initializeCallObserver()
            result(nil)
        case "dispose":
            disposeCallObserver()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initializeCallObserver() {
        callObserver = CXCallObserver()
        callObserver?.setDelegate(self, queue: nil)
    }

    private func disposeCallObserver() {
        callObserver = nil
    }

    private func sendCallState(isCallActive: Bool, callType: String) {
        let callState: [String: Any] = [
            "isCallActive": isCallActive,
            "callType": callType
        ]

        DispatchQueue.main.async {
            self.eventSink?(callState)
        }
    }
}

extension SwiftCallDetectorPlugin: CXCallObserverDelegate {
    public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        let isCallActive = call.hasEnded == false

        // In iOS, we can't definitively determine if it's a video call through CallKit
        // But we can make an educated guess based on whether it's a VoIP call
        let callType = call.isOutgoing ? "phoneCall" : "phoneCall"

        sendCallState(isCallActive: isCallActive, callType: callType)
    }
}

extension SwiftCallDetectorPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}