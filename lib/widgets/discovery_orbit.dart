import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pure helpers for keeping every Discover candidate reachable while rendering
/// only the part of a large orbit that can be presented clearly.
class DiscoveryOrbitMath {
  const DiscoveryOrbitMath._();

  static const int maxVisibleProfiles = 8;

  static int wrapIndex(int index, int count) {
    if (count <= 0) return 0;
    return ((index % count) + count) % count;
  }

  static int nearestIndex(double position, int count) {
    if (count <= 0) return 0;
    return wrapIndex(position.round(), count);
  }

  static double normalizedPosition(double position, int count) {
    if (count <= 0) return 0;
    final normalized = position % count;
    return normalized < 0 ? normalized + count : normalized;
  }

  /// The shortest signed movement from [position] to [index].
  static double distanceToIndex(double position, int index, int count) {
    if (count <= 0) return 0;

    final normalized = normalizedPosition(position, count);
    var distance = wrapIndex(index, count) - normalized;
    final half = count / 2;

    if (distance > half) distance -= count;
    if (distance < -half) distance += count;

    return distance;
  }

  /// The signed candidate offset used to place an index around the orbit.
  static double positionOffset(double position, int index, int count) {
    return -distanceToIndex(position, index, count);
  }

  static List<int> visibleIndices(double position, int count) {
    if (count <= 0) return const <int>[];
    if (count <= maxVisibleProfiles) {
      return List<int>.generate(count, (index) => index, growable: false);
    }

    final nearest = nearestIndex(position, count);

    // Eight slots keep the rear-most replacement hidden in the deepest part
    // of the orbit. Advancing focus rotates this window through every profile.
    return List<int>.generate(
      maxVisibleProfiles,
      (slot) => wrapIndex(nearest + slot - 3, count),
      growable: false,
    );
  }
}

/// Deterministic presentation values for keeping the Orbit legible across
/// sparse and virtualized candidate populations.
class DiscoveryOrbitVisuals {
  const DiscoveryOrbitVisuals._();

  static double baseNodeSize(int count) {
    if (count <= 1) return 88;
    if (count <= 3) return 84;
    if (count <= DiscoveryOrbitMath.maxVisibleProfiles) return 80;
    return 76;
  }

  static double nodeScale({
    required int count,
    required double depth01,
    required double perspective,
    required bool selected,
  }) {
    final depth = depth01.clamp(0.0, 1.0);
    final minimum = count <= 3 ? 0.7 : 0.63;
    final maximum = count <= 3 ? 1.1 : 1.06;
    final projected = perspective * (0.7 + depth * 0.3);
    final depthScale = projected.clamp(minimum, maximum).toDouble();
    if (!selected) return depthScale;

    final focusScale = 1.2 + depth * (count <= 3 ? 0.2 : 0.23);
    return math.max(depthScale, focusScale).clamp(1.2, 1.43).toDouble();
  }

