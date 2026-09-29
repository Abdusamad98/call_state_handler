import CallKit
import CoreTelephony
import Flutter
import UIKit

/// Detects calls with CallKit's CXCallObserver, which sees every call the
/// system knows about: cellular calls and calls from VoIP apps that report them
/// to CallKit (FaceTime, WhatsApp, Telegram, Zoom, Google Meet, Teams, ...).
///
/// CXCall does not say which app owns a call, so CoreTelephony's CTCallCenter,
/// which lists cellular calls only, classifies it: a call CallKit sees while
/// CTCallCenter also sees one is "phoneCall", otherwise "videoCall". CallKit is
/// the source of truth for whether any call exists, so a stale CTCallCenter
/// entry can never report a call on its own. The app's AVAudioSession is never
/// touched.
public class CallDetectorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CXCallObserverDelegate {
    private static let typeNone = "none"
    private static let typePhone = "phoneCall"
    private static let typeVideo = "videoCall"

    private var callObserver: CXCallObserver?
    private var callCenter: CTCallCenter?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var eventSink: FlutterEventSink?
    private var voipDetectionEnabled = true
    private var callType = CallDetectorPlugin.typeNone

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
            let arguments = call.arguments as? [String: Any]
            voipDetectionEnabled = arguments?["enabled"] as? Bool ?? true
            refreshState()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startMonitoring() {
        guard callObserver == nil else { return }
        let observer = CXCallObserver()
        // A nil queue delivers delegate calls on the main queue.
        observer.setDelegate(self, queue: nil)
        callObserver = observer

        let center = CTCallCenter()
        // CTCallCenter can update after CallKit has already reported a cellular
        // call; refresh again so the call is reclassified as "phoneCall". The
        // handler runs on a background queue.
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
        callObserver?.setDelegate(nil, queue: nil)
        callObserver = nil
        callCenter?.callEventHandler = nil
        callCenter = nil
        callType = CallDetectorPlugin.typeNone
    }

    private func refreshState() {
        guard let observer = callObserver else { return }
        // Ringing, dialing, connected and held calls all count, like Android's
        // MODE_RINGTONE / MODE_IN_CALL.
        let hasCall = observer.calls.contains { !$0.hasEnded }
        let hasCellularCall = callCenter?.currentCalls?.contains {
            $0.callState != CTCallStateDisconnected
        } ?? false

        let newType: String
        if hasCall && hasCellularCall {
            newType = CallDetectorPlugin.typePhone
        } else if hasCall && voipDetectionEnabled {
            newType = CallDetectorPlugin.typeVideo
        } else {
            newType = CallDetectorPlugin.typeNone
        }

        if newType != callType {
            callType = newType
            sendState()
        }
    }

    private func sendState() {
        eventSink?([
            "isCallActive": callType != CallDetectorPlugin.typeNone,
            "callType": callType,
        ])
    }

    public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        refreshState()
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
