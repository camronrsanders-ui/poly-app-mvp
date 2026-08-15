package com.polycircle.app

import com.google.android.play.agesignals.AgeSignalsAccessRequest
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.model.AgeSignalsStatus
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val AGE_CHANNEL = "com.polycircle.app/age_assurance"
        private const val ADULT_AGE = 18
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "requestAdultAgeSignal") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                requestAdultAgeSignal(result)
            }
    }

    private fun requestAdultAgeSignal(result: MethodChannel.Result) {
        val manager = AgeSignalsManagerFactory.create(applicationContext)
        val accessRequest = AgeSignalsAccessRequest.builder()
            .setActivity(this)
            .build()

        manager.requestAgeSignalsAccess(accessRequest)
            .addOnSuccessListener { accessResult ->
                when (accessResult.ageSignalsStatus()) {
                    AgeSignalsStatus.SHARED -> retrieveAgeSignals(manager, result)
                    AgeSignalsStatus.VERIFICATION_REQUIRED -> result.success(
                        mapOf(
                            "status" to "verification_required",
                            "platformStatus" to "verification_required",
                            "regulatedRegion" to true,
                        ),
                    )
                    else -> result.success(
                        mapOf(
                            "status" to "not_shared",
                            "platformStatus" to "not_shared",
                            "regulatedRegion" to false,
                        ),
                    )
                }
            }
            .addOnFailureListener {
                // We cannot safely determine whether mandatory sharing applies
                // when the access check itself fails. Require a successful retry
                // rather than silently downgrading an unknown jurisdiction to
                // self-attestation.
                result.success(
                    mapOf(
                        "status" to "unavailable",
                        "platformStatus" to "play_age_signals_error",
                        "regulatedRegion" to true,
                    ),
                )
            }
    }

    private fun retrieveAgeSignals(
        manager: AgeSignalsManager,
        result: MethodChannel.Result,
    ) {
        manager.checkAgeSignals(AgeSignalsRequest.builder().build())
            .addOnSuccessListener { ageResult ->
                val lower = ageResult.ageLower()
                val upper = ageResult.ageUpper()
                val source = ageResult.ageRangeSource()

                // Play Age Signals 0.0.4 removed the old userStatus field. The
                // supported response model is ageRangeSource plus age bounds.
                // For an adult-only app, the bounds are sufficient: an upper
                // bound below 18 is a minor, and a lower bound at least 18 is an
                // adult. Any shared-but-ambiguous response fails closed.
                val status = when {
                    upper != null && upper < ADULT_AGE -> "minor"
                    lower != null && lower >= ADULT_AGE -> "adult"
                    else -> "verification_required"
                }

                result.success(
                    mapOf(
                        "status" to status,
                        "platformStatus" to "shared",
                        "lowerBound" to lower,
                        "upperBound" to upper,
                        "source" to source?.toString(),
                        "regulatedRegion" to (status == "verification_required"),
                    ),
                )
            }
            .addOnFailureListener {
                // Access was shared but the actual signal could not be read. Do
                // not use a self-attested fallback for an indeterminate signal.
                result.success(
                    mapOf(
                        "status" to "unavailable",
                        "platformStatus" to "play_age_signals_error",
                        "regulatedRegion" to true,
                    ),
                )
            }
    }
}
