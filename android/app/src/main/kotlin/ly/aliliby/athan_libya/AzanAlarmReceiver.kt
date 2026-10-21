package ly.aliliby.athan_libya

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fired by AlarmManager at prayer time. */
class AzanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "حان وقت الصلاة"
        val body = intent.getStringExtra("body") ?: "أذان ليبيا — حيّ على الصلاة"
        val sound = intent.getBooleanExtra("sound", true)
        val time = intent.getLongExtra("time", 0L)

        // Ignore alarms delivered far too late (e.g. phone was off).
        if (time > 0 && System.currentTimeMillis() - time > 10 * 60 * 1000L) return

        if (sound) {
            AzanService.start(context, title, body)
        } else {
            AzanService.notifySilent(context, title, body)
        }
    }
}