  static double nodeOpacity({
    required double depth01,
    required bool selected,
  }) {
    if (selected) return 1;
    final depth = depth01.clamp(0.0, 1.0);
    return (0.78 + Curves.easeOut.transform(depth) * 0.22)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

class DiscoveryOrbit extends StatefulWidget {
  const DiscoveryOrbit({
    super.key,
    required this.profiles,
    required this.imageBuilder,
    required this.onViewProfile,
    required this.onLike,
    required this.onPass,
    required this.isActing,
  });

  final List<Map<String, dynamic>> profiles;
  final Widget Function(String uid) imageBuilder;
  final ValueChanged<Map<String, dynamic>> onViewProfile;
  final ValueChanged<Map<String, dynamic>> onLike;
  final ValueChanged<Map<String, dynamic>> onPass;
  final bool Function(String uid) isActing;

  @override
  State<DiscoveryOrbit> createState() => _DiscoveryOrbitState();
}

class _DiscoveryOrbitState extends State<DiscoveryOrbit>
    with SingleTickerProviderStateMixin {
  static const double _focusAngle = math.pi / 2;

  late final AnimationController _motion;

  double _position = 0;
  double _positionVelocity = 0;
  double? _lastPointerAngle;
  Offset? _lastPointerPosition;
  Duration? _lastPointerTime;

  int _selectedIndex = 0;
  int _lastHapticIndex = 0;
  String? _selectedIdentity;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController.unbounded(vsync: this)
      ..addListener(_motionFrame);

    if (widget.profiles.isNotEmpty) {
      _selectedIdentity = _identity(widget.profiles.first, 0);
    }
  }

  @override
  void dispose() {
    _motion
      ..removeListener(_motionFrame)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DiscoveryOrbit oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_sameProfileOrder(oldWidget.profiles, widget.profiles)) return;

    _motion.stop();

    if (widget.profiles.isEmpty) {
      _position = 0;
      _selectedIndex = 0;
      _selectedIdentity = null;
      _setMotionValueSilently(0);
      return;
    }

    final oldIndex = _selectedIndex;
    final preservedIndex = _selectedIdentity == null
        ? -1
        : _indexOfIdentity(widget.profiles, _selectedIdentity!);
    final nextIndex = preservedIndex >= 0
        ? preservedIndex
        : oldIndex.clamp(0, widget.profiles.length - 1);

    _selectedIndex = nextIndex;
    _lastHapticIndex = nextIndex;
    _selectedIdentity = _identity(widget.profiles[nextIndex], nextIndex);
    _position = nextIndex.toDouble();
    _setMotionValueSilently(_position);
  }

  bool get _reduceMotion {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations == true ||
        media?.accessibleNavigation == true;
  }

  void _setMotionValueSilently(double value) {
    _motion.removeListener(_motionFrame);
    _motion.value = value;
    _motion.addListener(_motionFrame);
  }

  bool _sameProfileOrder(
    List<Map<String, dynamic>> before,
    List<Map<String, dynamic>> after,
  ) {
    if (before.length != after.length) return false;

    for (var index = 0; index < before.length; index++) {
      if (_identity(before[index], index) != _identity(after[index], index)) {
        return false;
      }
    }

    return true;
  }

  int _indexOfIdentity(
    List<Map<String, dynamic>> profiles,
    String identity,
  ) {
    for (var index = 0; index < profiles.length; index++) {
      if (_identity(profiles[index], index) == identity) return index;
    }
    return -1;
  }

  String _identity(Map<String, dynamic> profile, int index) {
    final uid = profile['uid']?.toString().trim() ?? '';
    return uid.isEmpty ? 'profile-index-$index' : 'profile-uid-$uid';
  }

  String _displayName(Map<String, dynamic> profile) {
    final name = profile['displayName']?.toString().trim() ?? '';
    return name.isEmpty ? 'Someone' : name;
  }

  void _motionFrame() {
    if (!mounted || widget.profiles.isEmpty) return;

    final nextPosition = _motion.value;
    final nextIndex = DiscoveryOrbitMath.nearestIndex(
      nextPosition,
      widget.profiles.length,
    );
    final changed = nextIndex != _selectedIndex;

    setState(() {
      _position = nextPosition;
      _selectedIndex = nextIndex;
      _selectedIdentity = _identity(widget.profiles[nextIndex], nextIndex);
    });

    if (changed && nextIndex != _lastHapticIndex) {
      _lastHapticIndex = nextIndex;
      HapticFeedback.selectionClick();
    }
  }

  double _angleStep(int count) {
    if (count <= 1) return math.pi * 2;
    return (math.pi * 2) /
        math.min(count, DiscoveryOrbitMath.maxVisibleProfiles);
  }

  double _normalizeAngle(double angle) {
    while (angle > math.pi) {
      angle -= math.pi * 2;
    }
    while (angle < -math.pi) {
      angle += math.pi * 2;
    }
    return angle;
  }

  double _pointerAngle(Offset position, Offset center) {
    final dx = position.dx - center.dx;
    final dy = (position.dy - center.dy) * 1.65;
    return math.atan2(dy, dx);
  }

