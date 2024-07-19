package com.almoullim.background_location

import android.annotation.SuppressLint
import android.content.Context
import android.net.wifi.WifiManager
import android.os.PowerManager

/**
 * @author cat
 * @for android
 * @since 2024/7/19
 */
object WakelockUtils {
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null


    @SuppressLint("WakelockTimeout")
    fun acquireLockMode(
        context: Context,
        allowWakeLock: Boolean = true,
        allowWifiLock: Boolean = false
    ) {
        if (allowWakeLock && (wakeLock == null || wakeLock?.isHeld == false)) {
            wakeLock = (context.applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager).run {
                newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ForegroundLocationService:WakeLock").apply {
                    setReferenceCounted(false)
                    acquire()
                }
            }
        }

        if (allowWifiLock && (wifiLock == null || wifiLock?.isHeld == false)) {
            wifiLock = (context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager).run {
                createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "ForegroundLocationService:WifiLock").apply {
                    setReferenceCounted(false)
                    acquire()
                }
            }
        }
    }

    fun releaseLockMode() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                wakeLock = null
            }
        }

        wifiLock?.let {
            if (it.isHeld) {
                it.release()
                wifiLock = null
            }
        }
    }
}