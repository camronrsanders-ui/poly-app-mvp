package com.polycircle.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.provider.Settings
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
        private const val DISCOVER_LOCATION_CHANNEL = "com.polycircle.app/discover_location"
        private const val LOCATION_PERMISSION_REQUEST = 4201
        private const val LOCATION_TIMEOUT_MS = 15_000L
        private const val FRESH_LOCATION_MS = 15 * 60_000L
        private const val ADULT_AGE = 18
    }

    private var pendingLocationResult: MethodChannel.Result? = null
    private var currentLocationListener: LocationListener? = null
    private var currentLocationCancellation: CancellationSignal? = null
    private val locationHandler = Handler(Looper.getMainLooper())
    private val locationTimeout = Runnable {
        completeLocation(mapOf("status" to "unavailable"))
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DISCOVER_LOCATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestCurrentLocation" -> requestDiscoverLocation(result)
                "openLocationSettings" -> {
                    val target = call.argument<String>("target")
                    openLocationSettings(target)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestDiscoverLocation(result: MethodChannel.Result) {
        if (pendingLocationResult != null) {
            result.error(
                "LOCATION_REQUEST_IN_PROGRESS",
                "A Discover location request is already active.",
                null,
            )
            return
        }
        val manager = getSystemService(LOCATION_SERVICE) as LocationManager
        val enabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.isLocationEnabled
        } else {
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
        if (!enabled) {
            result.success(mapOf("status" to "services_disabled"))
            return
        }

        pendingLocationResult = result
        locationHandler.postDelayed(locationTimeout, LOCATION_TIMEOUT_MS)
        if (!hasForegroundLocationPermission()) {
            requestPermissions(
                arrayOf(
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                ),
                LOCATION_PERMISSION_REQUEST,
            )
            return
        }
        readOneLocation(manager)
    }

    private fun hasForegroundLocationPermission(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCATION_PERMISSION_REQUEST || pendingLocationResult == null) return
        if (!hasForegroundLocationPermission()) {
            completeLocation(mapOf("status" to "denied"))
            return
        }
        readOneLocation(getSystemService(LOCATION_SERVICE) as LocationManager)
    }

    @Suppress("MissingPermission")
    private fun readOneLocation(manager: LocationManager) {
        val providers = listOf(
            LocationManager.NETWORK_PROVIDER,
            LocationManager.GPS_PROVIDER,
        ).filter { provider ->
            try {
                manager.isProviderEnabled(provider)
            } catch (_: Exception) {
                false
            }
        }
        if (providers.isEmpty()) {
            completeLocation(mapOf("status" to "services_disabled"))
            return
        }

        val recent = providers
            .mapNotNull { provider ->
                try {
                    manager.getLastKnownLocation(provider)
                } catch (_: SecurityException) {
                    null
                }
            }
            .filter { location ->
                System.currentTimeMillis() - location.time <= FRESH_LOCATION_MS
            }
            .maxByOrNull { location -> location.time }
        if (recent != null) {
            completeLocation(locationPayload(recent))
            return
        }

        val provider = providers.first()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val cancellation = CancellationSignal()
            currentLocationCancellation = cancellation
            manager.getCurrentLocation(provider, cancellation, mainExecutor) { location ->
                if (location == null) {
                    completeLocation(mapOf("status" to "unavailable"))
                } else {
                    completeLocation(locationPayload(location))
                }
            }
            return
        }

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                completeLocation(locationPayload(location))
            }

            @Deprecated("Deprecated in Android")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

            override fun onProviderEnabled(provider: String) = Unit

            override fun onProviderDisabled(provider: String) {
                completeLocation(mapOf("status" to "services_disabled"))
            }
        }
        currentLocationListener = listener
        manager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
    }

    private fun locationPayload(location: Location): Map<String, Any> = mapOf(
        "status" to "ready",
        "latitude" to location.latitude,
        "longitude" to location.longitude,
        "accuracyMeters" to location.accuracy.toDouble(),
        "observedAtMs" to location.time,
    )

    private fun completeLocation(payload: Map<String, Any>) {
        val result = pendingLocationResult ?: return
        pendingLocationResult = null
        locationHandler.removeCallbacks(locationTimeout)
        currentLocationCancellation?.cancel()
        currentLocationCancellation = null
        currentLocationListener?.let { listener ->
            try {
                (getSystemService(LOCATION_SERVICE) as LocationManager).removeUpdates(listener)
            } catch (_: SecurityException) {
                // Completion is already fail-closed; there is no continuous tracking.
            }
        }
        currentLocationListener = null
        result.success(payload)
    }

    private fun openLocationSettings(target: String?) {
        val intent = if (target == "location_services") {
            Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            )
        }
        startActivity(intent)
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
