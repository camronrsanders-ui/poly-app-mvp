import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/connection_service.dart';
import '../../services/discovery_service.dart';
import '../../services/profile_media_service.dart';
import '../../widgets/discovery_orbit.dart';
import '../profile/profile_detail_screen.dart';

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
          return ColoredBox(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
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
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.secondaryContainer,
      child: Center(
        child: Icon(
          Icons.person,
          size: 30,
          color: colors.onSecondaryContainer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
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
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
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
    );
  }
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
            ),
            if (debugDetails != null && debugDetails!.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                debugDetails!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            action,
          ],
        ),
      ),
    );
  }
}