  bool _shouldAcceptOrbitDrag(
    Offset start,
    Offset current,
    Offset center,
  ) {
    final movement = current - start;
    final adjustedMovement = Offset(movement.dx, movement.dy * 1.65);
    final radialPosition = Offset(
      start.dx - center.dx,
      (start.dy - center.dy) * 1.65,
    );

    // A horizontal movement through the central region is still a useful
    // orbit gesture. A vertical movement there belongs to the surrounding
    // pull-to-refresh/ListView instead.
    if (radialPosition.distance < 34) {
      return movement.dx.abs() > movement.dy.abs() * 1.1;
    }

    final radial = radialPosition / radialPosition.distance;
    final tangent = Offset(-radial.dy, radial.dx);
    final tangentialTravel =
        adjustedMovement.dx * tangent.dx + adjustedMovement.dy * tangent.dy;
    final radialTravel =
        adjustedMovement.dx * radial.dx + adjustedMovement.dy * radial.dy;

    return tangentialTravel.abs() >= radialTravel.abs() * 0.82 ||
        movement.dx.abs() > movement.dy.abs() * 1.25;
  }

  void _beginDrag(Offset position, Duration time, Offset center) {
    if (widget.profiles.length < 2) return;

    _motion.stop();
    _dragging = true;
    _positionVelocity = 0;
    _lastPointerAngle = _pointerAngle(position, center);
    _lastPointerPosition = position;
    _lastPointerTime = time;
    HapticFeedback.lightImpact();
  }

  void _updateDrag(Offset position, Duration time, Offset center) {
    if (!_dragging ||
        _lastPointerAngle == null ||
        _lastPointerPosition == null ||
        widget.profiles.length < 2) {
      return;
    }

    final previousPosition = _lastPointerPosition!;
    final previousAngle = _lastPointerAngle!;
    final currentAngle = _pointerAngle(position, center);
    final adjustedRadius = Offset(
      previousPosition.dx - center.dx,
      (previousPosition.dy - center.dy) * 1.65,
    ).distance;

    final angleDelta = adjustedRadius < 28
        ? -(position.dx - previousPosition.dx) / math.max(80, center.dx * 0.75)
        : _normalizeAngle(currentAngle - previousAngle);
    final positionDelta = angleDelta / _angleStep(widget.profiles.length);

    final elapsedMicros = _lastPointerTime == null
        ? 16667
        : math.max(1000, (time - _lastPointerTime!).inMicroseconds);
    final seconds = elapsedMicros / Duration.microsecondsPerSecond;
    final instantaneousVelocity = positionDelta / seconds;

    _positionVelocity = (_positionVelocity * 0.48) +
        (instantaneousVelocity.clamp(-12.0, 12.0) * 0.52);
    _lastPointerAngle = currentAngle;
    _lastPointerPosition = position;
    _lastPointerTime = time;
    _motion.value = _position + positionDelta;
  }

  void _endDrag() {
    if (!_dragging || widget.profiles.isEmpty) return;

    _dragging = false;
    _lastPointerAngle = null;
    _lastPointerPosition = null;
    _lastPointerTime = null;

    final inertialTravel = _reduceMotion
        ? 0.0
        : (_positionVelocity * 0.11).clamp(-1.5, 1.5).toDouble();
    final projectedPosition = _position + inertialTravel;
    final targetIndex = DiscoveryOrbitMath.nearestIndex(
      projectedPosition,
      widget.profiles.length,
    );

    _animateToIndex(targetIndex, fromDirectManipulation: true);
  }

  void _animateToIndex(
    int index, {
    bool openIfAlreadyFocused = false,
    bool fromDirectManipulation = false,
  }) {
    if (widget.profiles.isEmpty ||
        index < 0 ||
        index >= widget.profiles.length) {
      return;
    }

    if (index == _selectedIndex &&
        openIfAlreadyFocused &&
        !fromDirectManipulation) {
      HapticFeedback.mediumImpact();
      widget.onViewProfile(widget.profiles[index]);
      return;
    }

    _motion.stop();
    final target = _position +
        DiscoveryOrbitMath.distanceToIndex(
          _position,
          index,
          widget.profiles.length,
        );

    if (_reduceMotion) {
      _motion.value = target;
      return;
    }

    final distance = (target - _position).abs();
    final milliseconds = (230 + distance * 55).round().clamp(230, 460);
    _motion.animateTo(
      target,
      duration: Duration(milliseconds: milliseconds),
      curve: fromDirectManipulation ? Curves.easeOutQuart : Curves.easeOutCubic,
    );
  }

