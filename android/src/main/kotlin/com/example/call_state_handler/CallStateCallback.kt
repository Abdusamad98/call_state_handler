package com.example.call_state_handler
interface CallStateCallback {
    fun onCallStateChanged(isCallActive: Boolean, callType: String)
}