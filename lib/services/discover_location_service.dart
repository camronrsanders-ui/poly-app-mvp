import 'dart:async';

import 'package:flutter/services.dart';

enum DiscoverLocationStatus {
  ready,
  denied,
  restricted,
  servicesDisabled,
  unavailable,
}

class DiscoverLocationSample {
  const DiscoverLocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.observedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime observedAt;
}

class DiscoverLocationOutcome {
  const DiscoverLocationOutcome(this.status, {this.sample});

  final DiscoverLocationStatus status;
  final DiscoverLocationSample? sample;

  static DiscoverLocationOutcome fromPlatformValue(Object? value) {
    if (value is! Map) {
      return const DiscoverLocationOutcome(
        DiscoverLocationStatus.unavailable,
      );
    }
    final status = value['status']?.toString();
    if (status != 'ready') {
      return DiscoverLocationOutcome(
        switch (status) {
          'denied' => DiscoverLocationStatus.denied,
          'restricted' => DiscoverLocationStatus.restricted,
          'services_disabled' => DiscoverLocationStatus.servicesDisabled,
          _ => DiscoverLocationStatus.unavailable,
        },
      );
    }

    final latitude = (value['latitude'] as num?)?.toDouble();
    final longitude = (value['longitude'] as num?)?.toDouble();
    final accuracy = (value['accuracyMeters'] as num?)?.toDouble();
    final observedAtMs = (value['observedAtMs'] as num?)?.toInt();
    if (latitude == null ||
        longitude == null ||
        accuracy == null ||
        observedAtMs == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        !accuracy.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        accuracy < 0) {
      return const DiscoverLocationOutcome(
        DiscoverLocationStatus.unavailable,
      );
    }

    return DiscoverLocationOutcome(
      DiscoverLocationStatus.ready,
      sample: DiscoverLocationSample(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracy,
        observedAt: DateTime.fromMillisecondsSinceEpoch(observedAtMs),
      ),
    );
  }
}

abstract interface class DiscoverLocationProvider {
  Future<DiscoverLocationOutcome> requestCurrentLocation();

  Future<void> openSettings(DiscoverLocationStatus status);
}

class PlatformDiscoverLocationProvider implements DiscoverLocationProvider {
  const PlatformDiscoverLocationProvider();

  static const _channel = MethodChannel('com.polycircle.app/discover_location');
  static const _timeout = Duration(seconds: 18);

  @override
  Future<DiscoverLocationOutcome> requestCurrentLocation() async {
    try {
      final value = await _channel
          .invokeMethod<Object?>('requestCurrentLocation')
          .timeout(_timeout);
      return DiscoverLocationOutcome.fromPlatformValue(value);
    } on TimeoutException {
      return const DiscoverLocationOutcome(
        DiscoverLocationStatus.unavailable,
      );
    } on PlatformException {
      return const DiscoverLocationOutcome(
        DiscoverLocationStatus.unavailable,
      );
    } on MissingPluginException {
      return const DiscoverLocationOutcome(
        DiscoverLocationStatus.unavailable,
      );
    }
  }

  @override
  Future<void> openSettings(DiscoverLocationStatus status) async {
    try {
      await _channel.invokeMethod<void>('openLocationSettings', {
        'target': status == DiscoverLocationStatus.servicesDisabled
            ? 'location_services'
            : 'app_permission',
      });
    } on PlatformException {
      // Settings guidance is best-effort. The visible Retry action remains.
    } on MissingPluginException {
      // Non-mobile test/preview platforms retain the visible Retry action.
    }
  }
}
