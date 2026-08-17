import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/firebase_runtime.dart';
import '../../services/connection_service.dart';
import '../../services/circle_membership_service.dart';
import '../../services/profile_media_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/polycircle_spatial_orbit.dart';
import '../profile/profile_detail_screen.dart';
import '../safety/safety_center_screen.dart';
import 'relationship_manager_screen.dart';

class MyCircleScreen extends StatefulWidget {
  const MyCircleScreen({super.key});

  @override
  State<MyCircleScreen> createState() => _MyCircleScreenState();
}

class _MyCircleScreenState extends State<MyCircleScreen>
    with SingleTickerProviderStateMixin {
  final _connections = ConnectionService();
  final _circleMembership = CircleMembershipService();
  final _profiles = ProfileService();
  final _media = ProfileMediaService();

  final _orbitController = PolycircleSpatialOrbitController();

  final Map<String, Future<List<VisibleProfilePhoto>>> _photoFutures = {};

  late Future<_UniverseModel> _future;
  late final AnimationController _worldTravel;

  String _activeWorldId = 'mine';
  String? _pendingWorldId;

  List<Map<String, dynamic>> _migratingPeople = const <Map<String, dynamic>>[];

  Map<String, Offset> _migrationStartPositions = const <String, Offset>{};

  Map<String, dynamic>? _focused;

  int _worldTravelDirection = 1;
  bool _worldTravelSwapped = false;
  bool _creatingCircle = false;
  bool _sendingCircleInvite = false;
  String? _respondingCircleInviteId;

  @override
  void initState() {
    super.initState();

    _worldTravel = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: 1,
    )..addListener(_handleWorldTravelFrame);

    _future = _load();
  }

  @override
  void dispose() {
    _worldTravel
      ..removeListener(_handleWorldTravelFrame)
      ..dispose();

    super.dispose();
  }

  void _handleWorldTravelFrame() {
    if (_pendingWorldId == null ||
        _worldTravelSwapped ||
        _worldTravel.value < .5) {
      return;
    }

    _worldTravelSwapped = true;

    setState(() {
      _activeWorldId = _pendingWorldId!;
      _focused = null;
    });

    HapticFeedback.selectionClick();
  }

  Future<void> _travelToWorld(
    _CircleWorld target,
    List<_CircleWorld> worlds,
  ) async {
    if (target.id == _activeWorldId || _pendingWorldId != null) {
      return;
    }

    final source = worlds.firstWhere(
      (world) => world.id == _activeWorldId,
      orElse: () => worlds.first,
    );

    final currentIndex = worlds.indexWhere(
      (world) => world.id == _activeWorldId,
    );

    final targetIndex = worlds.indexWhere(
      (world) => world.id == target.id,
    );

    final targetIds =
        target.people.map(_uidOf).where((id) => id.isNotEmpty).toSet();

    final sharedCandidates = source.people
        .where(
          (person) => targetIds.contains(
            _uidOf(person),
          ),
        )
        .toList();

    final focusedId = _focused == null ? '' : _uidOf(_focused!);

    sharedCandidates.sort(
      (a, b) {
        final aFocused = _uidOf(a) == focusedId;
        final bFocused = _uidOf(b) == focusedId;

        if (aFocused == bFocused) return 0;

        return aFocused ? -1 : 1;
      },
    );

    // Keep this visually special without making the
    // camera transition heavier than necessary.
    final migrating = sharedCandidates.take(3).toList(growable: false);

    final currentPositions = _orbitController.normalizedPositions;

    final startPositions = <String, Offset>{};

    for (final person in migrating) {
      final id = _uidOf(person);
      final position = currentPositions[id];

      if (id.isNotEmpty && position != null) {
        startPositions[id] = position;
      }
    }

    _worldTravelDirection = targetIndex >= currentIndex ? 1 : -1;

    setState(() {
      _pendingWorldId = target.id;
      _worldTravelSwapped = false;

      _migratingPeople = migrating;
      _migrationStartPositions = startPositions;
    });

    HapticFeedback.lightImpact();

    await _worldTravel.forward(from: 0);

    if (!mounted) return;

    setState(() {
      _pendingWorldId = null;
      _worldTravelSwapped = false;

      _migratingPeople = const <Map<String, dynamic>>[];

      _migrationStartPositions = const <String, Offset>{};
    });
  }

  Future<_UniverseModel> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('No signed-in user.');
    }

    final results = await Future.wait<Object?>([
      _connections.loadConnections(),
      _profiles.getProfile(uid),
      _circleMembership.listMyCircles(),
    ]);

    final circleSnapshot = results[2] as CircleMembershipSnapshot;

    return _UniverseModel(
      uid: uid,
      profile: results[1] as Map<String, dynamic>? ?? const <String, dynamic>{},
      connections: results[0] as List<Map<String, dynamic>>,
      circles: circleSnapshot.circles,
      invites: circleSnapshot.invites,
    );
  }

  Future<List<VisibleProfilePhoto>> _photosFor(
    String uid,
  ) {
    if (uid.isEmpty) {
      return Future.value(
        const <VisibleProfilePhoto>[],
      );
    }

    return _photoFutures.putIfAbsent(
      uid,
      () => _media.listVisiblePhotos(uid),
    );
  }

  void _reload() {
    setState(() {
      _focused = null;
      _photoFutures.clear();
      _future = _load();
    });
  }

  Future<void> _createCircle() async {
    if (_creatingCircle) return;

    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateCircleSheet(),
    );

    if (!mounted || name == null || name.trim().isEmpty) {
      return;
    }

    setState(() {
      _creatingCircle = true;
    });

    try {
      final created = await _circleMembership.createCircle(
        name,
      );

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      setState(() {
        _creatingCircle = false;
        _activeWorldId = 'circle:${created.circleId}';
        _focused = null;
        _photoFutures.clear();
        _future = _load();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${created.name} is now part of your universe.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Circle creation failed: $error',
        );
        debugPrintStack(
          stackTrace: stackTrace,
        );
      }

      if (!mounted) return;

      setState(() {
        _creatingCircle = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not create that Circle. '
            'Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _inviteToCircle({
    required CircleSummary circle,
    required List<Map<String, dynamic>> connections,
  }) async {
    if (_sendingCircleInvite) return;

    final person = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteCircleMemberSheet(
        circleName: circle.name,
        connections: connections,
      ),
    );

    if (!mounted || person == null) return;

    final inviteeUid = person['uid']?.toString().trim() ?? '';

    if (inviteeUid.isEmpty) return;

    final displayName = _name(person);

    setState(() {
      _sendingCircleInvite = true;
    });

    try {
      await _circleMembership.inviteMember(
        circleId: circle.circleId,
        inviteeUid: inviteeUid,
      );

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      setState(() {
        _sendingCircleInvite = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invitation sent to $displayName. '
            'They will not appear in ${circle.name} '
            'until they accept.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Circle invitation failed: $error',
        );
        debugPrintStack(
          stackTrace: stackTrace,
        );
      }

      if (!mounted) return;

      setState(() {
        _sendingCircleInvite = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send that Circle invitation. '
            'Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _respondToCircleInvitation({
    required CircleInviteSummary invite,
    required bool accept,
  }) async {
    if (_respondingCircleInviteId != null) {
      return;
    }

    setState(() {
      _respondingCircleInviteId = invite.inviteId;
    });

    try {
      final accepted = await _circleMembership.respondToInvite(
        inviteId: invite.inviteId,
        accept: accept,
      );

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      setState(() {
        _respondingCircleInviteId = null;

        if (accepted) {
          _activeWorldId = 'circle:${invite.circleId}';
        }

        _focused = null;
        _photoFutures.clear();
        _future = _load();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'Welcome to ${invite.circleName}.'
                : 'Circle invitation declined.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Circle invitation response failed: $error',
        );
        debugPrintStack(
          stackTrace: stackTrace,
        );
      }

      if (!mounted) return;

      setState(() {
        _respondingCircleInviteId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update that Circle invitation.',
          ),
        ),
      );
    }
  }

  Future<void> _openCircleInvitations(
    _UniverseModel model,
  ) async {
    if (model.invites.isEmpty) return;

    final decision = await showModalBottomSheet<_CircleInviteDecision>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IncomingCircleInvitesSheet(
        invites: model.invites,
        connections: model.connections,
      ),
    );

    if (!mounted || decision == null) {
      return;
    }

    await _respondToCircleInvitation(
      invite: decision.invite,
      accept: decision.accept,
    );
  }

  Future<void> _openSafety() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SafetyCenterScreen(),
      ),
    );
  }

  Future<void> _openManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Manage My Circle'),
          ),
          body: const RelationshipManagerScreen(),
        ),
      ),
    );
  }

  Future<void> _openProfile(
    Map<String, dynamic> person,
  ) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(
          profile: person,
          showConnectAction: false,
        ),
      ),
    );

    if (!mounted) return;

    if (result == 'blocked') {
      _reload();
    }
  }

  List<_CircleWorld> _worlds(
    _UniverseModel model,
  ) {
    final people = model.connections;

    final connectionsByUid = <String, Map<String, dynamic>>{
      for (final person in people)
        if (_uidOf(person).isNotEmpty) _uidOf(person): person,
    };

    final worlds = <_CircleWorld>[
      _CircleWorld(
        id: 'mine',
        name: 'My Circle',
        subtitle: 'Your relationship universe',
        icon: Icons.blur_circular_rounded,
        people: people,
      ),
    ];

    for (final circle in model.circles) {
      final circlePeople = circle.members.map(
        (member) {
          final uid = _uidOf(member);

          final connection = connectionsByUid[uid];

          // If this Circle member is
          // already one of YOUR active
          // connections, reuse the richer
          // profile view you already have.
          //
          // Otherwise keep only the
          // minimal Circle identity sent
          // by the membership backend.
          if (connection == null) {
            return member;
          }

          return <String, dynamic>{
            ...member,
            ...connection,
          };
        },
      ).toList(
        growable: false,
      );

      worlds.add(
        _CircleWorld(
          id: 'circle:${circle.circleId}',
          name: circle.name,
          subtitle: circle.isOwner
              ? 'Private Circle • You created this'
              : 'Shared Circle',
          icon: Icons.bubble_chart_rounded,
          memberCount: circle.memberCount,
          people: circlePeople,
        ),
      );
    }

    // Shared Worlds are being visually prototyped against
    // local synthetic fixtures only. Production gets the
    // consent-backed circles collection in the next backend phase.
    if (kDebugMode && useFirebaseEmulators && people.length >= 4) {
      worlds.add(
        _CircleWorld(
          id: 'house',
          name: 'House',
          subtitle: 'Shared Circle preview',
          icon: Icons.home_rounded,
          people: people.take(4).toList(growable: false),
        ),
      );

      worlds.add(
        _CircleWorld(
          id: 'chosen',
          name: 'Chosen Family',
          subtitle: 'Shared Circle preview',
          icon: Icons.favorite_rounded,
          people: people.length <= 5
              ? people
              : people.skip(1).take(5).toList(growable: false),
        ),
      );
    }

    return worlds;
  }

  List<PolycircleTopologyLink> _visibleTopologyFor(
    _CircleWorld world,
  ) {
    if (!(kDebugMode && useFirebaseEmulators)) {
      return const <PolycircleTopologyLink>[];
    }

    final ids = world.people
        .map(_uidOf)
        .where(
          (id) => id.isNotEmpty,
        )
        .toList(growable: false);

    if (ids.length < 2) {
      return const <PolycircleTopologyLink>[];
    }

    final links = <PolycircleTopologyLink>[
      PolycircleTopologyLink(
        fromId: '__owner__',
        toId: ids[0],
        label: 'Partner',
      ),
      PolycircleTopologyLink(
        fromId: ids[0],
        toId: ids[1],
        label: 'Metamour',
      ),
    ];

    if (ids.length >= 3) {
      links.add(
        PolycircleTopologyLink(
          fromId: '__owner__',
          toId: ids[2],
          label: 'Important connection',
        ),
      );
    }

    if (ids.length >= 4) {
      links.add(
        PolycircleTopologyLink(
          fromId: ids[1],
          toId: ids[3],
          label: world.id == 'house' ? 'Household' : 'Chosen family',
        ),
      );
    }

    if (world.id == 'chosen' && ids.length >= 5) {
      links.add(
        PolycircleTopologyLink(
          fromId: ids[2],
          toId: ids[4],
          label: 'Chosen family',
        ),
      );
    }

    return links;
  }

  String _uidOf(
    Map<String, dynamic> person,
  ) {
    return person['uid']?.toString() ?? '';
  }

  String _name(
    Map<String, dynamic> person,
  ) {
    final value = person['displayName']?.toString().trim() ?? '';

    return value.isEmpty ? 'Connection' : value;
  }

  String _relationship(
    Map<String, dynamic> person,
  ) {
    return [
      person['relationshipStructure'],
      person['relationshipStatus'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • ');
  }

  String _location(
    Map<String, dynamic> person,
  ) {
    return [
      person['city'],
      person['region'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
  }

  Widget _personPhoto(
    Map<String, dynamic> person,
  ) {
    final uid = person['uid']?.toString() ?? '';

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
            errorBuilder: (_, __, ___) => _personFallback(person),
          );
        }

        return _personFallback(person);
      },
    );
  }

  Widget _personFallback(
    Map<String, dynamic> person,
  ) {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.secondaryContainer,
      child: Center(
        child: Text(
          _name(person).characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_UniverseModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SpatialLoading();
        }

        if (snapshot.hasError || snapshot.data == null) {
          if (kDebugMode && snapshot.hasError) {
            debugPrint(
              'My Circle load failed: ${snapshot.error}',
            );
          }

          return _UniverseError(
            onRetry: _reload,
          );
        }

        return _buildUniverse(
          snapshot.data!,
        );
      },
    );
  }

  Widget _buildUniverse(
    _UniverseModel model,
  ) {
    final worlds = _worlds(model);

    var active = worlds.first;

    for (final world in worlds) {
      if (world.id == _activeWorldId) {
        active = world;
        break;
      }
    }

    if (active.people.isEmpty) {
      if (active.id == 'mine') {
        return _EmptyUniverse(
          displayName: model.profile['displayName']?.toString() ?? '',
          photoFuture: _photosFor(model.uid),
          onManage: _openManager,
          onSafety: _openSafety,
        );
      }

      return _buildEmptyCircleUniverse(
        model: model,
        worlds: worlds,
        active: active,
      );
    }

    final selected = _focused != null &&
            active.people.any(
              (person) => person['uid'] == _focused?['uid'],
            )
        ? _focused!
        : active.people.first;

    final topologyLinks = _visibleTopologyFor(active);

    final migratingIds = _pendingWorldId == null
        ? const <String>{}
        : _migratingPeople
            .map(_uidOf)
            .where(
              (id) => id.isNotEmpty,
            )
            .toSet();

    return Stack(
      children: [
        const Positioned.fill(
          child: _SpatialBackground(),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _SpatialHeader(
                world: active,
                count: active.memberCount ?? active.people.length,
                onSafety: _openSafety,
                onManage: _openManager,
              ),
              _WorldDock(
                worlds: worlds,
                activeWorldId: active.id,
                onSelect: (world) => _travelToWorld(
                  world,
                  worlds,
                ),
                onCreate: _createCircle,
              ),
              if (model.invites.isNotEmpty)
                _CircleInvitationNotice(
                  count: model.invites.length,
                  onTap: () => _openCircleInvitations(
                    model,
                  ),
                ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    _WorldCameraTravel(
                      animation: _worldTravel,
                      direction: _worldTravelDirection,
                      child: Center(
                        key: ValueKey(
                          active.id,
                        ),
                        child: PolycircleSpatialOrbit<Map<String, dynamic>>(
                          controller: _orbitController,
                          hiddenItemIds: migratingIds,
                          topologyLinks: topologyLinks,
                          items: active.people,
                          itemId: _uidOf,
                          labelBuilder: _name,
                          avatarBuilder: (
                            context,
                            person,
                            focused,
                          ) =>
                              _personPhoto(
                            person,
                          ),
                          onFocused: (person) {
                            setState(() {
                              _focused = person;
                            });
                          },
                          onOpen: _openProfile,
                          height: 430,
                          centerBuilder: (_) => _OwnerWorld(
                            displayName:
                                model.profile['displayName']?.toString() ?? '',
                            photoFuture: _photosFor(
                              model.uid,
                            ),
                            worldName: active.name,
                          ),
                        ),
                      ),
                    ),
                    if (_pendingWorldId != null && _migratingPeople.isNotEmpty)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _SharedMemberMigrationLayer(
                            animation: _worldTravel,
                            direction: _worldTravelDirection,
                            people: _migratingPeople,
                            startPositions: _migrationStartPositions,
                            orbitController: _orbitController,
                            avatarBuilder: _personPhoto,
                            labelBuilder: _name,
                            orbitHeight: 430,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _FocusedPersonGlass(
                person: selected,
                relationship: _relationship(selected),
                location: _location(selected),
                onOpen: () => _openProfile(selected),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCircleUniverse({
    required _UniverseModel model,
    required List<_CircleWorld> worlds,
    required _CircleWorld active,
  }) {
    final activeCircleId = active.id.startsWith('circle:')
        ? active.id.substring(
            'circle:'.length,
          )
        : '';

    final activeCircleIsOwner = model.circles.any(
      (circle) => circle.circleId == activeCircleId && circle.isOwner,
    );

    return Stack(
      children: [
        const Positioned.fill(
          child: _SpatialBackground(),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _SpatialHeader(
                world: active,
                count: active.memberCount ?? active.people.length,
                onSafety: _openSafety,
                onManage: _openManager,
              ),
              _WorldDock(
                worlds: worlds,
                activeWorldId: active.id,
                onSelect: (world) => _travelToWorld(
                  world,
                  worlds,
                ),
                onCreate: _createCircle,
              ),
              if (model.invites.isNotEmpty)
                _CircleInvitationNotice(
                  count: model.invites.length,
                  onTap: () => _openCircleInvitations(
                    model,
                  ),
                ),
              Expanded(
                child: _EmptyCircleStage(
                  name: active.name,
                  displayName: model.profile['displayName']?.toString() ?? '',
                  onInvite: activeCircleIsOwner
                      ? () {
                          CircleSummary? circle;

                          final circleId = active.id.startsWith(
                            'circle:',
                          )
                              ? active.id.substring(
                                  'circle:'.length,
                                )
                              : '';

                          for (final candidate in model.circles) {
                            if (candidate.circleId == circleId) {
                              circle = candidate;
                              break;
                            }
                          }

                          if (circle == null || !circle.isOwner) {
                            return;
                          }

                          _inviteToCircle(
                            circle: circle,
                            connections: model.connections,
                          );
                        }
                      : null,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreateCircleSheet extends StatefulWidget {
  const _CreateCircleSheet();

  @override
  State<_CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends State<_CreateCircleSheet> {
  final _controller = TextEditingController();

  String get _name => _controller.text.trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.isEmpty) return;

    Navigator.of(context).pop(
      _name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(
                    999,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primaryContainer,
                    colors.secondaryContainer,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 24,
                    spreadRadius: 2,
                    color: colors.primary.withAlpha(35),
                  ),
                ],
              ),
              child: Icon(
                Icons.bubble_chart_rounded,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Create a new world',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Give this Circle a name. '
              'It starts private — nobody joins '
              'until they accept your invitation.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Circle name',
                hintText: 'House, Chosen Family, Boston Crew…',
                prefixIcon: Icon(
                  Icons.blur_on_rounded,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(
                  18,
                ),
                border: Border.all(
                  color: colors.outlineVariant,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 20,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Circle membership and '
                      'relationship labels use '
                      'separate consent controls.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _name.isEmpty ? null : _submit,
                icon: const Icon(
                  Icons.add_circle_outline,
                ),
                label: const Text(
                  'Create Circle',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCircleStage extends StatelessWidget {
  const _EmptyCircleStage({
    required this.name,
    required this.displayName,
    this.onInvite,
  });

  final String name;
  final String displayName;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final initial = displayName.trim().isEmpty
        ? 'YOU'
        : displayName.trim().characters.first.toUpperCase();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 190,
                  height: 90,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colors.primary.withAlpha(38),
                      width: 1.3,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.primaryContainer,
                        colors.secondaryContainer,
                      ],
                    ),
                    border: Border.all(
                      color: colors.primary,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 30,
                        spreadRadius: 3,
                        color: colors.primary.withAlpha(38),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          initial,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colors.onPrimaryContainer,
                              ),
                        ),
                        Text(
                          'YOU',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: colors.onPrimaryContainer,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Just you for now',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This Circle is private. '
              'People appear here only after '
              'they accept an invitation.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            if (onInvite != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onInvite,
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                ),
                label: const Text(
                  'Invite people',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InviteCircleMemberSheet extends StatelessWidget {
  const _InviteCircleMemberSheet({
    required this.circleName,
    required this.connections,
  });

  final String circleName;
  final List<Map<String, dynamic>> connections;

  String _name(
    Map<String, dynamic> person,
  ) {
    final value = person['displayName']?.toString().trim() ?? '';

    return value.isEmpty ? 'Connection' : value;
  }

  String _detail(
    Map<String, dynamic> person,
  ) {
    final relationship = [
      person['relationshipStructure'],
      person['relationshipStatus'],
    ]
        .whereType<String>()
        .where(
          (value) => value.trim().isNotEmpty,
        )
        .join(' • ');

    final location = [
      person['city'],
      person['region'],
    ]
        .whereType<String>()
        .where(
          (value) => value.trim().isNotEmpty,
        )
        .join(', ');

    return [
      relationship,
      location,
    ]
        .where(
          (value) => value.isNotEmpty,
        )
        .join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .48,
        maxChildSize: .92,
        builder: (
          context,
          scrollController,
        ) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(
                    999,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  22,
                  22,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primaryContainer,
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(
                          width: 14,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invite into $circleName',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                'Choose an existing connection.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(
                        13,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 19,
                            color: colors.primary,
                          ),
                          const SizedBox(
                            width: 9,
                          ),
                          Expanded(
                            child: Text(
                              'Sending an invitation does not add them. '
                              'They become a member only after accepting.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: connections.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            28,
                          ),
                          child: Text(
                            'You need an active connection '
                            'before inviting someone into a Circle.',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          28,
                        ),
                        itemCount: connections.length,
                        separatorBuilder: (_, __) => const SizedBox(
                          height: 4,
                        ),
                        itemBuilder: (context, index) {
                          final person = connections[index];

                          final name = _name(person);

                          final detail = _detail(person);

                          return Card(
                            elevation: 0,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              leading: CircleAvatar(
                                child: Text(
                                  name.characters.first.toUpperCase(),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: detail.isEmpty
                                  ? null
                                  : Text(
                                      detail,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: const Icon(
                                Icons.arrow_forward_rounded,
                              ),
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pop(
                                  person,
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CircleInvitationNotice extends StatelessWidget {
  const _CircleInvitationNotice({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        8,
      ),
      child: Material(
        color: colors.secondaryContainer.withAlpha(170),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mark_email_unread_rounded,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    count == 1
                        ? '1 Circle invitation'
                        : '$count Circle invitations',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleInviteDecision {
  const _CircleInviteDecision({
    required this.invite,
    required this.accept,
  });

  final CircleInviteSummary invite;
  final bool accept;
}

class _IncomingCircleInvitesSheet extends StatelessWidget {
  const _IncomingCircleInvitesSheet({
    required this.invites,
    required this.connections,
  });

  final List<CircleInviteSummary> invites;
  final List<Map<String, dynamic>> connections;

  String _inviterName(
    CircleInviteSummary invite,
  ) {
    for (final person in connections) {
      if (person['uid']?.toString() == invite.inviterUid) {
        final name = person['displayName']?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          return name;
        }
      }
    }

    return 'A connection';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .66,
        minChildSize: .44,
        maxChildSize: .90,
        builder: (
          context,
          scrollController,
        ) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(
                    999,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  22,
                  22,
                  14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primaryContainer,
                      ),
                      child: Icon(
                        Icons.hub_outlined,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Circle invitations',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            'You choose which worlds become part of yours.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(
                    14,
                  ),
                  itemCount: invites.length,
                  separatorBuilder: (_, __) => const SizedBox(
                    height: 10,
                  ),
                  itemBuilder: (context, index) {
                    final invite = invites[index];

                    final inviter = _inviterName(
                      invite,
                    );

                    return Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    invite.circleName.characters.first
                                        .toUpperCase(),
                                  ),
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                Expanded(
                                  child: Text(
                                    invite.circleName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            Text(
                              '$inviter invited you '
                              'to join this Circle.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Text(
                              'Joining only adds you to '
                              'the Circle. Relationship '
                              'labels remain separately '
                              'controlled.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(
                              height: 18,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(
                                      context,
                                    ).pop(
                                      _CircleInviteDecision(
                                        invite: invite,
                                        accept: false,
                                      ),
                                    ),
                                    child: const Text(
                                      'Decline',
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => Navigator.of(
                                      context,
                                    ).pop(
                                      _CircleInviteDecision(
                                        invite: invite,
                                        accept: true,
                                      ),
                                    ),
                                    child: const Text(
                                      'Accept',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UniverseModel {
  const _UniverseModel({
    required this.uid,
    required this.profile,
    required this.connections,
    required this.circles,
    required this.invites,
  });

  final String uid;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> connections;
  final List<CircleSummary> circles;
  final List<CircleInviteSummary> invites;
}

class _CircleWorld {
  const _CircleWorld({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.people,
    this.memberCount,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final List<Map<String, dynamic>> people;
  final int? memberCount;
}

class _WorldCameraTravel extends StatelessWidget {
  const _WorldCameraTravel({
    required this.animation,
    required this.direction,
    required this.child,
  });

  final Animation<double> animation;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,

      // Keep the expensive spatial scene isolated while
      // only its transform changes frame-to-frame.
      child: RepaintBoundary(
        child: child,
      ),

      builder: (context, child) {
        final raw = animation.value.clamp(0.0, 1.0).toDouble();

        late final double x;
        late final double y;
        late final double z;
        late final double scale;
        late final double rotationY;

        if (raw < .5) {
          final phase = (raw / .5).clamp(0.0, 1.0).toDouble();

          final movement = Curves.easeInCubic.transform(phase);

          // Current universe retreats into space.
          x = -direction * 42 * movement;
          y = -10 * movement;
          z = -340 * movement;

          rotationY = direction * .14 * movement;

          scale = 1 - (.66 * movement);
        } else {
          final phase = ((raw - .5) / .5).clamp(0.0, 1.0).toDouble();

          final movement = Curves.easeOutCubic.transform(phase);

          // A tiny physical settle on arrival.
          final spatialOvershoot = Curves.easeOutBack.transform(phase);

          // New universe travels back toward camera.
          x = direction * 48 * (1 - movement);
          y = 12 * (1 - movement);
          z = -340 * (1 - movement);

          rotationY = -direction * .16 * (1 - movement);

          scale = .34 + (.66 * spatialOvershoot);
        }

        final matrix = Matrix4.identity()
          ..setEntry(
            3,
            2,
            -.0011,
          )
          ..translateByDouble(
            x,
            y,
            z,
            1,
          )
          ..rotateY(rotationY)
          ..scaleByDouble(
            scale,
            scale,
            1,
            1,
          );

        return IgnorePointer(
          ignoring: animation.value < 1,
          child: Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: child,
          ),
        );
      },
    );
  }
}

class _SharedMemberMigrationLayer extends StatelessWidget {
  const _SharedMemberMigrationLayer({
    required this.animation,
    required this.direction,
    required this.people,
    required this.startPositions,
    required this.orbitController,
    required this.avatarBuilder,
    required this.labelBuilder,
    required this.orbitHeight,
  });

  final Animation<double> animation;
  final int direction;

  final List<Map<String, dynamic>> people;

  final Map<String, Offset> startPositions;

  final PolycircleSpatialOrbitController orbitController;

  final Widget Function(
    Map<String, dynamic> person,
  ) avatarBuilder;

  final String Function(
    Map<String, dynamic> person,
  ) labelBuilder;

  final double orbitHeight;

  Offset _resolve(
    Offset normalized,
    double width,
    double orbitTop,
  ) {
    return Offset(
      normalized.dx * width,
      orbitTop + normalized.dy * orbitHeight,
    );
  }

  Offset _quadratic(
    Offset start,
    Offset control,
    Offset end,
    double t,
  ) {
    final inverse = 1 - t;

    return Offset(
      inverse * inverse * start.dx +
          2 * inverse * t * control.dx +
          t * t * end.dx,
      inverse * inverse * start.dy +
          2 * inverse * t * control.dy +
          t * t * end.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final width = constraints.maxWidth;

        final height = constraints.maxHeight;

        final orbitTop = ((height - orbitHeight) / 2)
            .clamp(
              0.0,
              height,
            )
            .toDouble();

        return AnimatedBuilder(
          animation: animation,
          builder: (
            context,
            child,
          ) {
            final raw = animation.value.clamp(0.0, 1.0).toDouble();

            final targetPositions = orbitController.normalizedPositions;

            final middleStrength =
                (1 - ((raw - .5).abs() * 2)).clamp(0.0, 1.0).toDouble();

            final nodeScale = 1 +
                (.10 *
                    Curves.easeOutCubic.transform(
                      middleStrength,
                    ));

            final children = <Widget>[];

            for (var index = 0; index < people.length; index++) {
              final person = people[index];

              final id = person['uid']?.toString() ?? '';

              if (id.isEmpty) {
                continue;
              }

              final startNormalized = startPositions[id] ??
                  const Offset(
                    .5,
                    .43,
                  );

              final targetNormalized = targetPositions[id] ??
                  const Offset(
                    .5,
                    .43,
                  );

              final start = _resolve(
                startNormalized,
                width,
                orbitTop,
              );

              final target = _resolve(
                targetNormalized,
                width,
                orbitTop,
              );

              final lane = (index - ((people.length - 1) / 2)) * 52.0;

              final bridge = Offset(
                (width / 2) + lane,
                orbitTop + orbitHeight * .26,
              );

              late final Offset position;

              if (raw < .5) {
                final phase = Curves.easeInOutCubic.transform(
                  (raw / .5)
                      .clamp(
                        0.0,
                        1.0,
                      )
                      .toDouble(),
                );

                final highestY = start.dy < bridge.dy ? start.dy : bridge.dy;

                final control = Offset(
                  (start.dx + bridge.dx) / 2,
                  highestY - 22,
                );

                position = _quadratic(
                  start,
                  control,
                  bridge,
                  phase,
                );
              } else {
                final phase = Curves.easeInOutCubic.transform(
                  ((raw - .5) / .5)
                      .clamp(
                        0.0,
                        1.0,
                      )
                      .toDouble(),
                );

                final highestY = bridge.dy < target.dy ? bridge.dy : target.dy;

                final control = Offset(
                  (bridge.dx + target.dx) / 2,
                  highestY - 22,
                );

                position = _quadratic(
                  bridge,
                  control,
                  target,
                  phase,
                );
              }

              final firstHalf = (raw / .5)
                  .clamp(
                    0.0,
                    1.0,
                  )
                  .toDouble();

              final secondHalf = ((raw - .5) / .5)
                  .clamp(
                    0.0,
                    1.0,
                  )
                  .toDouble();

              final rotation = raw < .5
                  ? direction * -.055 * firstHalf
                  : direction * .055 * (1 - secondHalf);

              const size = 54.0;

              children.add(
                Positioned(
                  left: position.dx - size / 2,
                  top: position.dy - size / 2,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: nodeScale,
                      child: RepaintBoundary(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: size,
                              height: size,
                              padding: const EdgeInsets.all(
                                2.5,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    colors.secondaryContainer,
                                    colors.primary,
                                  ],
                                ),
                                border: Border.all(
                                  color: colors.primary,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withAlpha(
                                      82,
                                    ),
                                    blurRadius: 22 + (middleStrength * 14),
                                    spreadRadius: 2 + (middleStrength * 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: avatarBuilder(
                                  person,
                                ),
                              ),
                            ),
                            if (raw > .16 && raw < .84) ...[
                              const SizedBox(
                                height: 5,
                              ),
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 96,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surface.withAlpha(
                                    236,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    999,
                                  ),
                                  border: Border.all(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  labelBuilder(
                                    person,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Stack(
              clipBehavior: Clip.none,
              children: children,
            );
          },
        );
      },
    );
  }
}

class _SpatialHeader extends StatelessWidget {
  const _SpatialHeader({
    required this.world,
    required this.count,
    required this.onSafety,
    required this.onManage,
  });

  final _CircleWorld world;
  final int count;
  final VoidCallback onSafety;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  world.id == 'mine' ? 'MY CIRCLE' : world.name.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  world.subtitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Safety center',
            onPressed: onSafety,
            icon: const Icon(
              Icons.shield_outlined,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Circle options',
            onSelected: (value) {
              if (value == 'manage') {
                onManage();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded),
                    SizedBox(width: 10),
                    Text('Manage relationships'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorldDock extends StatelessWidget {
  const _WorldDock({
    required this.worlds,
    required this.activeWorldId,
    required this.onSelect,
    required this.onCreate,
  });

  final List<_CircleWorld> worlds;
  final String activeWorldId;
  final ValueChanged<_CircleWorld> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 102,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 14,
                right: 6,
              ),
              children: [
                for (final world in worlds)
                  Padding(
                    padding: const EdgeInsets.only(
                      right: 9,
                    ),
                    child: _WorldButton(
                      world: world,
                      selected: world.id == activeWorldId,
                      onTap: () => onSelect(world),
                    ),
                  ),
              ],
            ),
          ),

          // Creating a Circle is a primary action,
          // so it never disappears into horizontal
          // world scrolling.
          Container(
            padding: const EdgeInsets.only(
              left: 4,
              right: 10,
            ),
            decoration: BoxDecoration(
              color: colors.surface.withAlpha(
                246,
              ),
              border: Border(
                left: BorderSide(
                  color: colors.outlineVariant.withAlpha(90),
                ),
              ),
            ),
            child: _CreateWorldButton(
              onTap: onCreate,
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldButton extends StatelessWidget {
  const _WorldButton({
    required this.world,
    required this.selected,
    required this.onTap,
  });

  final _CircleWorld world;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: selected ? 104 : 92,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: selected ? 58 : 48,
              height: selected ? 58 : 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: selected
                      ? [
                          Colors.white,
                          colors.secondaryContainer,
                          colors.primary,
                        ]
                      : [
                          colors.surface,
                          colors.primaryContainer,
                        ],
                ),
                border: Border.all(
                  color: selected ? colors.primary : colors.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: colors.primary.withAlpha(55),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                world.icon,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              world.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateWorldButton extends StatelessWidget {
  const _CreateWorldButton({
    required this.onTap,
    required this.colors,
  });

  final VoidCallback onTap;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface.withAlpha(210),
                border: Border.all(
                  color: colors.outlineVariant,
                ),
              ),
              child: const Icon(Icons.add_rounded),
            ),
            const SizedBox(height: 5),
            Text(
              'New',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerWorld extends StatelessWidget {
  const _OwnerWorld({
    required this.displayName,
    required this.photoFuture,
    required this.worldName,
  });

  final String displayName;
  final Future<List<VisibleProfilePhoto>> photoFuture;
  final String worldName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors.primary.withAlpha(70),
                colors.secondary.withAlpha(25),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          width: 91,
          height: 91,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                colors.secondaryContainer,
                colors.primary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withAlpha(75),
                blurRadius: 32,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipOval(
            child: FutureBuilder<List<VisibleProfilePhoto>>(
              future: photoFuture,
              builder: (context, snapshot) {
                final photos = snapshot.data ?? const <VisibleProfilePhoto>[];

                if (photos.isNotEmpty) {
                  return Image.network(
                    photos.first.url.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(context),
                  );
                }

                return _fallback(context);
              },
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colors.primary.withAlpha(70),
              ),
            ),
            child: Text(
              'YOU',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback(
    BuildContext context,
  ) {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: displayName.trim().isEmpty
            ? Icon(
                Icons.person_rounded,
                color: colors.onPrimaryContainer,
              )
            : Text(
                displayName.characters.first.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.onPrimaryContainer,
                    ),
              ),
      ),
    );
  }
}

class _FocusedPersonGlass extends StatelessWidget {
  const _FocusedPersonGlass({
    required this.person,
    required this.relationship,
    required this.location,
    required this.onOpen,
  });

  final Map<String, dynamic> person;
  final String relationship;
  final String location;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final name = person['displayName']?.toString() ?? 'Connection';

    final age = person['age'];

    final headline = person['headline']?.toString().trim() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 20,
            sigmaY: 20,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              17,
              14,
              12,
              14,
            ),
            decoration: BoxDecoration(
              color: colors.surface.withAlpha(205),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: colors.primary.withAlpha(35),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name'
                        '${age != null ? ', $age' : ''}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (relationship.isNotEmpty)
                        Text(
                          relationship,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                        ),
                      if (location.isNotEmpty)
                        Text(
                          location,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                        ),
                      if (headline.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onOpen,
                  icon: const Icon(
                    Icons.arrow_outward_rounded,
                    size: 17,
                  ),
                  label: const Text('View'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpatialBackground extends StatelessWidget {
  const _SpatialBackground();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -.12),
          radius: 1.12,
          colors: [
            colors.primaryContainer.withAlpha(115),
            colors.surface,
            colors.surface,
          ],
          stops: const [
            0,
            .57,
            1,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _SpatialDustPainter(
          primary: colors.primary,
          secondary: colors.secondary,
        ),
      ),
    );
  }
}

class _SpatialDustPainter extends CustomPainter {
  const _SpatialDustPainter({
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    for (var i = 0; i < 38; i++) {
      final x = ((i * 73) % 997) / 997 * size.width;

      final y = ((i * 131 + 47) % 991) / 991 * size.height;

      canvas.drawCircle(
        Offset(x, y),
        i % 7 == 0 ? 1.5 : .7,
        Paint()
          ..color = (i.isEven ? primary : secondary).withAlpha(
            i % 7 == 0 ? 30 : 14,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _SpatialDustPainter oldDelegate,
  ) {
    return oldDelegate.primary != primary || oldDelegate.secondary != secondary;
  }
}

class _SpatialLoading extends StatelessWidget {
  const _SpatialLoading();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(
          child: _SpatialBackground(),
        ),
        Center(
          child: CircularProgressIndicator(),
        ),
      ],
    );
  }
}

class _UniverseError extends StatelessWidget {
  const _UniverseError({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.tonal(
        onPressed: onRetry,
        child: const Text('Reload My Circle'),
      ),
    );
  }
}

class _EmptyUniverse extends StatelessWidget {
  const _EmptyUniverse({
    required this.displayName,
    required this.photoFuture,
    required this.onManage,
    required this.onSafety,
  });

  final String displayName;
  final Future<List<VisibleProfilePhoto>> photoFuture;
  final VoidCallback onManage;
  final VoidCallback onSafety;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: _SpatialBackground(),
        ),
        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: onSafety,
                  icon: const Icon(
                    Icons.shield_outlined,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 125,
                        height: 125,
                        child: _OwnerWorld(
                          displayName: displayName,
                          photoFuture: photoFuture,
                          worldName: 'My Circle',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Your universe is waiting',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your connections will appear here '
                        'as your Circle grows.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: onManage,
                        icon: const Icon(Icons.tune),
                        label: const Text(
                          'Manage relationships',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
