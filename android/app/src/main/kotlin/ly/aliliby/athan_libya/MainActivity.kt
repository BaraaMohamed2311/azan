package ly.aliliby.athan_libya

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "ly.aliliby.athan_libya/azan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        try {
                            val list = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
                            val items = list.map {
                                AzanItem(
                                    id = (it["id"] as Number).toInt(),
                                    time = (it["time"] as Number).toLong(),
                                    title = it["title"] as String,
                                    body = it["body"] as String,
                                    sound = it["sound"] as Boolean,
                                )
                            }
                            AzanScheduler.replaceAll(applicationContext, items)
                            result.success(items.size)
                        } catch (e: Exception) {
                            result.error("SCHEDULE_FAILED", e.message, null)
                        }
                    }
                    "cancel" -> {
                        AzanScheduler.cancelAll(applicationContext)
                        AzanService.stop()
                        result.success(null)
                    }
                    "stop" -> {
                        AzanService.stop()
                        result.success(null)
                    }
                    "test" -> {
                        val title = call.argument<String>("title") ?: "حان وقت الصلاة"
                        val body = call.argument<String>("body") ?: "أذان ليبيا — حيّ على الصلاة"
                        val sound = call.argument<Boolean>("sound") ?: true
                        if (sound) AzanService.start(applicationContext, title, body)
                        else AzanService.notifySilent(applicationContext, title, body)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Volume buttons pressed while the app is open also stop the azan.
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            AzanService.stop()
        }
        return super.onKeyDown(keyCode, event)
    }
}
