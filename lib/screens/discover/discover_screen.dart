import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/discovery_options.dart';
import '../../services/connection_service.dart';
import '../../services/discover_location_service.dart';
import '../../services/discovery_service.dart';
import '../../services/profile_media_service.dart';
import '../../theme/app_theme.dart';
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
    this.profilePhotosLoader,
  });

  final DiscoverRepository? discovery;
  final DiscoverLocationProvider? locationProvider;
  final Future<bool> Function(String uid)? likeUser;
  final Future<void> Function(String uid)? passUser;
  final ValueChanged<Map<String, dynamic>>? onViewProfile;
  final Widget Function(String uid)? profileImageBuilder;
  final Future<List<VisibleProfilePhoto>> Function(String uid)?
      profilePhotosLoader;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _locationRefreshInterval = Duration(minutes: 15);
  static const _prefetchRemainingProfiles = 3;
  static const _maximumRetainedProfiles = 60;
  static const _retainedProfilesBehindFocus = 15;
  static const _maximumPhotoFutures = 20;

  late final DiscoverRepository _discovery;
  late final DiscoverLocationProvider _locationProvider;
  late final Future<bool> Function(String uid) _likeUser;
  late final Future<void> Function(String uid) _passUser;
  late final Future<List<VisibleProfilePhoto>> Function(String uid)?
      _profilePhotosLoader;
  final Set<String> _actingOn = {};
  final Set<String> _sessionUids = {};
  final Map<String, int> _sessionOrdinals = {};
  final Map<String, Future<List<VisibleProfilePhoto>>> _photoFutures = {};
  Future<void> _photoLoadTail = Future<void>.value();
  List<Map<String, dynamic>> _profiles = const [];
  String? _nextCursor;
  int _distanceMiles = defaultDiscoverDistanceMiles;
  int _sessionGeneration = 0;
  int _sessionDeliveredCount = 0;
  int _focusedIndex = 0;
  bool _initializing = true;
  bool _loadingInitialPage = false;
  bool _prefetching = false;
  bool _hasMore = false;
  bool _savingDistance = false;
  Object? _setupError;
  Object? _pageError;
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
    _profilePhotosLoader = widget.profileImageBuilder == null
        ? widget.profilePhotosLoader ?? ProfileMediaService().listVisiblePhotos
        : null;
    _initializeDiscover();
  }

  @override
  void dispose() {
    _sessionGeneration++;
    super.dispose();
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
        setState(() => _initializing = false);
        await _startFreshSession();
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
      () {
        final requestGeneration = _sessionGeneration;
        final request = _photoLoadTail.then(
          (_) => requestGeneration == _sessionGeneration
              ? _profilePhotosLoader!(uid)
              : Future.value(const <VisibleProfilePhoto>[]),
        );
        _photoLoadTail = request.then<void>(
          (_) {},
          onError: (Object _, StackTrace __) {},
        );
        return request;
      },
    );
  }

  void _primeProfilePhoto(Map<String, dynamic>? profile) {
    if (_profilePhotosLoader == null || profile == null) return;
    final uid = _profileUid(profile);
    if (uid == null) return;
    _photosFor(uid).ignore();
  }

  String? _profileUid(Map<String, dynamic> profile) {
    final uid = profile['uid']?.toString().trim() ?? '';
    return uid.isEmpty ? null : uid;
  }

  Future<void> _startFreshSession() async {
    if (!mounted || _locationProblem != null) return;
    final generation = ++_sessionGeneration;
    setState(() {
      _profiles = const [];
      _sessionUids.clear();
      _sessionOrdinals.clear();
      _photoFutures.clear();
      _nextCursor = null;
      _sessionDeliveredCount = 0;
      _focusedIndex = 0;
      _loadingInitialPage = true;
      _prefetching = false;
      _hasMore = false;
      _pageError = null;
      _setupError = null;
    });

    try {
      final page = await _discovery.loadCandidates(limit: discoverPageSize);
      if (!mounted || generation != _sessionGeneration) return;
      _primeProfilePhoto(page.profiles.firstOrNull);
      setState(() {
        _appendPage(page);
        _loadingInitialPage = false;
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover first page failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _loadingInitialPage = false;
        _pageError = error;
      });
    }
  }

  void _appendPage(DiscoverPage page) {
    final nextProfiles = List<Map<String, dynamic>>.of(_profiles);
    for (final profile in page.profiles) {
      final uid = _profileUid(profile);
      if (uid == null || !_sessionUids.add(uid)) continue;
      _sessionDeliveredCount++;
      _sessionOrdinals[uid] = _sessionDeliveredCount;
      nextProfiles.add(profile);
    }
    _nextCursor = page.nextCursor;
    _hasMore = page.hasMore && page.nextCursor != null;
    _profiles = nextProfiles;
    _trimRetainedFeed();
  }

  void _trimRetainedFeed() {
    final overflow = _profiles.length - _maximumRetainedProfiles;
    if (overflow <= 0) return;
    final safeToRemove = math.max(
      0,
      _focusedIndex - _retainedProfilesBehindFocus,
    );
    final removeCount = math.min(overflow, safeToRemove);
    if (removeCount <= 0) return;
    final removed = _profiles.take(removeCount).toList(growable: false);
    _profiles = _profiles.sublist(removeCount);
    _focusedIndex = math.max(0, _focusedIndex - removeCount);
    for (final profile in removed) {
      final uid = _profileUid(profile);
      if (uid != null) _photoFutures.remove(uid);
    }
  }

  Future<void> _prefetchNextPage() async {
    final cursor = _nextCursor;
    if (!mounted || _prefetching || !_hasMore || cursor == null) return;
    final generation = _sessionGeneration;
    setState(() {
      _prefetching = true;
      _pageError = null;
    });
    try {
      final page = await _discovery.loadCandidates(
        limit: discoverPageSize,
        cursor: cursor,
      );
      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _appendPage(page);
        _prefetching = false;
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover prefetch failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _prefetching = false;
        _pageError = error;
        if (error is DiscoverSessionExpiredException) {
          _hasMore = false;
          _nextCursor = null;
        }
      });
    }
  }

  void _focusChanged(int index) {
    if (!mounted || _profiles.isEmpty) return;
    final nextIndex = index.clamp(0, _profiles.length - 1);
    _primeProfilePhoto(_profiles[nextIndex]);
    if (_focusedIndex != nextIndex) {
      setState(() => _focusedIndex = nextIndex);
    }
    _prunePhotoFutures(nextIndex);
    if (_profiles.length - nextIndex - 1 <= _prefetchRemainingProfiles) {
      unawaited(_prefetchNextPage());
    }
  }

  void _prunePhotoFutures(int focusedIndex) {
    if (_photoFutures.length <= _maximumPhotoFutures) return;
    final retainedUids = <String>{};
    final start = math.max(0, focusedIndex - 7);
    final end = math.min(_profiles.length, focusedIndex + 11);
    for (var index = start; index < end; index++) {
      final uid = _profileUid(_profiles[index]);
      if (uid != null) retainedUids.add(uid);
    }
    _photoFutures.removeWhere((uid, _) => !retainedUids.contains(uid));
  }

  String _counterLabel(int index) {
    if (_profiles.isEmpty) return '0';
    final safeIndex = index.clamp(0, _profiles.length - 1);
    final uid = _profileUid(_profiles[safeIndex]);
    final ordinal =
        uid == null ? safeIndex + 1 : (_sessionOrdinals[uid] ?? safeIndex + 1);
    return '$ordinal / $_sessionDeliveredCount${_hasMore ? '+' : ''}';
  }

  String _counterSemantics(int index) {
    if (_profiles.isEmpty) return 'No profiles';
    final safeIndex = index.clamp(0, _profiles.length - 1);
    final uid = _profileUid(_profiles[safeIndex]);
    final ordinal =
        uid == null ? safeIndex + 1 : (_sessionOrdinals[uid] ?? safeIndex + 1);
    return _hasMore
        ? 'Profile $ordinal in this Discover session, more nearby profiles available'
        : 'Profile $ordinal in this Discover session';
  }

  void _reload() {
    if (!mounted || _locationProblem != null) return;
    unawaited(_startFreshSession());
  }

  Future<void> _refresh() async {
    final hasLocation = await _refreshLocation(force: false);
    if (!mounted || !hasLocation) return;
    await _startFreshSession();
  }

  void _removeProfile(String uid) {
    final index = _profiles.indexWhere(
      (profile) => _profileUid(profile) == uid,
    );
    if (index < 0) return;
    setState(() {
      final nextProfiles = List<Map<String, dynamic>>.of(_profiles)
        ..removeAt(index);
      _profiles = nextProfiles;
      _photoFutures.remove(uid);
      _focusedIndex =
          _profiles.isEmpty ? 0 : index.clamp(0, _profiles.length - 1);
    });
    if (_profiles.length - _focusedIndex - 1 <= _prefetchRemainingProfiles) {
      unawaited(_prefetchNextPage());
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
          content: Text(matched ? 'You connected 🎉' : 'Interest sent.'),
        ),
      );
      _removeProfile(uid);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover like failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send interest right now.')),
      );
    } finally {
      if (mounted) setState(() => _actingOn.remove(uid));
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
          content: Text('Passed. This profile will stay out of Discover.'),
        ),
      );
      _removeProfile(uid);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover pass failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that Pass right now.')),
      );
    } finally {
      if (mounted) setState(() => _actingOn.remove(uid));
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
      final uid = _profileUid(profile);
      if (uid != null) _removeProfile(uid);
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
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
      setState(() => _initializing = false);
      if (hasLocation) await _startFreshSession();
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
      builder: (context) => Theme(
        data: AppTheme.dark,
        child: _DiscoverDistanceSheet(selectedMiles: _distanceMiles),
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
      setState(() => _distanceMiles = distanceMiles);
      if (_locationProblem == null) await _startFreshSession();
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
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          FilledButton.tonalIcon(
            key: const ValueKey('discover-location-retry'),
            onPressed: _retryLocation,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
          if (servicesDisabled || permissionUnavailable)
            OutlinedButton.icon(
              key: const ValueKey('discover-location-settings'),
              onPressed: _openLocationSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open settings'),
            ),
        ],
      ),
    );
  }

  Widget _discoverContent() {
    if (_loadingInitialPage) {
      return const _DiscoverLoadingState();
    }

    final pageError = _pageError;
    if (_profiles.isEmpty && pageError != null) {
      if (pageError is DiscoverLocationRequiredException) {
        return _locationUnavailable(DiscoverLocationStatus.unavailable);
      }
      return _StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Discover is taking a break',
        text:
            'We could not load profiles. Check your connection and try again.',
        debugDetails: kDebugMode ? pageError.toString() : null,
        action: FilledButton.tonalIcon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      );
    }

    if (_profiles.isEmpty) {
      final nextDistance = nextDiscoverDistanceMiles(_distanceMiles);
      return _StateMessage(
        icon: Icons.travel_explore_rounded,
        title: 'No new worlds within $_distanceMiles miles.',
        text:
            'You’re caught up nearby. Refresh to check again, or choose a wider radius when you want to explore farther.',
        action: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey('discover-empty-refresh'),
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
            if (nextDistance != null)
              OutlinedButton.icon(
                key: const ValueKey('discover-increase-radius'),
                onPressed: () => _setDistance(nextDistance),
                icon: const Icon(Icons.radar_rounded),
                label: Text('Increase to $nextDistance mi'),
              ),
          ],
        ),
      );
    }

    final atEnd = !_hasMore && _focusedIndex >= _profiles.length - 1;
    final nextDistance = nextDiscoverDistanceMiles(_distanceMiles);
    return RefreshIndicator(
      color: AppTheme.accentBlue,
      backgroundColor: const Color(0xFF21122F),
      onRefresh: _refresh,
      child: ListView(
        key: const ValueKey('discover-world-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.xxs, 0, AppSpacing.xl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x45140C1D),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: const Color(0x664A2B61)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: DiscoveryOrbit(
                  profiles: _profiles,
                  imageBuilder: _profileImage,
                  onViewProfile: _viewProfile,
                  onLike: _like,
                  onPass: _pass,
                  isActing: (uid) => _actingOn.contains(uid),
                  onFocusChanged: _focusChanged,
                  onRequestMore: () => unawaited(_prefetchNextPage()),
                  hasMoreProfiles: _hasMore,
                  loadingMore: _prefetching,
                  counterLabelBuilder: _counterLabel,
                  counterSemanticsBuilder: _counterSemantics,
                ),
              ),
            ),
          ),
          if (_prefetching && _focusedIndex >= _profiles.length - 1)
            const Padding(
              key: ValueKey('discover-page-boundary-loading'),
              padding:
                  EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),
          if (pageError != null && !_prefetching && _hasMore)
            _DiscoverPagingMessage(
              key: const ValueKey('discover-page-retry'),
              icon: Icons.cloud_off_outlined,
              text: 'The next nearby worlds could not load yet.',
              actionLabel: 'Retry',
              onAction: () => unawaited(_prefetchNextPage()),
            ),
          if (atEnd)
            _DiscoverPagingMessage(
              key: const ValueKey('discover-end-of-results'),
              icon: Icons.auto_awesome_rounded,
              text: 'You’ve explored the nearby worlds available right now.',
              actionLabel: 'Refresh',
              onAction: _reload,
              secondaryLabel: nextDistance == null ? null : 'Increase radius',
              onSecondary: nextDistance == null
                  ? null
                  : () => _setDistance(nextDistance),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: _DiscoverWorld(
        onOpenSafetyCenter: _openSafetyCenter,
        distanceMiles: _distanceMiles,
        distanceBusy: _savingDistance,
        onChangeDistance: _showDistancePicker,
        child: _initializing
            ? const _DiscoverLoadingState()
            : _locationProblem != null
                ? _locationUnavailable(_locationProblem!)
                : _setupError != null
                    ? _StateMessage(
                        icon: Icons.cloud_off_outlined,
                        title: 'Discover is taking a break',
                        text:
                            'We could not prepare nearby Discover. Check your connection and try again.',
                        debugDetails:
                            kDebugMode ? _setupError.toString() : null,
                        action: FilledButton.tonalIcon(
                          onPressed: _retryLocation,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      )
                    : _discoverContent(),
      ),
    );
  }
}

