package com.baklavapp.halolauncher.platform

import android.app.NotificationManager
import android.bluetooth.BluetoothManager
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Handler
import android.provider.Settings

/**
 * The Switchboard's dials and rows, read from and written to the phone with
 * nothing but normal-app access. What Android reserves (switching Wi-Fi,
 * Bluetooth, mobile data or airplane mode; writing brightness or Do Not
 * Disturb without a grant) opens the right Settings screen instead.
 */
class SwitchboardController(
    private val context: Context,
    private val main: Handler,
    private val emit: (String) -> Unit,
) {
    private val audio get() = context.getSystemService(AudioManager::class.java)
    private val connectivity get() = context.getSystemService(ConnectivityManager::class.java)
    private val notifications get() = context.getSystemService(NotificationManager::class.java)
    private val resolver get() = context.contentResolver

    private val settingsObserver = object : ContentObserver(main) {
        override fun onChange(selfChange: Boolean) = emit("quick")
    }

    private val changeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = emit("quick")
    }

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = emit("quick")
        override fun onLost(network: Network) = emit("quick")
        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = emit("quick")
    }

    fun register() {
        resolver.registerContentObserver(Settings.System.CONTENT_URI, true, settingsObserver)
        resolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.AIRPLANE_MODE_ON), false, settingsObserver)
        val filter = IntentFilter().apply {
            addAction(WifiManager.WIFI_STATE_CHANGED_ACTION)
            addAction("android.bluetooth.adapter.action.STATE_CHANGED")
            addAction(Intent.ACTION_AIRPLANE_MODE_CHANGED)
            addAction(NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED)
            addAction(AudioManager.RINGER_MODE_CHANGED_ACTION)
        }
        context.registerReceiver(changeReceiver, filter)
        try {
            connectivity.registerDefaultNetworkCallback(networkCallback, main)
        } catch (e: SecurityException) {
            // No network state; the rows still read the radios.
        }
    }

    fun unregister() {
        resolver.unregisterContentObserver(settingsObserver)
        context.unregisterReceiver(changeReceiver)
        try {
            connectivity.unregisterNetworkCallback(networkCallback)
        } catch (e: IllegalArgumentException) {
            // It was never registered.
        }
    }

    /** Everything the Switchboard shows besides the media strip and the battery. */
    fun read(): Map<String, Any?> {
        val maxVolume = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        return mapOf(
            "brightness" to brightness(),
            "brightnessAuto" to (
                Settings.System.getInt(resolver, Settings.System.SCREEN_BRIGHTNESS_MODE, 0) ==
                    Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
                ),
            "canWriteSettings" to Settings.System.canWrite(context),
            "volume" to audio.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / maxVolume,
            "ringer" to when (audio.ringerMode) {
                AudioManager.RINGER_MODE_SILENT -> "silent"
                AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
                else -> "ring"
            },
            "wifi" to wifi(),
            "bluetooth" to bluetooth(),
            "cellular" to cellular(),
            "airplane" to airplane(),
            "focus" to focus(),
        )
    }

    private fun brightness(): Double =
        Settings.System.getInt(resolver, Settings.System.SCREEN_BRIGHTNESS, 128).coerceIn(0, 255) / 255.0

    private fun wifi(): Map<String, Any> {
        val on = context.getSystemService(WifiManager::class.java)?.isWifiEnabled == true
        // The network's name is location data, so the row says only whether it is connected.
        val connected = on && hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
        return mapOf("on" to on, "state" to if (connected) "connected" else if (on) "on" else "off")
    }

    private fun bluetooth(): Map<String, Any> {
        val on = context.getSystemService(BluetoothManager::class.java)?.adapter?.isEnabled == true
        return mapOf("on" to on, "state" to if (on) "on" else "off")
    }

    private fun cellular(): Map<String, Any> {
        val on = connectivity.allNetworks.any {
            connectivity.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true
        }
        return mapOf("on" to on, "state" to if (on) "connected" else "off")
    }

    private fun airplane(): Map<String, Any> {
        val on = Settings.Global.getInt(resolver, Settings.Global.AIRPLANE_MODE_ON, 0) != 0
        return mapOf("on" to on, "state" to if (on) "on" else "off")
    }

    private fun focus(): Map<String, Any> {
        val on = notifications.currentInterruptionFilter.let {
            it != NotificationManager.INTERRUPTION_FILTER_ALL && it != NotificationManager.INTERRUPTION_FILTER_UNKNOWN
        }
        return mapOf("on" to on, "canChange" to notifications.isNotificationPolicyAccessGranted)
    }

    private fun hasTransport(transport: Int): Boolean {
        val caps = connectivity.getNetworkCapabilities(connectivity.activeNetwork) ?: return false
        return caps.hasTransport(transport)
    }

    /** Sets the level by hand. Without the Write settings grant, asks for it. */
    fun setBrightness(value: Double) {
        if (!Settings.System.canWrite(context)) return requestWriteSettings()
        Settings.System.putInt(
            resolver,
            Settings.System.SCREEN_BRIGHTNESS_MODE,
            Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL,
        )
        Settings.System.putInt(resolver, Settings.System.SCREEN_BRIGHTNESS, (value * 255).toInt().coerceIn(1, 255))
    }

    fun setBrightnessAuto(auto: Boolean) {
        if (!Settings.System.canWrite(context)) return requestWriteSettings()
        Settings.System.putInt(
            resolver,
            Settings.System.SCREEN_BRIGHTNESS_MODE,
            if (auto) Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC else Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL,
        )
    }

    /** The Android Settings page behind a System section. */
    fun openSection(section: String) {
        val action = when (section) {
            "connections" -> Settings.ACTION_WIRELESS_SETTINGS
            "display" -> Settings.ACTION_DISPLAY_SETTINGS
            "sound" -> Settings.ACTION_SOUND_SETTINGS
            "focus" -> "android.settings.ZEN_MODE_SETTINGS"
            "privacy" -> Settings.ACTION_PRIVACY_SETTINGS
            "battery" -> Intent.ACTION_POWER_USAGE_SUMMARY
            else -> return
        }
        start(Intent(action), fallback = Intent(Settings.ACTION_SETTINGS))
    }

    fun requestPolicyAccess() = start(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))

    fun requestWriteSettings() = start(
        Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.fromParts("package", context.packageName, null)),
    )

    fun setVolume(value: Double) {
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        audio.setStreamVolume(AudioManager.STREAM_MUSIC, (value * max).toInt().coerceIn(0, max), 0)
    }

    /** Do Not Disturb on or off; without notification policy access, asks for it. */
    fun setFocus(on: Boolean) {
        if (!notifications.isNotificationPolicyAccessGranted) {
            return requestPolicyAccess()
        }
        notifications.setInterruptionFilter(
            if (on) NotificationManager.INTERRUPTION_FILTER_PRIORITY else NotificationManager.INTERRUPTION_FILTER_ALL,
        )
    }

    /** Android doesn't let an app switch these radios, so open the panel that does. */
    fun openRadio(id: String) {
        val action = when (id) {
            "wifi" -> Settings.Panel.ACTION_WIFI
            "cellular" -> Settings.Panel.ACTION_INTERNET_CONNECTIVITY
            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
            "airplane" -> Settings.ACTION_AIRPLANE_MODE_SETTINGS
            else -> return
        }
        start(Intent(action))
    }

    private fun start(intent: Intent, fallback: Intent? = null) {
        try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: ActivityNotFoundException) {
            // This phone has no such screen: the main Settings page, if given.
            if (fallback != null) start(fallback)
        }
    }
}
