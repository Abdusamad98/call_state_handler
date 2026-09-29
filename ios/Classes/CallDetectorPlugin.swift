import CoreTelephony
import Flutter
import UIKit

/// Detects cellular phone calls with CoreTelephony's CTCallCenter.
///
/// CallKit is intentionally not used: apps linking CallKit are rejected for the
/// China mainland App Store. Without CallKit there is no reliable way to detect
/// VoIP/video calls from other apps, so iOS only reports "phoneCall". The app's
/// AVAudioSession is never touched.
public class CallDetectorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var callCenter: CTCallCenter?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var eventSink: FlutterEventSink?
    private var isCallActive = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.example.call_detector/methods",
            binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(
            name: "com.example.call_detector/events",
            binaryMessenger: registrar.messenger())

        let instance = CallDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            startMonitoring()
            result(nil)
        case "dispose":
            stopMonitoring()
            result(nil)
        case "setVoipDetectionEnabled":
            // VoIP detection is not available on iOS.
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startMonitoring() {
        guard callCenter == nil else { return }
        let center = CTCallCenter()
        // The handler runs on a background queue.
        center.callEventHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.refreshState() }
        }
        callCenter = center
        // Call events can be delayed while the app is suspended; re-check on resume.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshState()
        }
        refreshState()
    }

    private func stopMonitoring() {
        if let observer = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            didBecomeActiveObserver = nil
        }
        callCenter?.callEventHandler = nil
        callCenter = nil
        isCallActive = false
    }

    private func refreshState() {
        guard let center = callCenter else { return }
        let active = center.currentCalls?.contains { $0.callState != CTCallStateDisconnected } ?? false
        if active != isCallActive {
            isCallActive = active
            sendState()
        }
    }

    private func sendState() {
        eventSink?([
            "isCallActive": isCallActive,
            "callType": isCallActive ? "phoneCall" : "none",
        ])
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        sendState()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