  void _moveFocus(int delta) {
    if (widget.profiles.length < 2) return;
    final index = DiscoveryOrbitMath.wrapIndex(
      _selectedIndex + delta,
      widget.profiles.length,
    );
    _animateToIndex(index);
  }

  Widget _orbitScene() {
    final viewport = MediaQuery.sizeOf(context);
    final sceneHeight = viewport.width <= 340
        ? 292.0
        : viewport.height < 760
            ? 312.0
            : 340.0;

    return RepaintBoundary(
      child: SizedBox(
        key: const ValueKey('discovery-orbit-scene'),
        height: sceneHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final center = Offset(width / 2, height * 0.42);
            final radius = math.min(
              math.min(width * 0.455, height * 0.49),
              170.0,
            );
            final projector = _DiscoveryOrbitProjector(
              center: center,
              radius: radius,
              cameraDistance: radius * 2.75,
              focalLength: radius * 2.5,
              tilt: 0.56,
            );
            final visible = DiscoveryOrbitMath.visibleIndices(
              _position,
              widget.profiles.length,
            );
            final angleStep = _angleStep(widget.profiles.length);
            final projected = <_DiscoveryProjectedNode>[
              for (final index in visible)
                projector.project(
                  index: index,
                  angle: _focusAngle +
                      DiscoveryOrbitMath.positionOffset(
                            _position,
                            index,
                            widget.profiles.length,
                          ) *
                          angleStep,
                ),
            ];
            final backNodes = projected.where((node) => node.depth < 0).toList()
              ..sort((a, b) => a.depth.compareTo(b.depth));
            final frontNodes = projected
                .where((node) => node.depth >= 0)
                .toList()
              ..sort((a, b) => a.depth.compareTo(b.depth));

            return RawGestureDetector(
              key: const ValueKey('discovery-orbit-gesture-surface'),
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                _OrbitDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _OrbitDragGestureRecognizer>(
                  _OrbitDragGestureRecognizer.new,
                  (recognizer) {
                    recognizer.shouldAccept = (start, current) =>
                        _shouldAcceptOrbitDrag(start, current, center);
                    recognizer.onStart = (update) => _beginDrag(
                          update.position,
                          update.time,
                          center,
                        );
                    recognizer.onUpdate = (update) => _updateDrag(
                          update.position,
                          update.time,
                          center,
                        );
                    recognizer.onEnd = _endDrag;
                  },
                ),
              },
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DiscoveryAtmospherePainter(
                          center: center,
                          radius: radius,
                          primary: const Color(0xFF8D43E4),
                          secondary: const Color(0xFFC98BFF),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DiscoveryRailPainter(
                          projector: projector,
                          front: false,
                          primary: const Color(0xFF8D43E4),
                          secondary: const Color(0xFFC98BFF),
                        ),
                      ),
                    ),
                  ),
                  for (final node in backNodes) _candidateNode(node),
                  Positioned(
                    left: center.dx - 36,
                    top: center.dy - 36,
                    child: const _DiscoveryCenter(),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DiscoveryRailPainter(
                          projector: projector,
                          front: true,
                          primary: const Color(0xFF8D43E4),
                          secondary: const Color(0xFFC98BFF),
                        ),
                      ),
                    ),
                  ),
                  for (final node in frontNodes) _candidateNode(node),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _candidateNode(_DiscoveryProjectedNode node) {
    final profile = widget.profiles[node.index];
    final uid = profile['uid']?.toString().trim() ?? '';
    final selected = node.index == _selectedIndex;
    final name = _displayName(profile);
    final finalScale = DiscoveryOrbitVisuals.nodeScale(
      count: widget.profiles.length,
      depth01: node.depth01,
      perspective: node.perspective,
      selected: selected,
    );
    final baseSize = DiscoveryOrbitVisuals.baseNodeSize(
      widget.profiles.length,
    );
    final size = baseSize * finalScale;
    final opacity = DiscoveryOrbitVisuals.nodeOpacity(
      depth01: node.depth01,
      selected: selected,
    );
    final identity = _identity(profile, node.index);
    final avatarKey = uid.isEmpty ? identity : uid;
    final framePadding = selected ? 4.2 : 2.4;

    return Positioned(
      key: ValueKey('position-$identity'),
      left: node.position.dx - size / 2,
      top: node.position.dy - size / 2 - (selected ? 4 : 0),
      child: Semantics(
        button: true,
        selected: selected,
        label: selected
            ? '$name, focused profile'
            : '$name, profile in your discovery orbit',
        hint: selected
            ? 'Activate to enter their profile world'
            : 'Activate to bring this profile into focus',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: ValueKey('discovery-avatar-$avatarKey'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _animateToIndex(
              node.index,
              openIfAlreadyFocused: true,
            ),
            child: Opacity(
              opacity: opacity,
              child: Container(
                key: ValueKey('discovery-frame-$avatarKey'),
                width: size,
                height: size,
                padding: EdgeInsets.all(framePadding),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: selected
                        ? const [
                            Color(0xFFFFFAFF),
                            Color(0xFFD9B7FF),
                            Color(0xFF8C3DDE),
                          ]
                        : [
                            const Color(0xFFDCC2F7).withValues(
                              alpha: 0.72 + node.depth01 * 0.2,
                            ),
                            const Color(0xFF9A62CF),
                            const Color(0xFF552273),
                          ],
                  ),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFF7E9FF)
                        : const Color(0xFFB584E1).withValues(
                            alpha: 0.42 + node.depth01 * 0.28,
                          ),
                    width: selected ? 1.4 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9C5CFF).withValues(
                        alpha: selected ? 0.68 : 0.1 + node.depth01 * 0.18,
                      ),
                      blurRadius: selected ? 38 : 8 + node.depth01 * 14,
                      spreadRadius: selected ? 5 : 0,
                      offset: Offset(0, selected ? 10 : 3 + node.depth01 * 5),
                    ),
                    if (selected)
                      BoxShadow(
                        color: const Color(0xFFE2C3FF).withValues(alpha: 0.28),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Container(
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? const Color(0xB3FFFFFF)
                          : const Color(0x5CDCC2F7),
                      width: selected ? 1.1 : 0.65,
                    ),
                  ),
                  child: ClipOval(
                    clipBehavior: Clip.antiAlias,
                    child: RepaintBoundary(
                      key: ValueKey('photo-$identity'),
                      child: uid.isEmpty
                          ? const ColoredBox(
                              color: Color(0xFF2A1838),
                              child: Icon(
                                Icons.person_rounded,
                                color: Color(0xFFDCC8EC),
                              ),
                            )
                          : widget.imageBuilder(uid),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _orbitControls() {
    final enabled = widget.profiles.length > 1;

    return Center(
      child: Container(
        key: const ValueKey('discovery-orbit-controls'),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x80150C20),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xB34E2B67),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7135A7).withValues(alpha: 0.1),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: 'Previous profile',
              child: IconButton(
                key: const ValueKey('discovery-previous-profile'),
                tooltip: 'Previous profile',
                onPressed: enabled ? () => _moveFocus(-1) : null,
                icon: const Icon(Icons.arrow_back_rounded),
                iconSize: 21,
                color: const Color(0xFFD9C7E8),
                disabledColor: Colors.white30,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: const EdgeInsets.all(10),
                visualDensity: VisualDensity.standard,
              ),
            ),
            const SizedBox(width: 3),
            Semantics(
              liveRegion: true,
              excludeSemantics: true,
              label:
                  'Profile ${_selectedIndex + 1} of ${widget.profiles.length}',
              child: Text(
                '${_selectedIndex + 1} / ${widget.profiles.length}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFC8B8D5),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 3),
            Semantics(
              button: true,
              label: 'Next profile',
              child: IconButton(
                key: const ValueKey('discovery-next-profile'),
                tooltip: 'Next profile',
                onPressed: enabled ? () => _moveFocus(1) : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                iconSize: 21,
                color: const Color(0xFFD9C7E8),
                disabledColor: Colors.white30,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: const EdgeInsets.all(10),
                visualDensity: VisualDensity.standard,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedCard() {
    final profile = widget.profiles[_selectedIndex];
    final uid = profile['uid']?.toString() ?? '';
    final acting = uid.isNotEmpty && widget.isActing(uid);
    final name = _displayName(profile);
    final age = profile['age'];
    final location = [profile['city'], profile['region']]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
    final headline = profile['headline']?.toString().trim() ?? '';
    final intentions = (profile['intentionTags'] as List?)
            ?.whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .take(3)
            .toList(growable: false) ??
        const <String>[];
    const primaryText = Color(0xFFF7F1FF);
    const secondaryText = Color(0xFFCFC2DB);

    return Semantics(
      container: true,
      label: 'Focused profile details for $name',
      child: Container(
        key: const ValueKey('discovery-world-preview'),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xEB291838),
              Color(0xF0180E24),
              Color(0xF20D0914),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF70429A),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C38B8).withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 12),
            ),
            const BoxShadow(
              color: Color(0x1FDDBBFF),
              blurRadius: 8,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: KeyedSubtree(
          key: ValueKey('selected-profile-$uid'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC891FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xAA9C5CFF),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WORLD PREVIEW',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFC5A8DA),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.55,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                age == null ? name : '$name, $age',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.35,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: secondaryText,
                              height: 1.2,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
              if (headline.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  headline,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: primaryText,
                        fontWeight: FontWeight.w500,
                        height: 1.28,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (intentions.isNotEmpty) ...[
                const SizedBox(height: 11),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: intentions
                      .map(
                        (value) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xB3342047),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xB38658BA),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            value,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: const Color(0xFFE8D7FF),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('discovery-enter-profile-world'),
                  onPressed:
                      acting ? null : () => widget.onViewProfile(profile),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF5EAFF),
                    disabledForegroundColor: Colors.white38,
                    backgroundColor: const Color(0x662F1843),
                    side: BorderSide(
                      color: acting
                          ? const Color(0xFF44364D)
                          : const Color(0xFF8050A9),
                    ),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.public_outlined, size: 18),
                  label: const Text('Enter their profile world'),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      key: const ValueKey('discovery-pass'),
                      onPressed: acting ? null : () => widget.onPass(profile),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF1E8F8),
                        disabledForegroundColor: Colors.white38,
                        side: BorderSide(
                          color:
                              acting ? Colors.white24 : const Color(0xFF836B90),
                        ),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 19),
                      label: const Text('Pass'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 7,
                    child: FilledButton.icon(
                      key: const ValueKey('discovery-connect'),
                      onPressed: acting ? null : () => widget.onLike(profile),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B3DDA),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF4A3855),
                        disabledForegroundColor: Colors.white70,
                        minimumSize: const Size.fromHeight(48),
                        elevation: acting ? 0 : 3,
                        shadowColor: const Color(0xFF9B52E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: acting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            )
                          : const Icon(Icons.favorite_border_rounded),
                      label: Text(acting ? 'Working…' : 'Connect'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profiles.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        _orbitScene(),
        Transform.translate(
          offset: const Offset(0, -3),
          child: _orbitControls(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: Text(
            widget.profiles.length > 1
                ? 'Drag the orbit, tap a person, or use the arrows.'
                : 'Tap the focused person to enter their world.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9E90AA),
                  fontSize: 11.5,
                  letterSpacing: 0.1,
                ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 1,
          height: 11,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF8A4EBA),
                Color(0x337C45A6),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _selectedCard(),
        ),
      ],
    );
  }
}

class _DiscoveryCenter extends StatelessWidget {
  const _DiscoveryCenter();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'You are at the center of your discovery orbit',
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey('discovery-you-orb'),
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFA962FF).withValues(alpha: 0.28),
                      const Color(0xFF5C238E).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const Positioned.fill(
                child: CustomPaint(
                  painter: _DiscoveryCenterEnergyPainter(),
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.35),
                    colors: [
                      Color(0xFF69339C),
                      Color(0xFF311143),
                      Color(0xFF16081E),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFFBE94EB),
                    width: 1.15,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA654F0).withValues(alpha: 0.28),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                    const BoxShadow(
                      color: Color(0x24F3E2FF),
                      blurRadius: 5,
                      offset: Offset(-1, -1),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFE8D1FF),
                      size: 15,
                    ),
                    SizedBox(height: 1),
                    Text(
                      'YOU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryCenterEnergyPainter extends CustomPainter {
  const _DiscoveryCenterEnergyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final arc = Paint()
      ..color = const Color(0xFFCB9EFF).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(bounds.deflate(4.5), -2.65, 0.92, false, arc);

    arc
      ..color = const Color(0xFF8C49C7).withValues(alpha: 0.3)
      ..strokeWidth = 0.8;
    canvas.drawArc(bounds.deflate(3.5), 0.3, 0.72, false, arc);
  }

  @override
  bool shouldRepaint(covariant _DiscoveryCenterEnergyPainter oldDelegate) {
    return false;
  }
}

