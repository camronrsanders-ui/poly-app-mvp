import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/connection_service.dart';
import '../../services/discovery_service.dart';
import '../../services/profile_media_service.dart';
import '../../widgets/discovery_orbit.dart';
import '../profile/profile_detail_screen.dart';
import '../safety/safety_center_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _discovery = DiscoveryService();
  final _connections = ConnectionService();
  final _profileMedia = ProfileMediaService();

  late Future<List<Map<String, dynamic>>> _future;

  final Set<String> _actingOn = {};
  final Map<String, Future<List<VisibleProfilePhoto>>> _photoFutures = {};

  @override
  void initState() {
    super.initState();
    _future = _discovery.loadCandidates();
  }

  Future<List<VisibleProfilePhoto>> _photosFor(String uid) {
    if (uid.isEmpty) return Future.value(const <VisibleProfilePhoto>[]);

    return _photoFutures.putIfAbsent(
      uid,
      () => _profileMedia.listVisiblePhotos(uid),
    );
  }

  void _reload() {
    if (!mounted) return;

    setState(() {
      _photoFutures.clear();
      _future = _discovery.loadCandidates();
    });
  }

  Future<void> _refresh() async {
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
      final matched = await _connections.likeUser(uid);

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
      await _connections.passUser(uid);

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
          center: Alignment(-0.3, -0.35),
          colors: [
            Color(0xFF5B367B),
            Color(0xFF281536),
            Color(0xFF120B19),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 34,
          color: Color(0xFFE8D7F9),
        ),
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

  @override
  Widget build(BuildContext context) {
    return _DiscoverWorld(
      onOpenSafetyCenter: _openSafetyCenter,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFC596FF),
              ),
            );
          }

          if (snapshot.hasError) {
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
              debugDetails: kDebugMode ? snapshot.error?.toString() : null,
              action: TextButton(
                onPressed: _reload,
                child: const Text('Try again'),
              ),
            );
          }

          final profiles = snapshot.data ?? [];

          if (profiles.isEmpty) {
            return _StateMessage(
              icon: Icons.travel_explore,
              title: 'Your circle is still growing',
              text: 'No new profiles match the current discovery settings yet.',
              action: TextButton(
                onPressed: _reload,
                child: const Text('Refresh'),
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
                  onViewProfile: (profile) => _viewProfile(profile),
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
    required this.child,
  });

  final VoidCallback onOpenSafetyCenter;
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 10, 7),
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
