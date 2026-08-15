import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/firebase_runtime.dart';
import '../../services/connection_service.dart';
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
  final _profiles = ProfileService();
  final _media = ProfileMediaService();

  final Map<String, Future<List<VisibleProfilePhoto>>> _photoFutures = {};

  late Future<_UniverseModel> _future;
  late final AnimationController _worldTravel;

  String _activeWorldId = 'mine';
  String? _pendingWorldId;

  Map<String, dynamic>? _focused;

  int _worldTravelDirection = 1;
  bool _worldTravelSwapped = false;

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

    final currentIndex = worlds.indexWhere(
      (world) => world.id == _activeWorldId,
    );

    final targetIndex = worlds.indexWhere(
      (world) => world.id == target.id,
    );

    _worldTravelDirection = targetIndex >= currentIndex ? 1 : -1;

    setState(() {
      _pendingWorldId = target.id;
      _worldTravelSwapped = false;
    });

    HapticFeedback.lightImpact();

    await _worldTravel.forward(from: 0);

    if (!mounted) return;

    setState(() {
      _pendingWorldId = null;
      _worldTravelSwapped = false;
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
    ]);

    return _UniverseModel(
      uid: uid,
      profile: results[1] as Map<String, dynamic>? ?? const <String, dynamic>{},
      connections: results[0] as List<Map<String, dynamic>>,
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

    final worlds = <_CircleWorld>[
      _CircleWorld(
        id: 'mine',
        name: 'My Circle',
        subtitle: 'Your relationship universe',
        icon: Icons.blur_circular_rounded,
        people: people,
      ),
    ];

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
      return _EmptyUniverse(
        displayName: model.profile['displayName']?.toString() ?? '',
        photoFuture: _photosFor(model.uid),
        onManage: _openManager,
        onSafety: _openSafety,
      );
    }

    final selected = _focused != null &&
            active.people.any(
              (person) => person['uid'] == _focused?['uid'],
            )
        ? _focused!
        : active.people.first;

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
                count: active.people.length,
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
                onCreate: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Shared Circle creation is the next '
                        'consent-backed build phase.',
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: _WorldCameraTravel(
                  animation: _worldTravel,
                  direction: _worldTravelDirection,
                  child: Center(
                    key: ValueKey(active.id),
                    child: PolycircleSpatialOrbit<Map<String, dynamic>>(
                      items: active.people,
                      itemId: (person) => person['uid']?.toString() ?? '',
                      labelBuilder: _name,
                      avatarBuilder: (
                        context,
                        person,
                        focused,
                      ) =>
                          _personPhoto(person),
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
                        photoFuture: _photosFor(model.uid),
                        worldName: active.name,
                      ),
                    ),
                  ),
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
}

class _UniverseModel {
  const _UniverseModel({
    required this.uid,
    required this.profile,
    required this.connections,
  });

  final String uid;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> connections;
}

class _CircleWorld {
  const _CircleWorld({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.people,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final List<Map<String, dynamic>> people;
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
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final world in worlds)
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: _WorldButton(
                world: world,
                selected: world.id == activeWorldId,
                onTap: () => onSelect(world),
              ),
            ),
          _CreateWorldButton(
            onTap: onCreate,
            colors: colors,
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
