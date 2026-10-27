package `in`.doctorfresh.doctor_fresh

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

/**
 * Local reminders (purifier service due, filter change), written with the
 * Android SDK alone: AlarmManager wakes ReminderReceiver, which posts the
 * notification. Reminders are kept in SharedPreferences so BootReceiver can
 * set them again after the phone restarts — alarms do not survive a reboot.
 */
object Reminders {
    private const val PREFS = "df_reminders"
    private const val CHANNEL = "reminders"
    const val EXTRA_ROUTE = "df_route"

    fun schedule(context: Context, id: Int, at: Long, title: String, body: String, route: String) {
        val entry = JSONObject().put("at", at).put("title", title).put("body", body).put("route", route)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(id.toString(), entry.toString()).apply()
        arm(context, id, at)
    }

    fun cancel(context: Context, id: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(id.toString()).apply()
        alarms(context).cancel(alarmIntent(context, id))
    }

    /** After a reboot: everything still to come, again. */
    fun rearm(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        for ((key, value) in prefs.all) {
            val at = runCatching { JSONObject(value as String).getLong("at") }.getOrNull() ?: continue
            arm(context, key.toInt(), at)
        }
    }

    private fun alarms(context: Context) = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun alarmIntent(context: Context, id: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context, id,
            Intent(context, ReminderReceiver::class.java).putExtra("id", id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    // An inexact alarm is fine for a reminder and needs no special permission.
    private fun arm(context: Context, id: Int, at: Long) {
        alarms(context).set(AlarmManager.RTC_WAKEUP, maxOf(at, System.currentTimeMillis() + 5_000), alarmIntent(context, id))
    }

    fun show(context: Context, id: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val entry = prefs.getString(id.toString(), null)?.let { runCatching { JSONObject(it) }.getOrNull() } ?: return
        prefs.edit().remove(id.toString()).apply()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "Service reminders", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val open = PendingIntent.getActivity(
            context, id,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra(EXTRA_ROUTE, entry.optString("route")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, CHANNEL)
        } else {
            android.app.Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_reminder)
            .setContentTitle(entry.optString("title"))
            .setContentText(entry.optString("body"))
            .setStyle(android.app.Notification.BigTextStyle().bigText(entry.optString("body")))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { manager.notify(id, notification) }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Reminders.show(context, intent.getIntExtra("id", 0))
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) Reminders.rearm(context)
    }
}