class _DiscoveryOrbitProjector {
  const _DiscoveryOrbitProjector({
    required this.center,
    required this.radius,
    required this.cameraDistance,
    required this.focalLength,
    required this.tilt,
  });

  final Offset center;
  final double radius;
  final double cameraDistance;
  final double focalLength;
  final double tilt;

  _DiscoveryProjectedNode project({
    required int index,
    required double angle,
  }) {
    final worldX = radius * math.cos(angle);
    final worldZ = radius * math.sin(angle);
    final tiltedY = worldZ * math.sin(tilt);
    final cameraZ = worldZ * math.cos(tilt);
    final denominator = cameraDistance - cameraZ;
    final perspective = cameraDistance / denominator;
    final maximumDepth = radius * math.cos(tilt);

    return _DiscoveryProjectedNode(
      index: index,
      position: Offset(
        center.dx + focalLength * worldX / denominator,
        center.dy + focalLength * tiltedY / denominator,
      ),
      depth: cameraZ,
      depth01: (((cameraZ / maximumDepth) + 1) / 2).clamp(0.0, 1.0),
      perspective: perspective,
    );
  }
}

class _DiscoveryProjectedNode {
  const _DiscoveryProjectedNode({
    required this.index,
    required this.position,
    required this.depth,
    required this.depth01,
    required this.perspective,
  });

