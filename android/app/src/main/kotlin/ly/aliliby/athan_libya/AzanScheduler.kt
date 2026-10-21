package ly.aliliby.athan_libya

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/** One scheduled prayer alert. */
data class AzanItem(
    val id: Int,
    val time: Long,
    val title: String,
    val body: String,
    val sound: Boolean,
)

/**
 * Schedules prayer alerts with AlarmManager and persists them so they can be
 * restored after a reboot / app update / time change.
 */
object AzanScheduler {
    private const val PREFS = "azan_schedule"
    private const val KEY_ITEMS = "items"
    const val ACTION_ALARM = "ly.aliliby.athan_libya.action.AZAN_ALARM"

    fun replaceAll(context: Context, items: List<AzanItem>) {
        cancelAll(context)
        save(context, items)
        val now = System.currentTimeMillis()
        items.filter { it.time > now }.forEach { schedule(context, it) }
    }

    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        load(context).forEach { item ->
            val intent = Intent(context, AzanAlarmReceiver::class.java).setAction(ACTION_ALARM)
            val pi = PendingIntent.getBroadcast(
                context, item.id, intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) {
                am.cancel(pi)
                pi.cancel()
            }
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY_ITEMS).apply()
    }

    fun restore(context: Context) {
        val now = System.currentTimeMillis()
        load(context).filter { it.time > now }.forEach { schedule(context, it) }
    }

    private fun schedule(context: Context, item: AzanItem) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AzanAlarmReceiver::class.java)
            .setAction(ACTION_ALARM)
            .putExtra("id", item.id)
            .putExtra("time", item.time)
            .putExtra("title", item.title)
            .putExtra("body", item.body)
            .putExtra("sound", item.sound)
        val pi = PendingIntent.getBroadcast(
            context, item.id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
            if (canExact) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, item.time, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, item.time, pi)
                }
            } else {
                // Works without the exact-alarm permission and is exempt from Doze.
                val open = PendingIntent.getActivity(
                    context, 0,
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                am.setAlarmClock(AlarmManager.AlarmClockInfo(item.time, open), pi)
            }
        } catch (_: SecurityException) {
            am.set(AlarmManager.RTC_WAKEUP, item.time, pi)
        }
    }

    private fun save(context: Context, items: List<AzanItem>) {
        val arr = JSONArray()
        items.forEach {
            arr.put(
                JSONObject()
                    .put("id", it.id).put("time", it.time)
                    .put("title", it.title).put("body", it.body).put("sound", it.sound)
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_ITEMS, arr.toString()).apply()
    }

    private fun load(context: Context): List<AzanItem> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ITEMS, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                AzanItem(
                    o.getInt("id"), o.getLong("time"),
                    o.getString("title"), o.getString("body"), o.optBoolean("sound", true)
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
