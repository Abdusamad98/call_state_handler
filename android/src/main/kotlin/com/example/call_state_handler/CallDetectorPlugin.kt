package com.example.call_state_handler
import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class CallDetectorPlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler, CallStateCallback {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var audioManager: AudioManager? = null
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private val audioSessionChecker = Runnable { checkAudioSessionMode() }
    private var isChecking = false
    private var isCallActive = false
    private var currentCallType = "none"

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.call_detector/methods")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.example.call_detector/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> {
                initializeAudioSessionMonitoring()
                result.success(null)
            }
            "dispose" -> {
                disposeAudioSessionMonitoring()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializeAudioSessionMonitoring() {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        isChecking = true
        handler.post(audioSessionChecker)
    }

    private fun disposeAudioSessionMonitoring() {
        isChecking = false
        handler.removeCallbacks(audioSessionChecker)
        audioManager = null
    }

    private fun checkAudioSessionMode() {
        if (!isChecking) return

        audioManager?.let { am ->
            val mode = am.mode
            val wasCallActive = isCallActive

            // Check if it's a call
            isCallActive = when (mode) {
                AudioManager.MODE_IN_CALL,
                AudioManager.MODE_IN_COMMUNICATION,
                AudioManager.MODE_RINGTONE -> true
                else -> false
            }

            // Try to determine if it's a video call or audio call
            if (isCallActive) {
                currentCallType = if (mode == AudioManager.MODE_IN_COMMUNICATION) {
                    "videoCall" // Most likely a VoIP or video call
                } else {
                    "phoneCall" // Regular phone call
                }
            } else {
                currentCallType = "none"
            }

            // Notify only when state changes
            if (wasCallActive != isCallActive) {
                onCallStateChanged(isCallActive, currentCallType)
            }
        }

        // Schedule next check
        handler.postDelayed(audioSessionChecker, 1000) // Check every second
    }

    override fun onCallStateChanged(isCallActive: Boolean, callType: String) {
        val callStateMap = mapOf(
            "isCallActive" to isCallActive,
            "callType" to callType
        )

        handler.post {
            eventSink?.success(callStateMap)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        disposeAudioSessionMonitoring()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}