  final int index;
  final Offset position;
  final double depth;
  final double depth01;
  final double perspective;
}

class _DiscoveryAtmospherePainter extends CustomPainter {
  const _DiscoveryAtmospherePainter({
    required this.center,
    required this.radius,
    required this.primary,
    required this.secondary,
  });

  final Offset center;
  final double radius;
  final Color primary;
  final Color secondary;

  static const _stars = <Offset>[
    Offset(0.08, 0.16),
    Offset(0.16, 0.72),
    Offset(0.23, 0.3),
    Offset(0.31, 0.84),
    Offset(0.4, 0.1),
    Offset(0.53, 0.24),
    Offset(0.61, 0.79),
    Offset(0.7, 0.12),
    Offset(0.79, 0.67),
    Offset(0.88, 0.25),
    Offset(0.94, 0.81),
    Offset(0.06, 0.48),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < _stars.length; index++) {
      final star = _stars[index];
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        index % 4 == 0 ? 1.25 : 0.75,
        Paint()
          ..color = (index.isEven ? primary : secondary).withValues(
            alpha: index % 4 == 0 ? 0.34 : 0.2,
          ),
      );
    }

    canvas.drawCircle(
      center,
      74,
      Paint()
        ..color = primary.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.82),
        width: radius * 1.55,
        height: 24,
      ),
      Paint()
        ..color = primary.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  @override
  bool shouldRepaint(covariant _DiscoveryAtmospherePainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}

