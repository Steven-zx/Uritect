package ph.edu.wvsu.uritect

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity : FlutterActivity() {
    private val historySecurity by lazy { HistorySecurity(this) }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "ph.edu.wvsu.uritect/history_security")
            .setMethodCallHandler { call, result -> historySecurity.handle(call, result) }
    }
    override fun onStop() { historySecurity.onStop(); super.onStop() }
    @Deprecated("Framework credential result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!historySecurity.result(requestCode, resultCode)) super.onActivityResult(requestCode, resultCode, data)
    }
}
