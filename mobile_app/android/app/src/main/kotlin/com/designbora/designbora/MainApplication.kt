package com.designbora.designbora

import android.app.Application
import android.os.Bundle
import android.util.Log
import com.hiennv.flutter_callkit_incoming.CallkitEventCallback
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Kitufe cha "Kataa" kwenye skrini ya simu ya mfumo, app ikiwa imefungwa kabisa:
 * inatuma ombi moja kwa server kwa ufunguo wa simu hiyo (declineKey) - haihitaji login.
 */
class MainApplication : Application() {

    private val callkitEventCallback = object : CallkitEventCallback {
        override fun onCallEvent(event: CallkitEventCallback.CallEvent, callData: Bundle) {
            if (event != CallkitEventCallback.CallEvent.DECLINE) return

            @Suppress("UNCHECKED_CAST", "DEPRECATION")
            val extra = callData.getSerializable("EXTRA_CALLKIT_EXTRA") as? HashMap<String, Any?> ?: return
            val callId = extra["callId"]?.toString() ?: return
            val key = extra["declineKey"]?.toString()?.takeIf { it.isNotBlank() } ?: return
            val apiBase = extra["apiBase"]?.toString() ?: return

            Thread {
                try {
                    val url = URL("$apiBase/calls/$callId/decline?key=" + URLEncoder.encode(key, "UTF-8"))
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.connectTimeout = 10_000
                    conn.readTimeout = 10_000
                    conn.doOutput = true
                    conn.outputStream.use { it.write(ByteArray(0)) }
                    Log.d(TAG, "Simu #$callId imekataliwa: ${conn.responseCode}")
                    conn.disconnect()
                } catch (e: Exception) {
                    Log.w(TAG, "Kukataa simu #$callId kumeshindwa: ${e.message}")
                }
            }.start()
        }
    }

    override fun onCreate() {
        super.onCreate()
        FlutterCallkitIncomingPlugin.registerEventCallback(callkitEventCallback)
    }

    companion object {
        private const val TAG = "DesignBoraCall"
    }
}