class _DiscoveryRailPainter extends CustomPainter {
  const _DiscoveryRailPainter({
    required this.projector,
    required this.front,
    required this.primary,
    required this.secondary,
  });

  final _DiscoveryOrbitProjector projector;
  final bool front;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 120;

    for (var index = 0; index < segments; index++) {
      final first = projector.project(
        index: index,
        angle: math.pi * 2 * index / segments,
      );
      final second = projector.project(
        index: index + 1,
        angle: math.pi * 2 * (index + 1) / segments,
      );
      final isFront = (first.depth + second.depth) / 2 >= 0;
      if (isFront != front) continue;

      final depth = (first.depth01 + second.depth01) / 2;
      final depthEmphasis = Curves.easeIn.transform(depth.clamp(0.0, 1.0));
      canvas.drawLine(
        first.position,
        second.position,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = front ? 0.9 + depthEmphasis * 1.05 : 0.55
          ..color = primary.withValues(
            alpha: front
                ? 0.13 + depthEmphasis * 0.18
                : 0.05 + depthEmphasis * 0.035,
          ),
      );

      if (front && depth > 0.68) {
        canvas.drawLine(
          first.position,
          second.position,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 6
            ..color = secondary.withValues(
              alpha: 0.018 + depthEmphasis * 0.022,
            ),
        );
      }
    }

