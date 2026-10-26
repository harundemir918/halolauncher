package com.baklavapp.halolauncher.platform

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.graphics.Bitmap
import android.graphics.Canvas
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
 * `contacts` (the contacts permission was answered).
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

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = emit("battery")
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
        if (requestCode != REQUEST_CONTACTS) return false
        emit("contacts")
        return true
    }

    // EventChannel

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        launcherApps.registerCallback(appsCallback, main)
        context.registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
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
    }

    override fun onCancel(arguments: Any?) {
        launcherApps.unregisterCallback(appsCallback)
        context.unregisterReceiver(batteryReceiver)
        context.unregisterReceiver(profileReceiver)
        sink = null
    }

    private fun emit(type: String) {
        main.post { sink?.success(mapOf("type" to type)) }
    }

    // Methods

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "apps" -> result.success(apps())
            "defaultApps" -> result.success(defaultApps())
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
     * The user's default apps for the roles on the Home design's arc, in its
     * order (Notes has no standard role): maps, music, messages, camera,
     * browser, phone. Used to fill the arc the first time.
     */
    private fun defaultApps(): List<String> {
        val pm = context.packageManager
        fun resolved(intent: Intent): String? =
            pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName
                ?.takeIf { it != "android" } // the chooser: no default picked
        val packages = listOf(
            resolved(Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q="))),
            resolved(Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_MUSIC)),
            Telephony.Sms.getDefaultSmsPackage(context),
            resolved(Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)),
            resolved(Intent(Intent.ACTION_VIEW, Uri.parse("https://"))),
            resolved(Intent(Intent.ACTION_DIAL)),
        )
        val mine = launcherApps.getActivityList(null, me)
        return packages.filterNotNull().distinct().mapNotNull { pkg ->
            mine.firstOrNull { it.componentName.packageName == pkg }?.let(::idOf)
        }
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

    /** Each app's icon, and its monochrome layer as `mono` when it has one. */
    private fun icons(ids: List<String>, size: Int): Map<String, Map<String, ByteArray>> {
        val byId = activities().associateBy(::idOf)
        val out = HashMap<String, Map<String, ByteArray>>()
        for (id in ids) {
            val info = byId[id] ?: continue
            val drawable = try {
                info.getIcon(0)
            } catch (e: Exception) {
                null
            } ?: continue
            val mono = if (Build.VERSION.SDK_INT >= 33 && drawable is AdaptiveIconDrawable) {
                drawable.monochrome?.let { layerPng(it, size) }
            } else {
                null
            }
            out[id] = buildMap {
                put("icon", png(drawable, size))
                if (mono != null) put("mono", mono)
            }
        }
        return out
    }

    /** One adaptive icon layer, full bleed and cropped like [png]. */
    private fun layerPng(layer: Drawable, size: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val bleed = size * 18 / 72
        layer.setBounds(-bleed, -bleed, size + bleed, size + bleed)
        layer.draw(Canvas(bitmap))
        return compress(bitmap)
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
    }
}
