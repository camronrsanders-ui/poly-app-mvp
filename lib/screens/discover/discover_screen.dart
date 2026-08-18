import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/discovery_options.dart';
import '../../services/connection_service.dart';
import '../../services/discover_location_service.dart';
import '../../services/discovery_service.dart';
import '../../services/profile_media_service.dart';
import '../../widgets/discovery_orbit.dart';
import '../profile/profile_detail_screen.dart';
import '../safety/safety_center_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    this.discovery,
    this.locationProvider,
    this.likeUser,
    this.passUser,
    this.onViewProfile,
    this.profileImageBuilder,
  });

  final DiscoverRepository? discovery;
  final DiscoverLocationProvider? locationProvider;
  final Future<bool> Function(String uid)? likeUser;
  final Future<void> Function(String uid)? passUser;
  final ValueChanged<Map<String, dynamic>>? onViewProfile;
  final Widget Function(String uid)? profileImageBuilder;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _locationRefreshInterval = Duration(minutes: 15);

  late final DiscoverRepository _discovery;
  late final DiscoverLocationProvider _locationProvider;
  late final Future<bool> Function(String uid) _likeUser;
  late final Future<void> Function(String uid) _passUser;
  late final ProfileMediaService? _profileMedia;
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _actingOn = {};
  final Map<String, Future<List<VisibleProfilePhoto>>> _photoFutures = {};
  int _distanceMiles = defaultDiscoverDistanceMiles;
  bool _initializing = true;
  bool _savingDistance = false;
  Object? _setupError;
  DiscoverLocationStatus? _locationProblem;
  DateTime? _lastLocationRefresh;

  @override
  void initState() {
    super.initState();
    _discovery = widget.discovery ?? DiscoveryService();
    _locationProvider =
        widget.locationProvider ?? const PlatformDiscoverLocationProvider();
    if (widget.likeUser != null && widget.passUser != null) {
      _likeUser = widget.likeUser!;
      _passUser = widget.passUser!;
    } else {
      final connections = ConnectionService();
      _likeUser = widget.likeUser ?? connections.likeUser;
      _passUser = widget.passUser ?? connections.passUser;
    }
    _profileMedia =
        widget.profileImageBuilder == null ? ProfileMediaService() : null;
    _future = Future.value(const <Map<String, dynamic>>[]);
    _initializeDiscover();
  }

  Future<void> _initializeDiscover() async {
    try {
      final distance = await _discovery.loadDistanceMiles();
      if (!mounted) return;
      setState(() {
        _distanceMiles = normalizedDiscoverDistanceMiles(distance);
      });

      final hasLocation = await _refreshLocation(force: true);
      if (!mounted) return;
      if (hasLocation) {
        setState(() {
          _initializing = false;
          _future = _discovery.loadCandidates();
        });
      } else {
        setState(() => _initializing = false);
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover setup failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _setupError = error;
      });
    }
  }

  Future<bool> _refreshLocation({required bool force}) async {
    final refreshedAt = _lastLocationRefresh;
    if (!force &&
        refreshedAt != null &&
        DateTime.now().difference(refreshedAt) < _locationRefreshInterval) {
      return true;
    }

    final outcome = await _locationProvider.requestCurrentLocation();
    if (!mounted) return false;
    final sample = outcome.sample;
    if (outcome.status != DiscoverLocationStatus.ready || sample == null) {
      setState(() => _locationProblem = outcome.status);
      return false;
    }

    setState(() => _locationProblem = null);
    await _discovery.updateLocation(
      latitude: sample.latitude,
      longitude: sample.longitude,
      accuracyMeters: sample.accuracyMeters,
      observedAt: sample.observedAt,
    );
    if (!mounted) return false;
    setState(() {
      _lastLocationRefresh = DateTime.now();
      _locationProblem = null;
      _setupError = null;
    });
    return true;
  }

  Future<List<VisibleProfilePhoto>> _photosFor(String uid) {
    if (uid.isEmpty) return Future.value(const <VisibleProfilePhoto>[]);

    return _photoFutures.putIfAbsent(
      uid,
      () => _profileMedia!.listVisiblePhotos(uid),
    );
  }

  void _reload() {
    if (!mounted || _locationProblem != null) return;

    setState(() {
      _photoFutures.clear();
      _future = _discovery.loadCandidates();
    });
  }

  Future<void> _refresh() async {
    final hasLocation = await _refreshLocation(force: false);
    if (!mounted || !hasLocation) return;
    final future = _discovery.loadCandidates();

    if (!mounted) return;

    setState(() {
      _photoFutures.clear();
      _future = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder presents the user-facing error state.
    }
  }

  Future<void> _like(Map<String, dynamic> profile) async {
    final uid = profile['uid'] as String?;

    if (uid == null || _actingOn.contains(uid)) return;

    setState(() => _actingOn.add(uid));

    try {
      final matched = await _likeUser(uid);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            matched ? 'You connected 🎉' : 'Interest sent.',
          ),
        ),
      );

      _reload();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover like failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send interest right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _actingOn.remove(uid));
      }
    }
  }

  Future<void> _pass(Map<String, dynamic> profile) async {
    final uid = profile['uid'] as String?;

    if (uid == null || _actingOn.contains(uid)) return;

    setState(() => _actingOn.add(uid));

    try {
      await _passUser(uid);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Passed. This profile will stay out of Discover.',
          ),
        ),
      );

      _reload();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover pass failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save that Pass right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _actingOn.remove(uid));
      }
    }
  }

  Future<void> _viewProfile(Map<String, dynamic> profile) async {
    final override = widget.onViewProfile;
    if (override != null) {
      override(profile);
      return;
    }
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(profile: profile),
      ),
    );

    if (!mounted) return;

    if (result == 'liked' || result == 'matched' || result == 'blocked') {
      _reload();
    }
  }

  Widget _profileImage(String uid) {
    final override = widget.profileImageBuilder;
    if (override != null) return override(uid);
    return FutureBuilder<List<VisibleProfilePhoto>>(
      future: _photosFor(uid),
      builder: (context, snapshot) {
        final photos = snapshot.data ?? const <VisibleProfilePhoto>[];

        if (photos.isNotEmpty) {
          return Image.network(
            photos.first.url.toString(),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            gaplessPlayback: true,
            cacheWidth: 640,
            errorBuilder: (_, __, ___) => _photoFallback(),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ColoredBox(
            color: Color(0xFF21122F),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFC596FF),
                ),
              ),
            ),
          );
        }

        return _photoFallback();
      },
    );
  }

  Widget _photoFallback() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [
            Color(0xFF68418A),
            Color(0xFF321A43),
            Color(0xFF130B1B),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.person_rounded,
            size: 33,
            color: Color(0xFFE8D7F9),
          ),
          Positioned(
            top: 9,
            right: 10,
            child: Icon(
              Icons.auto_awesome,
              size: 10,
              color: Color(0xB3DDB8FF),
            ),
          ),
        ],
      ),
    );
  }

  void _openSafetyCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SafetyCenterScreen(),
      ),
    );
  }

  Future<void> _retryLocation() async {
    if (_initializing) return;
    setState(() {
      _initializing = true;
      _setupError = null;
    });
    try {
      final hasLocation = await _refreshLocation(force: true);
      if (!mounted) return;
      setState(() {
        _initializing = false;
        if (hasLocation) _future = _discovery.loadCandidates();
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover location retry failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _setupError = error;
      });
    }
  }

  Future<void> _openLocationSettings() async {
    final status = _locationProblem;
    if (status == null) return;
    await _locationProvider.openSettings(status);
  }

  Future<void> _showDistancePicker() async {
    if (_savingDistance) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DiscoverDistanceSheet(
        selectedMiles: _distanceMiles,
      ),
    );
    if (selected == null || selected == _distanceMiles || !mounted) return;
    await _setDistance(selected);
  }

  Future<void> _setDistance(int distanceMiles) async {
    if (_savingDistance ||
        !discoverDistanceOptionsMiles.contains(distanceMiles)) {
      return;
    }
    setState(() => _savingDistance = true);
    try {
      await _discovery.saveDistanceMiles(distanceMiles);
      if (!mounted) return;
      setState(() {
        _distanceMiles = distanceMiles;
        _photoFutures.clear();
        if (_locationProblem == null) {
          _future = _discovery.loadCandidates();
        }
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover distance update failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update your Discover radius right now.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingDistance = false);
    }
  }

  Widget _locationUnavailable(DiscoverLocationStatus status) {
    final servicesDisabled = status == DiscoverLocationStatus.servicesDisabled;
    final permissionUnavailable = status == DiscoverLocationStatus.denied ||
        status == DiscoverLocationStatus.restricted;
    return _StateMessage(
      icon: Icons.location_off_outlined,
      title: 'Nearby Discover needs your location',
      text: servicesDisabled
          ? 'Turn on Location Services, then retry. Polycircle only requests a foreground location when Discover needs it.'
          : permissionUnavailable
              ? 'Allow location while using Polycircle to find nearby worlds. Your precise coordinates are never shown to other members.'
              : 'We could not get a current location. Check your connection and device location, then retry.',
      action: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          TextButton.icon(
            key: const ValueKey('discover-location-retry'),
            onPressed: _retryLocation,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
          if (servicesDisabled || permissionUnavailable)
            TextButton.icon(
              key: const ValueKey('discover-location-settings'),
              onPressed: _openLocationSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open settings'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DiscoverWorld(
      onOpenSafetyCenter: _openSafetyCenter,
      distanceMiles: _distanceMiles,
      distanceBusy: _savingDistance,
      onChangeDistance: _showDistancePicker,
      child: _initializing
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFC596FF)),
            )
          : _locationProblem != null
              ? _locationUnavailable(_locationProblem!)
              : _setupError != null
                  ? _StateMessage(
                      icon: Icons.error_outline,
                      title: 'Discover is taking a break',
                      text:
                          'We could not prepare nearby Discover. Check your connection and try again.',
                      debugDetails: kDebugMode ? _setupError.toString() : null,
                      action: TextButton(
                        onPressed: _retryLocation,
                        child: const Text('Try again'),
                      ),
                    )
                  : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFC596FF),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          if (snapshot.error
                              is DiscoverLocationRequiredException) {
                            return _locationUnavailable(
                              DiscoverLocationStatus.unavailable,
                            );
                          }
                          if (kDebugMode) {
                            debugPrint(
                              'Discover load failed: ${snapshot.error}',
                            );

                            if (snapshot.stackTrace != null) {
                              debugPrintStack(
                                stackTrace: snapshot.stackTrace!,
                              );
                            }
                          }

                          return _StateMessage(
                            icon: Icons.error_outline,
                            title: 'Discover is taking a break',
                            text:
                                'We could not load profiles. Check your connection and try again.',
                            debugDetails:
                                kDebugMode ? snapshot.error?.toString() : null,
                            action: TextButton(
                              onPressed: _reload,
                              child: const Text('Try again'),
                            ),
                          );
                        }

                        final profiles = snapshot.data ?? [];

                        if (profiles.isEmpty) {
                          final nextDistance =
                              nextDiscoverDistanceMiles(_distanceMiles);
                          return _StateMessage(
                            icon: Icons.travel_explore_outlined,
                            title:
                                'No new worlds within $_distanceMiles miles.',
                            text:
                                'Your selected distance stays in control. Refresh or explicitly increase it to explore farther.',
                            action: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              children: [
                                TextButton(
                                  key: const ValueKey('discover-empty-refresh'),
                                  onPressed: _reload,
                                  child: const Text('Refresh'),
                                ),
                                if (nextDistance != null)
                                  TextButton(
                                    key: const ValueKey(
                                        'discover-increase-radius'),
                                    onPressed: () => _setDistance(nextDistance),
                                    child: Text('Increase to $nextDistance mi'),
                                  ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          color: const Color(0xFFC596FF),
                          backgroundColor: const Color(0xFF21122F),
                          onRefresh: _refresh,
                          child: ListView(
                            key: const ValueKey('discover-world-scroll-view'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(0, 2, 0, 24),
                            children: [
                              DiscoveryOrbit(
                                profiles: profiles,
                                imageBuilder: _profileImage,
                                onViewProfile: (profile) =>
                                    _viewProfile(profile),
                                onLike: (profile) => _like(profile),
                                onPass: (profile) => _pass(profile),
                                isActing: (uid) => _actingOn.contains(uid),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _DiscoverWorld extends StatelessWidget {
  const _DiscoverWorld({
    required this.onOpenSafetyCenter,
    required this.distanceMiles,
    required this.distanceBusy,
    required this.onChangeDistance,
    required this.child,
  });

  final VoidCallback onOpenSafetyCenter;
  final int distanceMiles;
  final bool distanceBusy;
  final VoidCallback onChangeDistance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('discover-cosmic-world'),
      color: const Color(0xFF05030B),
      child: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DiscoverWorldPainter(),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 10, 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explore your orbit',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: const Color(0xFFF8F2FF),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.35,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Move through the people whose worlds may cross yours.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFFB7A9C4),
                                    height: 1.25,
                                  ),
                            ),
                            const SizedBox(height: 9),
                            Semantics(
                              button: true,
                              label:
                                  'Discovery radius, within $distanceMiles miles',
                              hint: 'Activate to change your nearby radius',
                              child: OutlinedButton.icon(
                                key: const ValueKey(
                                  'discover-radius-control',
                                ),
                                onPressed:
                                    distanceBusy ? null : onChangeDistance,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEBD9FF),
                                  backgroundColor: const Color(0x7321122F),
                                  side: const BorderSide(
                                    color: Color(0xFF69408D),
                                    width: 0.9,
                                  ),
                                  minimumSize: const Size(0, 34),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 6,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  shape: const StadiumBorder(),
                                ),
                                icon: distanceBusy
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFC596FF),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.location_on_outlined,
                                        size: 17,
                                      ),
                                label: Text('Within $distanceMiles mi'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: 'Open Safety center',
                        child: IconButton(
                          key: const ValueKey('discover-safety-center'),
                          tooltip: 'Safety center',
                          onPressed: onOpenSafetyCenter,
                          style: IconButton.styleFrom(
                            foregroundColor: const Color(0xFFE7D5F8),
                            backgroundColor: const Color(0x66231631),
                            side: const BorderSide(
                              color: Color(0xFF4B2B63),
                            ),
                          ),
                          icon: const Icon(Icons.shield_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverDistanceSheet extends StatelessWidget {
  const _DiscoverDistanceSheet({required this.selectedMiles});

  final int selectedMiles;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('discover-radius-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF21122F), Color(0xFF0D0914)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: Color(0xFF754AA0)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C6A89),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Explore nearby',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFF8F1FF),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how far your Orbit reaches. It will never widen silently.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB9ACC4),
                  ),
            ),
            const SizedBox(height: 16),
            for (final miles in discoverDistanceOptionsMiles)
              Semantics(
                button: true,
                selected: miles == selectedMiles,
                label: '$miles mile Discover radius',
                child: ListTile(
                  key: ValueKey('discover-radius-$miles'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: miles == selectedMiles
                          ? const Color(0xFFB77CFA)
                          : Colors.transparent,
                    ),
                  ),
                  tileColor: miles == selectedMiles
                      ? const Color(0xFF4A2469)
                      : Colors.transparent,
                  textColor: const Color(0xFFF1E8F8),
                  iconColor: const Color(0xFFD3A7FF),
                  title: Text('$miles mi'),
                  trailing: miles == selectedMiles
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: () => Navigator.of(context).pop(miles),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverWorldPainter extends CustomPainter {
  const _DiscoverWorldPainter();

  static const _stars = <Offset>[
    Offset(0.05, 0.09),
    Offset(0.13, 0.23),
    Offset(0.2, 0.06),
    Offset(0.29, 0.33),
    Offset(0.37, 0.15),
    Offset(0.46, 0.04),
    Offset(0.55, 0.28),
    Offset(0.63, 0.1),
    Offset(0.72, 0.37),
    Offset(0.8, 0.18),
    Offset(0.91, 0.07),
    Offset(0.96, 0.31),
    Offset(0.08, 0.49),
    Offset(0.18, 0.62),
    Offset(0.33, 0.52),
    Offset(0.44, 0.73),
    Offset(0.59, 0.57),
    Offset(0.7, 0.77),
    Offset(0.84, 0.55),
    Offset(0.93, 0.7),
    Offset(0.11, 0.87),
    Offset(0.27, 0.94),
    Offset(0.51, 0.89),
    Offset(0.76, 0.93),
    Offset(0.9, 0.84),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final upperGlow = Rect.fromCircle(
      center: Offset(size.width * 0.5, size.height * 0.27),
      radius: size.width * 0.72,
    );
    canvas.drawCircle(
      upperGlow.center,
      upperGlow.width / 2,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0x382E0C4D),
            Color(0x181A0B2B),
            Color(0x0005030B),
          ],
        ).createShader(upperGlow),
    );

    final lowerGlow = Rect.fromCircle(
      center: Offset(size.width * 0.8, size.height * 0.78),
      radius: size.width * 0.64,
    );
    canvas.drawCircle(
      lowerGlow.center,
      lowerGlow.width / 2,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0x242B0D43),
            Color(0x0005030B),
          ],
        ).createShader(lowerGlow),
    );

    for (var index = 0; index < _stars.length; index++) {
      final star = _stars[index];
      final prominent = index % 6 == 0;
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        prominent ? 1.25 : 0.65,
        Paint()
          ..color =
              (index.isEven ? const Color(0xFFD9BDFF) : const Color(0xFF8D7CA0))
                  .withValues(alpha: prominent ? 0.42 : 0.22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiscoverWorldPainter oldDelegate) => false;
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    this.debugDetails,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget action;
  final String? debugDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFFB987F2)),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFFF7F0FF),
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFB9ACC4),
              ),
            ),
            if (debugDetails != null && debugDetails!.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                debugDetails!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9C8FA8),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Theme(
              data: theme.copyWith(
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD8B6FF),
                  ),
                ),
              ),
              child: action,
            ),
          ],
        ),
      ),
    );
  }
}