class _DiscoverPagingMessage extends StatelessWidget {
  const _DiscoverPagingMessage({
    super.key,
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final semantic = PolycircleColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: semantic.surfaceRaised.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: semantic.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: AppTheme.accentBlue),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: semantic.textSecondary,
                      height: 1.35,
                    ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
            if (secondaryLabel != null && onSecondary != null)
              TextButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
          ],
        ),
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
    final theme = Theme.of(context);
    final semantic = PolycircleColors.of(context);
    return ColoredBox(
      key: const ValueKey('discover-cosmic-world'),
      color: const Color(0xFF05030B),
      child: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _DiscoverWorldPainter()),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.accentPink,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    'Explore your orbit',
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      color: semantic.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Move through the people whose worlds may cross yours.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: semantic.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Semantics(
                              button: true,
                              label:
                                  'Discovery radius, within $distanceMiles miles',
                              hint: 'Activate to change your nearby radius',
                              child: OutlinedButton.icon(
                                key: const ValueKey('discover-radius-control'),
                                onPressed:
                                    distanceBusy ? null : onChangeDistance,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: semantic.textPrimary,
                                  backgroundColor: semantic.surfaceRaised
                                      .withValues(alpha: 0.70),
                                  side:
                                      BorderSide(color: semantic.borderStrong),
                                  minimumSize: const Size(
                                    0,
                                    AppTheme.minimumTapTarget,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.xs,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                icon: distanceBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.location_on_outlined,
                                        size: 18,
                                      ),
                                label: Text('Within $distanceMiles mi'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      SizedBox.square(
                        dimension: AppTheme.minimumTapTarget,
                        child: IconButton(
                          key: const ValueKey('discover-safety-center'),
                          tooltip: 'Safety center',
                          onPressed: onOpenSafetyCenter,
                          style: IconButton.styleFrom(
                            foregroundColor: semantic.textPrimary,
                            backgroundColor:
                                semantic.surfaceRaised.withValues(alpha: 0.72),
                            side: BorderSide(color: semantic.border),
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
    final theme = Theme.of(context);
    final semantic = PolycircleColors.of(context);
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('discover-radius-sheet'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: semantic.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          border: Border(top: BorderSide(color: semantic.borderStrong)),
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
                  color: semantic.borderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Explore nearby',
              style: theme.textTheme.titleLarge?.copyWith(
                color: semantic.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Choose how far your Orbit reaches. It will never widen silently.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: semantic.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final miles in discoverDistanceOptionsMiles)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Semantics(
                  button: true,
                  selected: miles == selectedMiles,
                  label: '$miles mile Discover radius',
                  child: Material(
                    color: miles == selectedMiles
                        ? theme.colorScheme.primary.withValues(alpha: 0.16)
                        : semantic.surfaceRaised,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(
                        color: miles == selectedMiles
                            ? theme.colorScheme.primary
                            : semantic.border,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: ValueKey('discover-radius-$miles'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      textColor: semantic.textPrimary,
                      iconColor: theme.colorScheme.primary,
                      title: Text(
                        '$miles mi',
                        style: theme.textTheme.titleMedium,
                      ),
                      trailing: miles == selectedMiles
                          ? const Icon(Icons.check_circle_rounded)
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).pop(miles),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverLoadingState extends StatelessWidget {
  const _DiscoverLoadingState();

  @override
  Widget build(BuildContext context) {
    final semantic = PolycircleColors.of(context);
    return Semantics(
      label: 'Loading nearby profiles',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: semantic.border),
                      ),
                    ),
                    Container(
                      width: 142,
                      height: 142,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: semantic.border.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.brandPurple, AppTheme.accentPink],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x663DC7F3),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.public_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const Positioned(
                      top: 18,
                      right: 42,
                      child: _OrbitDot(color: AppTheme.accentBlue, size: 16),
                    ),
                    const Positioned(
                      bottom: 30,
                      left: 26,
                      child: _OrbitDot(color: AppTheme.accentGold, size: 13),
                    ),
                    const Positioned(
                      bottom: 18,
                      right: 55,
                      child: _OrbitDot(color: AppTheme.accentPink, size: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Finding nearby worlds…',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: semantic.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Matching your preferences while keeping precise location private.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: semantic.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbitDot extends StatelessWidget {
  const _OrbitDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.42),
            blurRadius: 12,
          ),
        ],
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
    final semantic = PolycircleColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: semantic.surfaceRaised.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: semantic.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.24),
                        AppTheme.accentBlue.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: semantic.border),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 34, color: AppTheme.accentBlue),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: semantic.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: semantic.textSecondary,
                    height: 1.45,
                  ),
                ),
                if (debugDetails != null && debugDetails!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(
                    debugDetails!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: semantic.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
