package com.example.call_state_handler
import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.media.AudioManager
import android.os.Build
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
    private var activityManager: ActivityManager? = null
    private var usageStatsManager: UsageStatsManager? = null
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private val audioSessionChecker = Runnable { checkAudioSessionMode() }
    private var isChecking = false
    private var isCallActive = false
    private var currentCallType = "none"
    
    // Known video calling app package names
    private val videoCallingApps = setOf(
        "com.google.android.apps.meetings", // Google Meet
        "us.zoom.videomeetings", // Zoom
        "com.microsoft.teams", // Microsoft Teams
        "com.skype.raider", // Skype
        "com.whatsapp", // WhatsApp
        "com.facebook.orca", // Facebook Messenger
        "com.viber.voip", // Viber
        "com.discord", // Discord
        "com.tencent.mm", // WeChat
        "com.snapchat.android", // Snapchat
        "com.instagram.android", // Instagram
        "com.google.android.apps.tachyon", // Google Duo (now part of Meet)
        "com.apple.facetime", // FaceTime (if available on Android)
        "com.linkedin.android", // LinkedIn
        "com.webex.meetings", // Cisco Webex
        "com.gotomeeting", // GoToMeeting
        "com.bluejeansnetworks.android", // BlueJeans
        "com.amazon.chime", // Amazon Chime
        "com.jitsi.meet", // Jitsi Meet
        "com.ringcentral.meetings" // RingCentral
    )

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
        activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        }
        isChecking = true
        handler.post(audioSessionChecker)
    }

    private fun disposeAudioSessionMonitoring() {
        isChecking = false
        handler.removeCallbacks(audioSessionChecker)
        audioManager = null
        activityManager = null
        usageStatsManager = null
    }

    private fun checkAudioSessionMode() {
        if (!isChecking) return

        audioManager?.let { am ->
            val mode = am.mode
            val wasCallActive = isCallActive
            val foregroundApp = getForegroundAppPackageName()

            // Check if it's a call based on audio mode
            val audioCallActive = when (mode) {
                AudioManager.MODE_IN_CALL,
                AudioManager.MODE_IN_COMMUNICATION,
                AudioManager.MODE_RINGTONE -> true
                else -> false
            }

            // Check if a video calling app is in foreground
            val videoAppActive = foregroundApp != null && videoCallingApps.contains(foregroundApp)

            // Determine call state: active if audio mode indicates call OR video app is active
            isCallActive = audioCallActive || videoAppActive

            // Determine call type
            if (isCallActive) {
                currentCallType = when {
                    // If a known video calling app is active, it's definitely a video call
                    videoAppActive -> "videoCall"
                    // If audio mode is IN_COMMUNICATION, it's likely a VoIP/video call
                    mode == AudioManager.MODE_IN_COMMUNICATION -> "videoCall"
                    // Otherwise, it's a regular phone call
                    else -> "phoneCall"
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

    /**
     * Get the package name of the foreground app
     * Uses ActivityManager for older Android versions and UsageStatsManager for newer ones
     */
    private fun getForegroundAppPackageName(): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ (API 29+): Use UsageStatsManager
                usageStatsManager?.let { usm ->
                    val time = System.currentTimeMillis()
                    val stats = usm.queryUsageStats(
                        UsageStatsManager.INTERVAL_DAILY,
                        time - 1000 * 60, // Last minute
                        time
                    )
                    stats?.maxByOrNull { it.lastTimeUsed }?.packageName
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                // Android 5.0+ (API 21+): Try UsageStatsManager first, fallback to ActivityManager
                usageStatsManager?.let { usm ->
                    val time = System.currentTimeMillis()
                    val stats = usm.queryUsageStats(
                        UsageStatsManager.INTERVAL_DAILY,
                        time - 1000 * 60,
                        time
                    )
                    stats?.maxByOrNull { it.lastTimeUsed }?.packageName
                } ?: getForegroundAppFromActivityManager()
            } else {
                // Older Android versions: Use ActivityManager
                getForegroundAppFromActivityManager()
            }
        } catch (e: Exception) {
            // Fallback to ActivityManager if UsageStatsManager fails
            getForegroundAppFromActivityManager()
        }
    }

    /**
     * Fallback method using ActivityManager (works on older Android versions)
     * Note: This method may not work on Android 5.1+ due to security restrictions
     */
    private fun getForegroundAppFromActivityManager(): String? {
        return try {
            activityManager?.let { am ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    // Android 6.0+ (API 23+)
                    am.appTasks?.firstOrNull()?.taskInfo?.topActivity?.packageName
                } else {
                    // Older versions
                    @Suppress("DEPRECATION")
                    am.getRunningTasks(1)?.firstOrNull()?.topActivity?.packageName
                }
            }
        } catch (e: Exception) {
            null
        }
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

