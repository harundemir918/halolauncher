package com.baklavapp.halolauncher.platform

import android.Manifest
import android.app.Activity
import android.app.ActivityOptions
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.ContentUris
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.database.ContentObserver
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.content.pm.ApplicationInfo
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.UserHandle
import android.os.UserManager
import android.app.Notification
import android.os.SystemClock
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.Settings
import android.provider.Telephony
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * The Android side of halo_sdk's AndroidBackend (docs/DECISIONS.md D-019).
 *
 * Calls go over the `halo_android` method channel. Events go over
 * `halo_android/events` as `{"type": ...}` maps:
 * `apps` (installed apps or a profile's lock changed), `home` (Home pressed),
 * `battery`, `defaultHome` (the default home app may have changed),
 * `contacts` (the contacts permission was answered), `calendar` (events or
 * the calendar permission changed), `notifications` (posted, removed, or
 * access changed), `media` (the playing session changed).
 *
 * An app id is the short flattened component name, with `#<user serial>`
 * appended for apps in another profile (work).
 */
class HaloAndroidPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.NewIntentListener,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private lateinit var launcherApps: LauncherApps
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel

    private var activity: ActivityPluginBinding? = null
    private var sink: EventChannel.EventSink? = null

    private val main = Handler(Looper.getMainLooper())

    // Icon decoding is slow enough to drop frames, so it runs here.
    private val worker = Executors.newSingleThreadExecutor()

    private val me: UserHandle get() = Process.myUserHandle()

    private val users: UserManager get() = context.getSystemService(UserManager::class.java)

    private val prefs: SharedPreferences
        get() = context.getSharedPreferences("halo", Context.MODE_PRIVATE)

    private val appsCallback = object : LauncherApps.Callback() {
        override fun onPackageAdded(packageName: String, user: UserHandle) = emit("apps")
        override fun onPackageRemoved(packageName: String, user: UserHandle) = emit("apps")
        override fun onPackageChanged(packageName: String, user: UserHandle) = emit("apps")
        override fun onPackagesAvailable(names: Array<out String>, user: UserHandle, replacing: Boolean) = emit("apps")
        override fun onPackagesUnavailable(names: Array<out String>, user: UserHandle, replacing: Boolean) = emit("apps")
    }

    private val switchboard by lazy { SwitchboardController(context, main) { emit(it) } }

    private val usage by lazy { UsageController(context) }

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = emit("battery")
    }

    // A calendar sync (right after the grant, say) changes many rows at once;
    // tell Dart once the burst is over, not once per row.
    private val calendarChanged = Runnable { emit("calendar") }
    private val calendarObserver = object : ContentObserver(main) {
        override fun onChange(selfChange: Boolean) {
            main.removeCallbacks(calendarChanged)
            main.postDelayed(calendarChanged, 500)
        }
    }

    // A work profile paused or resumed, a private space locked or unlocked.
    private val profileReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = emit("apps")
    }

    // FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        launcherApps = context.getSystemService(LauncherApps::class.java)
        methods = MethodChannel(binding.binaryMessenger, "halo_android")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "halo_android/events")
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        worker.shutdown()
    }

    // ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding
        binding.addOnNewIntentListener(this)
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity?.removeOnNewIntentListener(this)
        activity?.removeActivityResultListener(this)
        activity?.removeRequestPermissionsResultListener(this)
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onNewIntent(intent: Intent): Boolean {
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_HOME)) {
            emit("home")
        }
        return false
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_DEFAULT_HOME) return false
        emit("defaultHome")
        return true
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        when (requestCode) {
            REQUEST_CONTACTS -> emit("contacts")
            REQUEST_CALENDAR -> {
                watchCalendar()
                emit("calendar")
            }
            else -> return false
        }
        return true
    }

    // EventChannel

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        launcherApps.registerCallback(appsCallback, main)
        context.registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        switchboard.register()
        val profiles = IntentFilter().apply {
            addAction(Intent.ACTION_MANAGED_PROFILE_AVAILABLE)
            addAction(Intent.ACTION_MANAGED_PROFILE_UNAVAILABLE)
            if (Build.VERSION.SDK_INT >= 31) {
                addAction(Intent.ACTION_PROFILE_AVAILABLE)
                addAction(Intent.ACTION_PROFILE_UNAVAILABLE)
            }
        }
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(profileReceiver, profiles, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(profileReceiver, profiles)
        }
        watchCalendar()
        HaloNotificationService.onChange = {
            main.post {
                emit("notifications")
                watchMedia()
            }
        }
        watchMedia()
    }

    override fun onCancel(arguments: Any?) {
        launcherApps.unregisterCallback(appsCallback)
        context.unregisterReceiver(batteryReceiver)
        switchboard.unregister()
        context.unregisterReceiver(profileReceiver)
        context.contentResolver.unregisterContentObserver(calendarObserver)
        main.removeCallbacks(calendarChanged)
        HaloNotificationService.onChange = null
        unwatchMedia()
        sink = null
    }

    // Registering for calendar changes needs READ_CALENDAR; without it the
    // rest of the stream must still work, and the grant result retries.
    private fun watchCalendar() {
        try {
            context.contentResolver.unregisterContentObserver(calendarObserver)
            context.contentResolver.registerContentObserver(CalendarContract.CONTENT_URI, true, calendarObserver)
        } catch (_: SecurityException) {
        }
    }

    private fun emit(type: String) {
        main.post { sink?.success(mapOf("type" to type)) }
    }

    // Methods

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "apps" -> result.success(apps())
            "defaultApps" -> result.success(roleApps().values.distinct())
            "roles" -> result.success(roleApps())
            "getPref" -> result.success(prefs.getString(call.argument<String>("key"), null))
            "setPref" -> {
                prefs.edit().putString(call.argument<String>("key"), call.argument<String>("value")).apply()
                result.success(null)
            }
            "shortcuts" -> result.success(shortcuts(call.argument<String>("id")))
            "startShortcut" -> result.success(
                startShortcut(call.argument<String>("id"), call.argument<String>("shortcut")),
            )
            "appInfo" -> {
                appInfo(call.argument<String>("id"))
                result.success(null)
            }
            "uninstall" -> {
                uninstall(call.argument<String>("id"))
                result.success(null)
            }
            "openSettings" -> {
                openSettings(call.argument<String>("id"))
                result.success(null)
            }
            "canSearchContacts" -> result.success(canSearchContacts())
            "requestContacts" -> {
                requestContacts()
                result.success(null)
            }
            "searchContacts" -> {
                val query = call.argument<String>("query").orEmpty()
                worker.execute {
                    val found = searchContacts(query)
                    main.post { result.success(found) }
                }
            }
            "openContact" -> {
                openContact(call.argument<String>("id"))
                result.success(null)
            }
            "openAssistant" -> result.success(openAssistant())
            "canReadCalendar" -> result.success(canReadCalendar())
            "requestCalendar" -> {
                requestCalendar()
                result.success(null)
            }
            "agenda" -> worker.execute {
                val events = agenda()
                main.post { result.success(events) }
            }
            "canReadNotifications" -> result.success(canReadNotifications())
            "requestNotificationAccess" -> {
                requestNotificationAccess()
                result.success(null)
            }
            "notifications" -> result.success(notifications())
            "openNotification" -> result.success(openNotification(call.argument<String>("id")))
            "dismissNotification" -> {
                notification(call.argument<String>("id"))?.let { HaloNotificationService.current?.cancelNotification(it.key) }
                result.success(null)
            }
            "snoozeNotification" -> {
                notification(call.argument<String>("id"))?.let {
                    HaloNotificationService.current?.snoozeNotification(it.key, SNOOZE_MS)
                }
                result.success(null)
            }
            "replyNotification" -> result.success(
                replyNotification(call.argument<String>("id"), call.argument<String>("text").orEmpty()),
            )
            "notificationAction" -> result.success(
                runNotificationAction(call.argument<String>("id"), call.argument<String>("action")),
            )
            "openMap" -> {
                openView(Uri.parse("geo:0,0?q=" + Uri.encode(call.argument<String>("place").orEmpty())))
                result.success(null)
            }
            "openEvent" -> {
                call.argument<String>("id")?.toLongOrNull()?.let {
                    openView(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, it))
                }
                result.success(null)
            }
            "canReadUsage" -> result.success(usage.canRead())
            "requestUsageAccess" -> {
                usage.request()
                result.success(null)
            }
            "recentApps" -> result.success(usage.recent())
            "quick" -> result.success(switchboard.read())
            "setBrightness" -> {
                switchboard.setBrightness(call.argument<Double>("value") ?: 0.5)
                result.success(null)
            }
            "setBrightnessAuto" -> {
                switchboard.setBrightnessAuto(call.argument<Boolean>("auto") ?: true)
                result.success(null)
            }
            "setVolume" -> {
                switchboard.setVolume(call.argument<Double>("value") ?: 0.5)
                result.success(null)
            }
            "setFocus" -> {
                switchboard.setFocus(call.argument<Boolean>("on") ?: false)
                result.success(null)
            }
            "openRadio" -> {
                switchboard.openRadio(call.argument<String>("id").orEmpty())
                result.success(null)
            }
            "requestWriteSettings" -> {
                switchboard.requestWriteSettings()
                result.success(null)
            }
            "requestPolicyAccess" -> {
                switchboard.requestPolicyAccess()
                result.success(null)
            }
            "openSystemSettings" -> {
                switchboard.openSection(call.argument<String>("section").orEmpty())
                result.success(null)
            }
            "skip" -> {
                skip(call.argument<Boolean>("next") ?: true)
                result.success(null)
            }
            "media" -> result.success(media())
            "setPlaying" -> {
                setPlaying(call.argument<Boolean>("playing") ?: false)
                result.success(null)
            }
            "privateSpace" -> result.success(privateSpaceState())
            "setPrivateSpaceLocked" -> {
                setPrivateSpaceLocked(call.argument<Boolean>("locked") ?: true)
                result.success(null)
            }
            "icons" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                val size = call.argument<Int>("size") ?: 144
                worker.execute {
                    val icons = icons(ids, size)
                    main.post { result.success(icons) }
                }
            }
            "launch" -> result.success(launch(call.argument<String>("id")))
            "battery" -> result.success(battery())
            "isDefaultHome" -> result.success(isDefaultHome())
            "requestDefaultHome" -> {
                requestDefaultHome()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun idOf(info: LauncherActivityInfo): String {
        val component = info.componentName.flattenToShortString()
        return if (info.user == me) component else "$component#${users.getSerialNumberForUser(info.user)}"
    }

    /** The component and profile an id names, or null if it is malformed. */
    private fun parse(id: String?): Pair<ComponentName, UserHandle>? {
        if (id == null) return null
        val parts = id.split('#', limit = 2)
        val component = ComponentName.unflattenFromString(parts[0]) ?: return null
        val user = if (parts.size == 1) me else users.getUserForSerialNumber(parts[1].toLongOrNull() ?: return null)
        return user?.let { component to it }
    }

    /** The private space profile (Android 15+), if there is one. */
    private fun privateProfile(): UserHandle? {
        if (Build.VERSION.SDK_INT < 35) return null
        return launcherApps.profiles.firstOrNull {
            launcherApps.getLauncherUserInfo(it)?.userType == UserManager.USER_TYPE_PROFILE_PRIVATE
        }
    }

    private fun privateSpaceState(): String {
        val profile = privateProfile() ?: return "none"
        return if (users.isQuietModeEnabled(profile)) "locked" else "unlocked"
    }

    /** The system asks for the private space's lock when unlocking. */
    private fun setPrivateSpaceLocked(locked: Boolean) {
        val profile = privateProfile() ?: return
        users.requestQuietModeEnabled(locked, profile)
    }

    /**
     * Launchable activities in every profile, minus Halo itself. A locked
     * private space shows nothing: its apps must not appear while locked.
     */
    private fun activities(): List<LauncherActivityInfo> {
        val hidden = privateProfile()?.takeIf(users::isQuietModeEnabled)
        return launcherApps.profiles
            .filter { it != hidden }
            .flatMap { launcherApps.getActivityList(null, it) }
            .filter { it.componentName.packageName != context.packageName }
    }

    /** Every launchable app, by label. */
    private fun apps(): List<Map<String, Any>> {
        val private = privateProfile()
        return activities()
            .map {
                val flags = it.applicationInfo.flags
                val system = flags and ApplicationInfo.FLAG_SYSTEM != 0 &&
                    flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP == 0
                mapOf(
                    "id" to idOf(it),
                    "label" to it.label.toString(),
                    "work" to (it.user != me && it.user != private),
                    "privateSpace" to (it.user == private),
                    "canUninstall" to !system,
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    /**
     * The user's default app for each role on the Home design's arc, role to
     * app id, in the design's order (Notes has no standard role): maps,
     * music, messages, camera, web, phone. They fill the arc the first time
     * and are drawn with the design's glyphs (D-025).
     */
    private fun roleApps(): Map<String, String> {
        val pm = context.packageManager
        fun resolved(intent: Intent): String? =
            pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName
                ?.takeIf { it != "android" } // the chooser: no default picked
        val packages = linkedMapOf(
            "maps" to resolved(Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q="))),
            "music" to resolved(Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_MUSIC)),
            "messages" to Telephony.Sms.getDefaultSmsPackage(context),
            "camera" to resolved(Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)),
            "web" to resolved(Intent(Intent.ACTION_VIEW, Uri.parse("https://"))),
            "phone" to resolved(Intent(Intent.ACTION_DIAL)),
        )
        val mine = launcherApps.getActivityList(null, me)
        val out = LinkedHashMap<String, String>()
        for ((role, pkg) in packages) {
            if (pkg == null) continue
            mine.firstOrNull { it.componentName.packageName == pkg }?.let { out[role] = idOf(it) }
        }
        return out
    }

    private fun shortcutQuery(component: ComponentName) = LauncherApps.ShortcutQuery()
        .setPackage(component.packageName)
        .setActivity(component)
        .setQueryFlags(
            LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or
                LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST or
                LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED,
        )

    /** Shortcuts need the host permission, which only the default home app has. */
    private fun shortcuts(id: String?): List<Map<String, String>> {
        val (component, user) = parse(id) ?: return emptyList()
        if (!launcherApps.hasShortcutHostPermission()) return emptyList()
        return try {
            launcherApps.getShortcuts(shortcutQuery(component), user).orEmpty()
                .filter(ShortcutInfo::isEnabled)
                .sortedBy(ShortcutInfo::getRank)
                .map { mapOf("id" to it.id, "label" to (it.shortLabel ?: it.longLabel ?: it.id).toString()) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun startShortcut(id: String?, shortcut: String?): Boolean {
        val (component, user) = parse(id) ?: return false
        if (shortcut == null) return false
        return try {
            launcherApps.startShortcut(component.packageName, shortcut, null, null, user)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun appInfo(id: String?) {
        val (component, user) = parse(id) ?: return
        launcherApps.startAppDetailsActivity(component, user, null, null)
    }

    private fun uninstall(id: String?) {
        val (component, _) = parse(id) ?: return
        val host: Activity = activity?.activity ?: return
        host.startActivity(Intent(Intent.ACTION_DELETE, Uri.fromParts("package", component.packageName, null)))
    }

    private fun openSettings(id: String?) {
        val action = when (id) {
            "wifi" -> Settings.ACTION_WIFI_SETTINGS
            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
            "network" -> Settings.ACTION_WIRELESS_SETTINGS
            "airplane" -> Settings.ACTION_AIRPLANE_MODE_SETTINGS
            "display" -> Settings.ACTION_DISPLAY_SETTINGS
            "sound" -> Settings.ACTION_SOUND_SETTINGS
            "notifications" -> "android.settings.NOTIFICATION_SETTINGS"
            "battery" -> Intent.ACTION_POWER_USAGE_SUMMARY
            "apps" -> Settings.ACTION_APPLICATION_SETTINGS
            "location" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
            "security" -> Settings.ACTION_SECURITY_SETTINGS
            "privacy" -> Settings.ACTION_PRIVACY_SETTINGS
            "storage" -> Settings.ACTION_INTERNAL_STORAGE_SETTINGS
            "accessibility" -> Settings.ACTION_ACCESSIBILITY_SETTINGS
            "datetime" -> Settings.ACTION_DATE_SETTINGS
            "language" -> Settings.ACTION_LOCALE_SETTINGS
            "home" -> Settings.ACTION_HOME_SETTINGS
            "about" -> Settings.ACTION_DEVICE_INFO_SETTINGS
            else -> Settings.ACTION_SETTINGS
        }
        // Not every phone has every page; fall back to Settings itself.
        for (a in listOf(action, Settings.ACTION_SETTINGS)) {
            try {
                context.startActivity(Intent(a).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (e: ActivityNotFoundException) {
                continue
            }
        }
    }

    /**
     * The assistant the user picked in Android (Settings > Apps > Default
     * apps > Digital assistant), or the voice command app. Halo has none of
     * its own (D-012).
     */
    private fun openAssistant(): Boolean {
        for (action in listOf(Intent.ACTION_ASSIST, Intent.ACTION_VOICE_COMMAND)) {
            try {
                context.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                continue
            }
        }
        return false
    }

    // Calendar

    private fun canReadCalendar(): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private fun requestCalendar() {
        val host: Activity = activity?.activity ?: return
        val askedBefore = prefs.getBoolean("askedCalendar", false)
        if (askedBefore && !host.shouldShowRequestPermissionRationale(Manifest.permission.READ_CALENDAR)) {
            host.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)),
            )
            return
        }
        prefs.edit().putBoolean("askedCalendar", true).apply()
        host.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), REQUEST_CALENDAR)
    }

    /**
     * Today's events from visible calendars, all-day ones first, then in time
     * order: id, start (epoch ms; local midnight for all-day), title,
     * location, all-day, and attendee count when there are guests.
     */
    private fun agenda(): List<Map<String, Any?>> {
        if (!canReadCalendar()) return emptyList()
        val day = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val start = day.timeInMillis
        val dayMs = 24 * 60 * 60 * 1000L
        val end = start + dayMs
        // All-day instances sit at UTC midnight, which can fall on either side
        // of the local day, so ask a day wider and match them by date.
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, start - dayMs)
            ContentUris.appendId(it, end + dayMs)
        }.build()
        val utc = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC"))
        fun isToday(utcMidnight: Long): Boolean {
            utc.timeInMillis = utcMidnight
            return utc.get(java.util.Calendar.YEAR) == day.get(java.util.Calendar.YEAR) &&
                utc.get(java.util.Calendar.DAY_OF_YEAR) == day.get(java.util.Calendar.DAY_OF_YEAR)
        }
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.ALL_DAY,
        )
        return try {
            context.contentResolver.query(
                uri,
                projection,
                "${CalendarContract.Instances.VISIBLE} = 1",
                null,
                "${CalendarContract.Instances.BEGIN} ASC",
            )?.use { c ->
                buildList {
                    while (c.moveToNext()) {
                        val allDay = c.getInt(4) == 1
                        val begin = c.getLong(2)
                        if (allDay && !isToday(begin)) continue
                        if (!allDay && (begin < start || begin >= end)) continue
                        add(
                            mapOf(
                                "id" to c.getLong(0).toString(),
                                "start" to if (allDay) start else begin,
                                "title" to (c.getString(1) ?: ""),
                                "location" to (c.getString(3) ?: ""),
                                "allDay" to allDay,
                                "attendees" to attendees(c.getLong(0)),
                            ),
                        )
                    }
                }.sortedWith(compareBy({ it["allDay"] != true }, { it["start"] as Long }))
            }.orEmpty()
        } catch (e: SecurityException) {
            emptyList()
        }
    }

    /** Guests on an event, or null when it has none. */
    private fun attendees(eventId: Long): Int? =
        context.contentResolver.query(
            CalendarContract.Attendees.CONTENT_URI,
            arrayOf(CalendarContract.Attendees._ID),
            "${CalendarContract.Attendees.EVENT_ID} = ?",
            arrayOf(eventId.toString()),
            null,
        )?.use { it.count.takeIf { n -> n > 1 } }

    // Notifications

    private val listener: ComponentName get() = ComponentName(context, HaloNotificationService::class.java)

    private fun canReadNotifications(): Boolean =
        context.getSystemService(NotificationManager::class.java).isNotificationListenerAccessGranted(listener)

    private fun requestNotificationAccess() {
        val intent = if (Build.VERSION.SDK_INT >= 30) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, listener.flattenToString())
        } else {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        }
        try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: ActivityNotFoundException) {
            context.startActivity(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun notification(key: String?) =
        HaloNotificationService.current?.activeNotifications?.firstOrNull { it.key == key }

    private fun replyAction(n: Notification): Notification.Action? =
        n.actions?.firstOrNull { a -> a.remoteInputs?.any { it.allowFreeFormInput } == true }

    /**
     * What Stream shows: the phone's notifications, newest first, minus Halo's
     * own, ongoing ones (music, calls in progress, downloads) and group
     * summaries that only stand for their children.
     */
    private fun notifications(): List<Map<String, Any?>> {
        val service = HaloNotificationService.current ?: return emptyList()
        val starredByUri = HashMap<String, Boolean>()
        val labels = HashMap<String, String>()
        fun label(pkg: String) = labels.getOrPut(pkg) {
            try {
                context.packageManager.getApplicationLabel(context.packageManager.getApplicationInfo(pkg, 0)).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                pkg
            }
        }
        val active = try {
            service.activeNotifications.orEmpty()
        } catch (e: SecurityException) {
            return emptyList()
        }
        return active
            .filter { it.packageName != context.packageName && !it.isOngoing }
            .filter { it.notification.flags and Notification.FLAG_GROUP_SUMMARY == 0 }
            .mapNotNull { sbn ->
                val n = sbn.notification
                val extras = n.extras
                val title = (
                    extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
                        ?: extras.getCharSequence(Notification.EXTRA_TITLE)
                    )?.toString()?.trim().orEmpty()
                val text = (
                    extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                        ?: extras.getCharSequence(Notification.EXTRA_TEXT)
                    )?.toString()?.trim().orEmpty()
                if (title.isEmpty() && text.isEmpty()) return@mapNotNull null
                val people = peopleOf(n)
                val category = n.category
                val fromPerson = people.isNotEmpty() ||
                    category == Notification.CATEGORY_MESSAGE ||
                    category == Notification.CATEGORY_CALL ||
                    category == MISSED_CALL ||
                    extras.getString(Notification.EXTRA_TEMPLATE) == MESSAGING_STYLE
                mapOf(
                    "id" to sbn.key,
                    "package" to sbn.packageName,
                    "app" to label(sbn.packageName),
                    "title" to title,
                    "text" to text,
                    "postTime" to sbn.postTime,
                    "canReply" to (replyAction(n) != null),
                    "canDismiss" to sbn.isClearable,
                    // For the priority rules (D-030): what it is, whether a
                    // person is behind it, and whether they are starred.
                    "missedCall" to (category == MISSED_CALL),
                    "fromPerson" to fromPerson,
                    "starred" to people.any { it.isImportant || isStarred(it.uri, starredByUri) },
                    // The app's other actions, by their place in the list.
                    "actions" to n.actions.orEmpty().withIndex()
                        .filter { (_, a) -> a.remoteInputs.isNullOrEmpty() && !a.title.isNullOrBlank() }
                        .map { (i, a) -> mapOf("id" to i.toString(), "label" to a.title.toString()) },
                )
            }
            .sortedByDescending { it["postTime"] as Long }
    }

    /** The people a notification names (chats, calls), if its app says so. */
    @Suppress("DEPRECATION")
    private fun peopleOf(n: Notification): List<android.app.Person> =
        n.extras.getParcelableArrayList<android.app.Person>(Notification.EXTRA_PEOPLE_LIST).orEmpty()

    /** Whether [uri] (a contact or a phone number) is a starred contact. Needs contacts access. */
    private fun isStarred(uri: String?, cache: MutableMap<String, Boolean>): Boolean {
        if (uri == null || !canSearchContacts()) return false
        return cache.getOrPut(uri) {
            try {
                val u = Uri.parse(uri)
                val target = when (u.scheme) {
                    "tel" -> Uri.withAppendedPath(
                        ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                        Uri.encode(u.schemeSpecificPart),
                    )
                    "content" -> u
                    else -> return@getOrPut false
                }
                context.contentResolver
                    .query(target, arrayOf(ContactsContract.Contacts.STARRED), null, null, null)
                    ?.use { it.moveToFirst() && it.getInt(0) == 1 } ?: false
            } catch (e: Exception) {
                false
            }
        }
    }

    /** Sends the notification's tap action and clears it if it should go. */
    private fun openNotification(key: String?): Boolean {
        val sbn = notification(key) ?: return false
        val intent = sbn.notification.contentIntent ?: return false
        return try {
            sendAllowingActivityStart(intent, null)
            if (sbn.notification.flags and Notification.FLAG_AUTO_CANCEL != 0) {
                HaloNotificationService.current?.cancelNotification(sbn.key)
            }
            true
        } catch (e: PendingIntent.CanceledException) {
            false
        }
    }

    /** Sends one of the notification's own actions (by its place). */
    private fun runNotificationAction(key: String?, index: String?): Boolean {
        val sbn = notification(key) ?: return false
        val action = index?.toIntOrNull()?.let { sbn.notification.actions?.getOrNull(it) } ?: return false
        return try {
            sendAllowingActivityStart(action.actionIntent, null)
            true
        } catch (e: PendingIntent.CanceledException) {
            false
        }
    }

    private fun openView(uri: Uri) {
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: ActivityNotFoundException) {
            // No app for it.
        }
    }

    /** Fills the reply action's free-form input with [text] and sends it. */
    private fun replyNotification(key: String?, text: String): Boolean {
        if (text.isBlank()) return false
        val sbn = notification(key) ?: return false
        val action = replyAction(sbn.notification) ?: return false
        val inputs = action.remoteInputs ?: return false
        val results = Bundle().apply { inputs.forEach { putCharSequence(it.resultKey, text) } }
        val fill = Intent()
        RemoteInput.addResultsToIntent(inputs, fill, results)
        RemoteInput.setResultsSource(fill, RemoteInput.SOURCE_FREE_FORM_INPUT)
        return try {
            sendAllowingActivityStart(action.actionIntent, fill)
            true
        } catch (e: PendingIntent.CanceledException) {
            false
        }
    }

    /**
     * Halo is in front when the user taps, so it lends its right to start an
     * activity to the app's PendingIntent (required from Android 14).
     */
    private fun sendAllowingActivityStart(intent: PendingIntent, fill: Intent?) {
        val options = if (Build.VERSION.SDK_INT >= 34) {
            ActivityOptions.makeBasic()
                .setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                .toBundle()
        } else {
            null
        }
        intent.send(context, 0, fill, null, null, null, options)
    }

    // Media sessions (they need notification access)

    private val sessions: MediaSessionManager get() = context.getSystemService(MediaSessionManager::class.java)
    private val watched = mutableListOf<MediaController>()

    private val mediaCallback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) = emit("media")
        override fun onMetadataChanged(metadata: MediaMetadata?) = emit("media")
        override fun onSessionDestroyed() = emit("media")
    }

    private val sessionsListener = MediaSessionManager.OnActiveSessionsChangedListener {
        rewatch(it.orEmpty())
        emit("media")
    }

    private fun watchMedia() {
        unwatchMedia()
        if (!canReadNotifications()) return
        try {
            sessions.addOnActiveSessionsChangedListener(sessionsListener, listener, main)
            rewatch(sessions.getActiveSessions(listener))
        } catch (e: SecurityException) {
            // Access was just revoked.
        }
    }

    private fun unwatchMedia() {
        try {
            sessions.removeOnActiveSessionsChangedListener(sessionsListener)
        } catch (e: Exception) {
            // Never added.
        }
        watched.forEach { it.unregisterCallback(mediaCallback) }
        watched.clear()
    }

    private fun rewatch(controllers: List<MediaController>) {
        watched.forEach { it.unregisterCallback(mediaCallback) }
        watched.clear()
        controllers.forEach {
            it.registerCallback(mediaCallback, main)
            watched.add(it)
        }
    }

    /** The playing session, else the first one with something loaded. */
    private fun currentController(): MediaController? {
        val list = try {
            if (!canReadNotifications()) return null
            sessions.getActiveSessions(listener)
        } catch (e: SecurityException) {
            return null
        }
        return list.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
            ?: list.firstOrNull { it.metadata != null }
    }

    private fun media(): Map<String, Any?>? {
        val c = currentController() ?: return null
        val meta = c.metadata ?: return null
        val state = c.playbackState
        val duration = meta.getLong(MediaMetadata.METADATA_KEY_DURATION)
        // Where it is now: the last reported position plus what has played since.
        val position = state?.let {
            if (it.state == PlaybackState.STATE_PLAYING) {
                it.position + ((SystemClock.elapsedRealtime() - it.lastPositionUpdateTime) * it.playbackSpeed).toLong()
            } else {
                it.position
            }
        } ?: 0L
        return mapOf(
            "title" to (meta.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""),
            "artist" to (
                meta.getString(MediaMetadata.METADATA_KEY_ARTIST)
                    ?: meta.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST) ?: ""
                ),
            "progress" to if (duration > 0) (position.toDouble() / duration).coerceIn(0.0, 1.0) else 0.0,
            "playing" to (state?.state == PlaybackState.STATE_PLAYING),
        )
    }

    private fun skip(next: Boolean) {
        val controls = currentController()?.transportControls ?: return
        if (next) controls.skipToNext() else controls.skipToPrevious()
    }

    private fun setPlaying(playing: Boolean) {
        val controls = currentController()?.transportControls ?: return
        if (playing) controls.play() else controls.pause()
    }

    private fun canSearchContacts(): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

    /**
     * Asks for the contacts permission. Once the user has said no for good,
     * Android shows no dialog any more, so open Halo's App info instead.
     */
    private fun requestContacts() {
        val host: Activity = activity?.activity ?: return
        val askedBefore = prefs.getBoolean("askedContacts", false)
        if (askedBefore && !host.shouldShowRequestPermissionRationale(Manifest.permission.READ_CONTACTS)) {
            host.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)),
            )
            return
        }
        prefs.edit().putBoolean("askedContacts", true).apply()
        host.requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), REQUEST_CONTACTS)
    }

    /** At most five contacts whose name matches, as the system's filter ranks them. */
    private fun searchContacts(query: String): List<Map<String, String>> {
        if (query.isBlank() || !canSearchContacts()) return emptyList()
        val uri = Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_FILTER_URI, Uri.encode(query.trim()))
        val projection = arrayOf(
            ContactsContract.Contacts._ID,
            ContactsContract.Contacts.LOOKUP_KEY,
            ContactsContract.Contacts.DISPLAY_NAME_PRIMARY,
        )
        val args = Bundle().apply { putInt(ContentResolver.QUERY_ARG_LIMIT, 5) }
        return try {
            context.contentResolver.query(uri, projection, args, null)?.use { c ->
                buildList {
                    while (c.moveToNext()) {
                        val name = c.getString(2) ?: continue
                        add(mapOf("id" to "${c.getString(1)}/${c.getLong(0)}", "name" to name))
                    }
                }
            }.orEmpty()
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun openContact(id: String?) {
        val (lookup, rowId) = id?.split('/', limit = 2)?.takeIf { it.size == 2 } ?: return
        val uri = ContactsContract.Contacts.getLookupUri(rowId.toLongOrNull() ?: return, lookup) ?: return
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: ActivityNotFoundException) {
            // No contacts app.
        }
    }

    /**
     * Each app's icon, and a monochrome mask as `mono`: the icon's own
     * monochrome layer (Android 13+) when it has one, else one derived from
     * the icon ([derivedMono]). The arc draws every app from it (D-025).
     */
    private fun icons(ids: List<String>, size: Int): Map<String, Map<String, Any>> {
        val byId = activities().associateBy(::idOf)
        val out = HashMap<String, Map<String, Any>>()
        for (id in ids) {
            val info = byId[id] ?: continue
            val drawable = try {
                info.getIcon(0)
            } catch (e: Exception) {
                null
            } ?: continue
            val layer = if (Build.VERSION.SDK_INT >= 33 && drawable is AdaptiveIconDrawable) {
                drawable.monochrome
            } else {
                null
            }
            val mono = try {
                if (layer != null) layerPng(layer, size) else derivedMono(drawable, size)
            } catch (e: Exception) {
                null
            }
            val iconPng = png(drawable, size)
            out[id] = buildMap {
                put("icon", iconPng)
                accentOf(iconPng)?.let { put("accent", it) }
                if (mono != null) put("mono", mono)
            }
        }
        return out
    }

    /**
     * The icon's main color as ARGB: the average of its saturated, opaque
     * pixels, else of all opaque ones. Null for an empty icon. Recents tints
     * a slat with it.
     */
    private fun accentOf(png: ByteArray): Int? {
        val bitmap = BitmapFactory.decodeByteArray(png, 0, png.size) ?: return null
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        val hsv = FloatArray(3)
        var r = 0L; var g = 0L; var b = 0L; var n = 0
        var ar = 0L; var ag = 0L; var ab = 0L; var an = 0
        for (p in pixels) {
            if (Color.alpha(p) < 200) continue
            ar += Color.red(p); ag += Color.green(p); ab += Color.blue(p); an++
            Color.colorToHSV(p, hsv)
            if (hsv[1] > 0.35f && hsv[2] > 0.25f) {
                r += Color.red(p); g += Color.green(p); b += Color.blue(p); n++
            }
        }
        return when {
            n > 0 -> Color.rgb((r / n).toInt(), (g / n).toInt(), (b / n).toInt())
            an > 0 -> Color.rgb((ar / an).toInt(), (ag / an).toInt(), (ab / an).toInt())
            else -> null
        }
    }

    /** A monochrome layer, full bleed and cropped like [png], as a clean mask. */
    private fun layerPng(layer: Drawable, size: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val bleed = size * 18 / 72
        layer.setBounds(-bleed, -bleed, size + bleed, size + bleed)
        layer.draw(Canvas(bitmap))
        return compress(cleanMask(bitmap))
    }

    /**
     * White with the mask's alpha, near-invisible pixels dropped: the arc
     * tints wherever the mask has any alpha, so a faint speck would show.
     */
    private fun cleanMask(bitmap: Bitmap): Bitmap {
        val w = bitmap.width
        val h = bitmap.height
        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)
        for (i in pixels.indices) {
            val a = pixels[i] ushr 24
            pixels[i] = if (a < MASK_FLOOR) 0 else (a shl 24) or 0xFFFFFF
        }
        bitmap.setPixels(pixels, 0, w, 0, 0, w, h)
        return bitmap
    }

    /**
     * A monochrome mask for an icon that has no monochrome layer: the pixels
     * that stand out from the icon's own background. For an adaptive icon
     * that is where the full icon differs from its background layer, so a
     * white logo on a colored plate keeps its shape and a white plate drops
     * away. A legacy icon is compared with its edge color, or used by its
     * alpha when the edge is transparent. The mask is shrunk to the size of
     * a monochrome layer's content (about two thirds), like [layerPng].
     */
    private fun derivedMono(drawable: Drawable, size: Int): ByteArray {
        val full = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(full)
        var reference: IntArray? = null
        var edge = 0
        if (drawable is AdaptiveIconDrawable) {
            val bleed = size * 18 / 72
            val back = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            drawable.background?.let {
                it.setBounds(-bleed, -bleed, size + bleed, size + bleed)
                it.draw(Canvas(back))
                it.draw(canvas)
            }
            drawable.foreground?.let {
                it.setBounds(-bleed, -bleed, size + bleed, size + bleed)
                it.draw(canvas)
            }
            reference = IntArray(size * size).also { back.getPixels(it, 0, size, 0, 0, size, size) }
            back.recycle()
        } else {
            val inset = size * 15 / 100
            drawable.setBounds(inset, inset, size - inset, size - inset)
            drawable.draw(canvas)
            edge = full.getPixel(inset + size / 25, size / 2)
        }
        val pixels = IntArray(size * size)
        full.getPixels(pixels, 0, size, 0, 0, size, size)
        full.recycle()
        for (i in pixels.indices) {
            val p = pixels[i]
            val a = p ushr 24
            if (a == 0) continue
            val against = reference?.get(i) ?: edge
            val stand = if (reference == null && against ushr 24 < 128) 1f else distance(p, against) * 3f
            val alpha = (a * stand.coerceIn(0f, 1f)).toInt()
            pixels[i] = (alpha shl 24) or 0xFFFFFF
        }
        val mask = Bitmap.createBitmap(pixels, size, size, Bitmap.Config.ARGB_8888)
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val shrink = size / 6
        Canvas(out).drawBitmap(
            mask,
            null,
            Rect(shrink, shrink, size - shrink, size - shrink),
            Paint(Paint.FILTER_BITMAP_FLAG),
        )
        mask.recycle()
        return compress(cleanMask(out))
    }

    /** RGB distance from 0 (same) to 1 (black against white). */
    private fun distance(a: Int, b: Int): Float {
        val dr = ((a shr 16) and 0xFF) - ((b shr 16) and 0xFF)
        val dg = ((a shr 8) and 0xFF) - ((b shr 8) and 0xFF)
        val db = (a and 0xFF) - (b and 0xFF)
        return kotlin.math.sqrt((dr * dr + dg * dg + db * db).toFloat()) / 441.7f
    }

    private fun compress(bitmap: Bitmap): ByteArray {
        val bytes = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes)
        bitmap.recycle()
        return bytes.toByteArray()
    }

    /**
     * Renders an icon full bleed into a square. Flutter masks it to a circle
     * (docs/DECISIONS.md D-025), so an adaptive icon gets its layers drawn
     * without the system mask, cropped to the 72 of 108 dp that the system
     * shows; a legacy icon is inset to stay inside the circle.
     */
    private fun png(drawable: Drawable, size: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        if (drawable is AdaptiveIconDrawable) {
            val bleed = size * 18 / 72
            for (layer in listOfNotNull(drawable.background, drawable.foreground)) {
                layer.setBounds(-bleed, -bleed, size + bleed, size + bleed)
                layer.draw(canvas)
            }
        } else {
            val inset = size * 15 / 100
            drawable.setBounds(inset, inset, size - inset, size - inset)
            drawable.draw(canvas)
        }
        return compress(bitmap)
    }

    private fun launch(id: String?): Boolean {
        val (component, user) = parse(id) ?: return false
        return try {
            launcherApps.startMainActivity(component, user, null, null)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun battery(): Map<String, Any> {
        val manager = context.getSystemService(BatteryManager::class.java)
        return mapOf(
            "level" to manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) / 100.0,
            "charging" to manager.isCharging,
            // Milliseconds until full while charging, else -1.
            "fullInMs" to manager.computeChargeTimeRemaining(),
        )
    }

    private fun isDefaultHome(): Boolean =
        context.getSystemService(RoleManager::class.java).isRoleHeld(RoleManager.ROLE_HOME)

    private fun requestDefaultHome() {
        val host: Activity = activity?.activity ?: return
        val roles = host.getSystemService(RoleManager::class.java)
        if (roles.isRoleAvailable(RoleManager.ROLE_HOME) && !roles.isRoleHeld(RoleManager.ROLE_HOME)) {
            host.startActivityForResult(roles.createRequestRoleIntent(RoleManager.ROLE_HOME), REQUEST_DEFAULT_HOME)
        } else {
            host.startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
        }
    }

    private companion object {
        const val REQUEST_DEFAULT_HOME = 0x4a10
        const val REQUEST_CONTACTS = 0x4a11
        const val REQUEST_CALENDAR = 0x4a12

        // Not public API constants: the category dialer apps set on a missed
        // call, and the template of a chat notification.
        const val MISSED_CALL = "missed_call"
        const val MESSAGING_STYLE = "android.app.Notification\$MessagingStyle"

        /** Stream's LATER puts a notification away for an hour. */
        const val SNOOZE_MS = 60 * 60 * 1000L

        /** Mask alpha below this is dropped (see [cleanMask]). */
        const val MASK_FLOOR = 40
    }
}
