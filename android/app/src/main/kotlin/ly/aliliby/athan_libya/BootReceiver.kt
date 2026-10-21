package ly.aliliby.athan_libya

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restores scheduled alarms after reboot, app update, clock or timezone change. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AzanScheduler.restore(context)
    }
}
