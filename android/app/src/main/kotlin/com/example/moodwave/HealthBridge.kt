package com.example.moodwave

import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId

/** No automatic permission prompts or background reading. API 27 always returns manual. */
class HealthBridge(private val activity: FlutterFragmentActivity) {
    private val permissions = setOf(HealthPermission.getReadPermission(StepsRecord::class), HealthPermission.getReadPermission(SleepSessionRecord::class))
    private var pending: MethodChannel.Result? = null
    private val launcher = activity.registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
        pending?.success(if (granted.containsAll(permissions)) "connected" else "denied")
        pending = null
    }
    private fun status(): String {
        if (Build.VERSION.SDK_INT < 28) return "unsupported"
        return when (HealthConnectClient.getSdkStatus(activity)) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
            else -> "unavailable"
        }
    }
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        activity.lifecycleScope.launch {
            try {
                val state = status()
                if (state != "available") { result.success(if (call.method == "read") emptyList<Any>() else state); return@launch }
                val client = HealthConnectClient.getOrCreate(activity)
                val granted = client.permissionController.getGrantedPermissions().containsAll(permissions)
                when (call.method) {
                    "status" -> result.success(if (granted) "connected" else "available")
                    "connect" -> {
                        if (granted) result.success("connected")
                        else if (pending != null) result.error("busy", "Permiso en curso", null)
                        else { pending = result; launcher.launch(permissions) }
                    }
                    "disconnect" -> { client.permissionController.revokeAllPermissions(); result.success("available") }
                    "read" -> {
                        if (!granted) { result.error("denied", "Conecta Health Connect antes de importar", null); return@launch }
                        val start = LocalDate.parse(call.argument<String>("start"))
                        val end = LocalDate.parse(call.argument<String>("end"))
                        require(!end.isBefore(start) && java.time.temporal.ChronoUnit.DAYS.between(start, end) <= 30)
                        val rows = mutableListOf<Map<String, Any?>>()
                        var date = start
                        val zone = ZoneId.systemDefault()
                        while (date.isBefore(end)) {
                            val time = TimeRangeFilter.between(date.atStartOfDay(zone).toInstant(), date.plusDays(1).atStartOfDay(zone).toInstant())
                            val values = client.aggregate(AggregateRequest(metrics = setOf(StepsRecord.COUNT_TOTAL, SleepSessionRecord.SLEEP_DURATION_TOTAL), timeRangeFilter = time))
                            val steps = values[StepsRecord.COUNT_TOTAL]?.toInt()
                            val sleep = values[SleepSessionRecord.SLEEP_DURATION_TOTAL]?.toMinutes()?.toInt()
                            if (steps != null || sleep != null) rows.add(mapOf("date" to date.toString(), "steps" to steps, "sleepMinutes" to sleep))
                            date = date.plusDays(1)
                        }
                        result.success(rows)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: SecurityException) { result.error("denied", "Permiso revocado; puedes seguir con captura manual", null) }
            catch (_: Exception) { result.error("health_error", "No se pudo leer Health Connect; usa captura manual o inténtalo de nuevo", null) }
        }
    }
}
