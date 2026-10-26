package com.baklavapp.halolauncher.platform

import android.app.Activity
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
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.UserHandle
import android.os.UserManager
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
 * `apps` (installed apps changed), `home` (Home pressed), `battery`,
 * `defaultHome` (the default home app may have changed).
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
    PluginRegistry.ActivityResultListener {

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
    }

    override fun onDetachedFromActivity() {
        activity?.removeOnNewIntentListener(this)
        activity?.removeActivityResultListener(this)
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

    // EventChannel

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        launcherApps.registerCallback(appsCallback, main)
        context.registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    }

    override fun onCancel(arguments: Any?) {
        launcherApps.unregisterCallback(appsCallback)
        context.unregisterReceiver(batteryReceiver)
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

    /** Launchable activities in every profile, minus Halo itself. */
    private fun activities(): List<LauncherActivityInfo> =
        launcherApps.profiles.flatMap { launcherApps.getActivityList(null, it) }
            .filter { it.componentName.packageName != context.packageName }

    /** Every launchable app, by label. */
    private fun apps(): List<Map<String, Any>> =
        activities()
            .map {
                val flags = it.applicationInfo.flags
                val system = flags and ApplicationInfo.FLAG_SYSTEM != 0 &&
                    flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP == 0
                mapOf(
                    "id" to idOf(it),
                    "label" to it.label.toString(),
                    "work" to (it.user != me),
                    "canUninstall" to !system,
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }

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

    private fun icons(ids: List<String>, size: Int): Map<String, ByteArray> {
        val byId = activities().associateBy(::idOf)
        val out = HashMap<String, ByteArray>()
        for (id in ids) {
            val info = byId[id] ?: continue
            val drawable = try {
                info.getIcon(0)
            } catch (e: Exception) {
                null
            } ?: continue
            out[id] = png(drawable, size)
        }
        return out
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
        val bytes = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes)
        bitmap.recycle()
        return bytes.toByteArray()
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
    }
}
