package com.example.moodwave

import android.Manifest
import android.content.pm.PackageManager
import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val healthBridge by lazy { HealthBridge(this) }
    private var cancellation: CancellationSignal? = null
    private var pending: MethodChannel.Result? = null
    private var documentResult: MethodChannel.Result? = null
    private var documentBytes: ByteArray? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.moodwave/health").setMethodCallHandler(healthBridge::handle)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.moodwave/documents").setMethodCallHandler { call, result ->
            if (call.method != "savePdf" && call.method != "saveJson") { result.notImplemented(); return@setMethodCallHandler }
            if (documentResult != null) { result.error("busy", "Ya hay un guardado en curso", null); return@setMethodCallHandler }
            val bytes = call.argument<ByteArray>("bytes")
            val name = call.argument<String>("name") ?: "moodwave.pdf"
            if (bytes == null || bytes.size > 10 * 1024 * 1024) { result.error("invalid", "PDF inválido o demasiado grande", null); return@setMethodCallHandler }
            documentBytes = bytes
            documentResult = result
            try {
                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = if (call.method == "saveJson") "application/json" else "application/pdf"
                    putExtra(Intent.EXTRA_TITLE, name)
                }, 41027)
            } catch (_: Exception) {
                documentBytes = null; documentResult = null
                result.error("unavailable", "No se pudo abrir el selector de archivos", null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.moodwave/legacy_fingerprint").setMethodCallHandler { call, result ->
            when (call.method) {
                "cancel" -> { cancelLegacy(); result.success(null) }
                "isAvailable", "hasEnrolledFingerprints", "authenticate" -> {
                    if (Build.VERSION.SDK_INT !in 23..27) {
                        result.success(if (call.method == "authenticate") "unavailable" else false)
                    } else legacy(call.method, result)
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 41027) return
        val result = documentResult ?: return
        val bytes = documentBytes
        documentResult = null; documentBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) { result.success(null); return }
        val resolver = applicationContext.contentResolver
        Thread {
            try {
                val output = resolver.openOutputStream(uri, "w") ?: throw IllegalStateException()
                output.use { it.write(bytes) }
                runOnUiThread { result.success(uri.toString()) }
            } catch (_: Exception) { runOnUiThread { result.error("write_failed", "No se pudo guardar el PDF", null) } }
        }.start()
    }
    private fun finish(value: String) {
        val result = pending
        pending = null
        val signal = cancellation
        cancellation = null
        result?.success(value)
        signal?.cancel()
    }
    private fun cancelLegacy() { finish("cancelled") }

    @Suppress("DEPRECATION")
    private fun legacy(method: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT !in 23..27) { result.success("unavailable"); return }
        if (checkSelfPermission(Manifest.permission.USE_FINGERPRINT) != PackageManager.PERMISSION_GRANTED) {
            result.success(if (method == "authenticate") "unavailable" else false); return
        }
        val manager = getSystemService(android.hardware.fingerprint.FingerprintManager::class.java)
        if (method == "isAvailable") { result.success(manager?.isHardwareDetected == true); return }
        if (method == "hasEnrolledFingerprints") { result.success(manager?.hasEnrolledFingerprints() == true); return }
        cancelLegacy()
        if (manager == null || !manager.isHardwareDetected) { result.success("noHardware"); return }
        if (!manager.hasEnrolledFingerprints()) { result.success("noEnrollment"); return }
        val signal = CancellationSignal()
        cancellation = signal
        pending = result
        try {
            manager.authenticate(null, signal, 0, object : android.hardware.fingerprint.FingerprintManager.AuthenticationCallback() {
                // Ignore callbacks from an attempt already cancelled or replaced.
                private fun complete(value: String) { if (cancellation === signal) finish(value) }
                override fun onAuthenticationSucceeded(value: android.hardware.fingerprint.FingerprintManager.AuthenticationResult?) { complete("success") }
                override fun onAuthenticationFailed() { complete("failed") }
                override fun onAuthenticationHelp(code: Int, message: CharSequence?) { complete("failed") }
                override fun onAuthenticationError(code: Int, message: CharSequence?) {
                    complete(if (code == android.hardware.fingerprint.FingerprintManager.FINGERPRINT_ERROR_CANCELED || code == android.hardware.fingerprint.FingerprintManager.FINGERPRINT_ERROR_USER_CANCELED) "cancelled" else "unavailable")
                }
            }, null)
        } catch (_: Exception) { if (cancellation === signal) finish("unavailable") }
    }
    override fun onStop() { cancelLegacy(); super.onStop() }
    override fun onDestroy() {
        cancelLegacy()
        documentBytes = null
        documentResult?.success(null); documentResult = null
        super.onDestroy()
    }
}
