package `in`.doctorfresh.doctor_fresh

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The native side of lib/core/native.dart — the few things only the phone can
 * do, written with the Android SDK alone (no plugin packages):
 *
 *   openUrl  { url }          → browser, dialer (tel:), mail (mailto:), WhatsApp
 *   share    { text }         → the share sheet
 *   openFile { path, mime }   → a PDF in the phone's viewer (via DfFileProvider)
 *   pickFile                  → a document picker; the file is copied to the cache
 *   location                  → asks for location permission, then the phone's
 *                               position { lat, lon } or { error: denied | off | unavailable }
 *   openInApp                 → false: links open in the browser on Android
 *   requestNotifications      → asks to post notifications (Android 13+)
 *   schedule / cancel         → local reminders (Reminders.kt)
 *   takeLaunchRoute           → the screen a tapped reminder asked for, once
 */
class MainActivity : FlutterActivity() {
    private val channelName = "in.doctorfresh.app/native"
    private val pickRequest = 4242
    private var pendingPick: MethodChannel.Result? = null
    private val locationRequest = 4343
    private var pendingLocation: MethodChannel.Result? = null
    private val notifyRequest = 4444
    private var pendingNotify: MethodChannel.Result? = null
    private var channel: MethodChannel? = null
    private var launchRoute: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        launchRoute = intent?.getStringExtra(Reminders.EXTRA_ROUTE)?.takeIf { it.isNotEmpty() }
    }

    /** A reminder tapped while the app is open. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val route = intent.getStringExtra(Reminders.EXTRA_ROUTE)?.takeIf { it.isNotEmpty() } ?: return
        channel?.invokeMethod("openRoute", route) ?: run { launchRoute = route }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        this.channel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> result.success(openUrl(call.argument<String>("url") ?: ""))
                "share" -> result.success(share(call.argument<String>("text") ?: ""))
                "openFile" -> result.success(openFile(call.argument<String>("path") ?: "", call.argument<String>("mime") ?: "application/pdf"))
                "pickFile" -> pickFile(result)
                "location" -> location(result)
                "openInApp" -> result.success(false)
                "requestNotifications" -> requestNotifications(result)
                "schedule" -> {
                    Reminders.schedule(
                        this,
                        call.argument<Int>("id") ?: 0,
                        call.argument<Number>("at")?.toLong() ?: 0L,
                        call.argument<String>("title") ?: "Doctor Fresh",
                        call.argument<String>("body") ?: "",
                        call.argument<String>("route") ?: "",
                    )
                    result.success(true)
                }
                "cancel" -> {
                    Reminders.cancel(this, call.argument<Int>("id") ?: 0)
                    result.success(null)
                }
                "takeLaunchRoute" -> {
                    result.success(launchRoute ?: "")
                    launchRoute = null
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openUrl(url: String): Boolean {
        if (url.isEmpty()) return false
        val uri = Uri.parse(url)
        val action = if (uri.scheme == "tel") Intent.ACTION_DIAL else Intent.ACTION_VIEW
        return try {
            startActivity(Intent(action, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun share(text: String): Boolean {
        return try {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            startActivity(Intent.createChooser(send, null))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openFile(path: String, mime: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false
        // Only files in the app's cache folder are served by DfFileProvider.
        val cached = File(cacheDir, file.name)
        if (cached.absolutePath != file.absolutePath) file.copyTo(cached, overwrite = true)
        val uri = Uri.parse("content://${DfFileProvider.authority(this)}/${Uri.encode(cached.name)}")
        return try {
            val view = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(view, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun pickFile(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "A file is already being picked", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/pdf",
                    "application/msword",
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                    "image/jpeg",
                    "image/png",
                    "image/webp",
                ),
            )
        }
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, pickRequest)
        } catch (e: Exception) {
            pendingPick = null
            result.success(null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            var name = "file"
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (i >= 0 && c.moveToFirst()) name = c.getString(i) ?: name
            }
            val mime = contentResolver.getType(uri) ?: "application/octet-stream"
            val out = File(cacheDir, "pick_${System.currentTimeMillis()}_$name")
            contentResolver.openInputStream(uri)?.use { input -> out.outputStream().use { input.copyTo(it) } }
            result.success(mapOf("path" to out.absolutePath, "name" to name, "mime" to mime))
        } catch (e: Exception) {
            result.success(null)
        }
    }

    /* -------------------------------------------------------------- location */

    private fun hasLocationPermission() =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun location(result: MethodChannel.Result) {
        if (pendingLocation != null) {
            result.success(mapOf("error" to "busy"))
            return
        }
        pendingLocation = result
        if (hasLocationPermission()) {
            readLocation()
        } else {
            requestPermissions(
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                locationRequest,
            )
        }
    }

    /* --------------------------------------------------------- notifications */

    private fun requestNotifications(result: MethodChannel.Result) {
        if (android.os.Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingNotify?.success(false)
        pendingNotify = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notifyRequest)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notifyRequest) {
            pendingNotify?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            pendingNotify = null
            return
        }
        if (requestCode != locationRequest) return
        if (hasLocationPermission()) readLocation() else finishLocation(mapOf("error" to "denied"))
    }

    private fun finishLocation(value: Map<String, Any>) {
        val result = pendingLocation ?: return
        pendingLocation = null
        result.success(value)
    }

    private fun Location.asMap() = mapOf("lat" to latitude, "lon" to longitude)

    /** A recent fix answers at once; otherwise one fresh reading, given ten seconds. */
    @Suppress("MissingPermission", "DEPRECATION")
    private fun readLocation() {
        val manager = getSystemService(LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
            .filter { runCatching { manager.isProviderEnabled(it) }.getOrDefault(false) }
        if (providers.isEmpty()) {
            finishLocation(mapOf("error" to "off"))
            return
        }

        val recent = providers
            .mapNotNull { runCatching { manager.getLastKnownLocation(it) }.getOrNull() }
            .maxByOrNull { it.time }
        if (recent != null && System.currentTimeMillis() - recent.time < 10 * 60 * 1000) {
            finishLocation(recent.asMap())
            return
        }

        val handler = Handler(Looper.getMainLooper())
        lateinit var listener: LocationListener
        val giveUp = Runnable {
            manager.removeUpdates(listener)
            finishLocation(recent?.asMap() ?: mapOf("error" to "unavailable"))
        }
        listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                handler.removeCallbacks(giveUp)
                manager.removeUpdates(this)
                finishLocation(location.asMap())
            }

            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }
        try {
            val provider = if (LocationManager.NETWORK_PROVIDER in providers) LocationManager.NETWORK_PROVIDER else providers.first()
            manager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
            handler.postDelayed(giveUp, 10_000)
        } catch (e: Exception) {
            finishLocation(recent?.asMap() ?: mapOf("error" to "unavailable"))
        }
    }
}
