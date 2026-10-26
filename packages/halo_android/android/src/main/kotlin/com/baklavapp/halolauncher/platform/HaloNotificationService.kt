package com.baklavapp.halolauncher.platform

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Android's notification listener for Halo. The user grants it in Settings
 * (notification access); while connected it is the [current] instance, and
 * every change calls [onChange] so the plugin can tell Dart to reload. Holding
 * this grant is also what lets Halo read media sessions.
 */
class HaloNotificationService : NotificationListenerService() {
    override fun onListenerConnected() {
        current = this
        onChange?.invoke()
    }

    override fun onListenerDisconnected() {
        if (current === this) current = null
        onChange?.invoke()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        onChange?.invoke()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        onChange?.invoke()
    }

    companion object {
        @Volatile
        var current: HaloNotificationService? = null
            private set

        /** Set by the plugin; called on the main thread. */
        var onChange: (() -> Unit)? = null
    }
}
