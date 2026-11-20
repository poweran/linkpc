package net.linkpc.client

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val TUNNEL_CHANNEL = "net.linkpc.client/tunnel"
    private val VPN_REQUEST_CODE = 2052
    private var pendingConfig: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TUNNEL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val config = call.argument<String>("config")
                    if (config.isNullOrEmpty()) {
                        result.error("INVALID_CONFIG", "Config cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    val prepareIntent = VpnService.prepare(this)
                    if (prepareIntent != null) {
                        pendingConfig = config
                        pendingResult = result
                        startActivityForResult(prepareIntent, VPN_REQUEST_CODE)
                    } else {
                        startVpnService(config)
                        result.success(true)
                    }
                }
                "stop" -> {
                    val intent = Intent(this, LinkpcVpnService::class.java).apply {
                        action = LinkpcVpnService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                "status" -> {
                    result.success(LinkpcVpnService.isRunning)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                pendingConfig?.let {
                    startVpnService(it)
                    pendingResult?.success(true)
                }
            } else {
                pendingResult?.error("PERMISSION_DENIED", "VPN permission was denied", null)
            }
            pendingConfig = null
            pendingResult = null
        }
    }

    private fun startVpnService(config: String) {
        val intent = Intent(this, LinkpcVpnService::class.java).apply {
            action = LinkpcVpnService.ACTION_START
            putExtra(LinkpcVpnService.EXTRA_CONFIG, config)
        }
        startService(intent)
    }
}