    final secondPlane = _DiscoveryOrbitProjector(
      center: projector.center,
      radius: projector.radius * 0.72,
      cameraDistance: projector.cameraDistance,
      focalLength: projector.focalLength,
      tilt: -0.3,
    );

    for (var index = 0; index < segments; index++) {
      final first = secondPlane.project(
        index: index,
        angle: math.pi * 2 * index / segments,
      );
      final second = secondPlane.project(
        index: index + 1,
        angle: math.pi * 2 * (index + 1) / segments,
      );
      final isFront = (first.depth + second.depth) / 2 >= 0;
      if (isFront != front) continue;

      canvas.drawLine(
        first.position,
        second.position,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = front ? 0.7 : 0.45
          ..color = secondary.withValues(alpha: front ? 0.075 : 0.035),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiscoveryRailPainter oldDelegate) {
    return oldDelegate.projector.center != projector.center ||
        oldDelegate.projector.radius != projector.radius ||
        oldDelegate.projector.cameraDistance != projector.cameraDistance ||
        oldDelegate.projector.focalLength != projector.focalLength ||
        oldDelegate.projector.tilt != projector.tilt ||
        oldDelegate.front != front ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}

class _OrbitPointerUpdate {
  const _OrbitPointerUpdate(this.position, this.time);

  final Offset position;
  final Duration time;
}

class _OrbitDragGestureRecognizer extends OneSequenceGestureRecognizer {
  _OrbitDragGestureRecognizer({super.debugOwner});

  bool Function(Offset start, Offset current)? shouldAccept;
  ValueChanged<_OrbitPointerUpdate>? onStart;
  ValueChanged<_OrbitPointerUpdate>? onUpdate;
  VoidCallback? onEnd;

  int? _pointer;
  Offset? _initialPosition;
  Duration? _latestTime;
  bool _accepted = false;
  bool _rejected = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) {
      resolvePointer(event.pointer, GestureDisposition.rejected);
      return;
    }

    _pointer = event.pointer;
    _initialPosition = event.localPosition;
    _latestTime = event.timeStamp;
    _accepted = false;
    _rejected = false;
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;

    if (event is PointerMoveEvent) {
      _latestTime = event.timeStamp;

      if (!_accepted && !_rejected) {
        final travel = event.localPosition - _initialPosition!;
        if (travel.distance >= 8) {
          final accepts = shouldAccept?.call(
                _initialPosition!,
                event.localPosition,
              ) ??
              true;
          resolve(
            accepts ? GestureDisposition.accepted : GestureDisposition.rejected,
          );
          if (!accepts) _rejected = true;
        }
      }

      if (_accepted) {
        onUpdate?.call(
          _OrbitPointerUpdate(event.localPosition, event.timeStamp),
        );
      }
      return;
    }

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_accepted) {
        onEnd?.call();
      } else if (!_rejected) {
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer != _pointer || _accepted) return;
    _accepted = true;
    onStart?.call(
      _OrbitPointerUpdate(
        _initialPosition!,
        _latestTime ?? Duration.zero,
      ),
    );
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) _rejected = true;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
    _initialPosition = null;
    _latestTime = null;
    _accepted = false;
    _rejected = false;
  }

  @override
  String get debugDescription => 'discovery orbit drag';
}
