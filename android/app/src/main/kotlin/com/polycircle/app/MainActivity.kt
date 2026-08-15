package com.polycircle.app

import com.google.android.play.agesignals.AgeSignalsAccessRequest
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.model.AgeSignalsStatus
import com.google.android.play.agesignals.model.AgeSignalsVerificationStatus
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
            .addOnFailureListener { error ->
                result.success(
                    mapOf(
                        "status" to "unavailable",
                        "platformStatus" to (error.javaClass.simpleName.ifEmpty { "play_age_signals_error" }),
                        "regulatedRegion" to false,
                    ),
                )
            }
    }

    private fun verificationStatusLabel(userStatus: Int?): String = when (userStatus) {
        AgeSignalsVerificationStatus.VERIFIED -> "verified"
        AgeSignalsVerificationStatus.SUPERVISED -> "supervised"
        AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING -> "supervised_approval_pending"
        AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED -> "supervised_approval_denied"
        AgeSignalsVerificationStatus.UNKNOWN -> "unknown"
        AgeSignalsVerificationStatus.DECLARED -> "declared"
        else -> "unrecognized"
    }

    private fun retrieveAgeSignals(
        manager: AgeSignalsManager,
        result: MethodChannel.Result,
    ) {
        manager.checkAgeSignals(AgeSignalsRequest.builder().build())
            .addOnSuccessListener { ageResult ->
                val lower = ageResult.ageLower()
                val upper = ageResult.ageUpper()
                val userStatus = ageResult.userStatus()
                val statusLabel = verificationStatusLabel(userStatus)

                // Google documents VERIFIED as an over-18 status. In that case
                // ageLower/ageUpper can both be null, so bounds alone are not a
                // sufficient adult check. For all other statuses, use the age
                // range defensively and fail closed when a shared signal remains
                // ambiguous around the 18+ boundary.
                val status = when {
                    userStatus == AgeSignalsVerificationStatus.VERIFIED -> "adult"
                    upper != null && upper < ADULT_AGE -> "minor"
                    lower != null && lower >= ADULT_AGE -> "adult"
                    userStatus == AgeSignalsVerificationStatus.UNKNOWN -> "verification_required"
                    userStatus == AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING -> "verification_required"
                    userStatus == AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED -> "verification_required"
                    lower != null || upper != null -> "verification_required"
                    else -> "not_shared"
                }

                val regulatedRegion =
                    userStatus == AgeSignalsVerificationStatus.UNKNOWN ||
                        status == "verification_required"

                result.success(
                    mapOf(
                        "status" to status,
                        "platformStatus" to "shared_$statusLabel",
                        "lowerBound" to lower,
                        "upperBound" to upper,
                        "source" to ageResult.ageRangeSource()?.toString(),
                        "regulatedRegion" to regulatedRegion,
                    ),
                )
            }
            .addOnFailureListener { error ->
                result.success(
                    mapOf(
                        "status" to "unavailable",
                        "platformStatus" to (error.javaClass.simpleName.ifEmpty { "play_age_signals_error" }),
                        "regulatedRegion" to false,
                    ),
                )
            }
    }
}
