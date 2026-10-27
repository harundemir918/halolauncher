package com.baklavapp.halolauncher.platform

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Process
import android.os.SystemClock
import android.provider.Settings

/**
 * Which apps the user used last, from Android's usage events. The grant is
 * "usage access", which the user gives in Settings; without it nothing is
 * read. Only the owner's apps show: work profile usage isn't visible here.
 */
class UsageController(private val context: Context) {
    fun canRead(): Boolean {
        val ops = context.getSystemService(AppOpsManager::class.java)
        return ops.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
        ) == AppOpsManager.MODE_ALLOWED
    }

    fun request() {
        try {
            context.startActivity(
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, Uri.fromParts("package", context.packageName, null))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: ActivityNotFoundException) {
            context.startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    /**
     * Packages brought to the foreground in the last [hours], and since the
     * phone started, newest first, each with the time it was last in front.
     * Halo itself is left out.
     *
     * Android tells a launcher nothing about which apps are still open, and
     * the public events only say an app left the screen, not whether it was
     * closed, so this is a history of use, not the system's Overview.
     */
    fun recent(hours: Int = 1, limit: Int = 30): List<Map<String, Any>> {
        if (!canRead()) return emptyList()
        val now = System.currentTimeMillis()
        // Events from before the phone started describe screens that are gone.
        val boot = now - SystemClock.elapsedRealtime()
        val events = context.getSystemService(UsageStatsManager::class.java)
            .queryEvents(maxOf(boot, now - hours * HOUR_MS), now)
        val last = LinkedHashMap<String, Long>()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED && event.packageName != context.packageName) {
                last[event.packageName] = event.timeStamp
            }
        }
        return last.entries
            .sortedByDescending { it.value }
            .take(limit)
            .map { mapOf("package" to it.key, "time" to it.value) }
    }

    private companion object {
        const val HOUR_MS = 60 * 60 * 1000L
    }
}
