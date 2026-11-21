package cachet.plugins.health

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.response.InsertRecordsResponse
import androidx.health.connect.client.units.Pressure
import cachet.plugins.health.HealthConstants.BLOOD_PRESSURE_DIASTOLIC
import cachet.plugins.health.HealthConstants.BLOOD_PRESSURE_SYSTOLIC
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Proxy
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Test

class BloodPressureTest {
    private val time = Instant.parse("2026-11-08T10:00:00Z")

    private fun record(bodyPosition: Int, measurementLocation: Int) = BloodPressureRecord(
        time = time,
        zoneOffset = null,
        metadata = Metadata.manualEntry(),
        systolic = Pressure.millimetersOfMercury(120.0),
        diastolic = Pressure.millimetersOfMercury(80.0),
        bodyPosition = bodyPosition,
        measurementLocation = measurementLocation,
    )

    @Test
    fun `converter returns body position and measurement location`() {
        val record = record(
            BloodPressureRecord.BODY_POSITION_SITTING_DOWN,
            BloodPressureRecord.MEASUREMENT_LOCATION_LEFT_UPPER_ARM,
        )

        for (type in listOf(BLOOD_PRESSURE_SYSTOLIC, BLOOD_PRESSURE_DIASTOLIC)) {
            val point = HealthDataConverter().convertRecord(record, type).single()
            assertEquals(BloodPressureRecord.BODY_POSITION_SITTING_DOWN, point["body_position"])
            assertEquals(
                BloodPressureRecord.MEASUREMENT_LOCATION_LEFT_UPPER_ARM,
                point["measurement_location"],
            )
        }
    }

    /** A [HealthConnectClient] that keeps the records passed to `insertRecords`. */
    private class RecordingClient {
        val inserted = mutableListOf<Record>()
        val client: HealthConnectClient = Proxy.newProxyInstance(
            HealthConnectClient::class.java.classLoader,
            arrayOf(HealthConnectClient::class.java),
        ) { _, method, args ->
            check(method.name == "insertRecords") { "Unexpected call: ${method.name}" }
            @Suppress("UNCHECKED_CAST")
            inserted += args!![0] as List<Record>
            InsertRecordsResponse(emptyList())
        } as HealthConnectClient
    }

    /** A [MethodChannel.Result] that keeps the value passed to `success`. */
    private class CapturingResult : MethodChannel.Result {
        var value: Any? = null
        override fun success(result: Any?) { value = result }
        override fun error(code: String, message: String?, details: Any?) =
            throw AssertionError("error: $code $message")
        override fun notImplemented() = throw AssertionError("notImplemented")
    }

    private fun writeBloodPressure(arguments: Map<String, Any?>): BloodPressureRecord {
        val client = RecordingClient()
        val result = CapturingResult()
        // Unconfined runs the launched coroutine at once, and the fake client does not suspend.
        HealthDataWriter(client.client, CoroutineScope(Dispatchers.Unconfined))
            .writeBloodPressure(MethodCall("writeBloodPressure", arguments), result)

        assertEquals(true, result.value)
        return client.inserted.single() as BloodPressureRecord
    }

    private val baseArguments = mapOf<String, Any?>(
        "systolic" to 120.0,
        "diastolic" to 80.0,
        "startTime" to time.toEpochMilli(),
        "endTime" to time.toEpochMilli(),
        "recordingMethod" to 1,
    )

    @Test
    fun `writer saves body position and measurement location`() {
        val saved = writeBloodPressure(
            baseArguments + mapOf(
                "bodyPosition" to BloodPressureRecord.BODY_POSITION_RECLINING,
                "measurementLocation" to BloodPressureRecord.MEASUREMENT_LOCATION_RIGHT_WRIST,
            )
        )

        assertEquals(BloodPressureRecord.BODY_POSITION_RECLINING, saved.bodyPosition)
        assertEquals(BloodPressureRecord.MEASUREMENT_LOCATION_RIGHT_WRIST, saved.measurementLocation)
    }

    @Test
    fun `writer saves unknown when body position and measurement location are missing`() {
        val saved = writeBloodPressure(baseArguments)

        assertEquals(BloodPressureRecord.BODY_POSITION_UNKNOWN, saved.bodyPosition)
        assertEquals(BloodPressureRecord.MEASUREMENT_LOCATION_UNKNOWN, saved.measurementLocation)
    }
}
