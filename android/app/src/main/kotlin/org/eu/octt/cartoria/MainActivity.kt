package org.eu.octt.cartoria

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cartoria/documents_provider"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setVaultPath" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        CartoriaDocumentsProvider.vaultPathOverride = path
                        result.success(null)
                    } else {
                        result.error(
                            "MISSING_PATH",
                            "No path argument provided",
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}