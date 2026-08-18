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
        ? 300.0
        : viewport.height < 760
            ? 320.0
            : 356.0;

    return RepaintBoundary(
      child: SizedBox(
        key: const ValueKey('discovery-orbit-scene'),
        height: sceneHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final center = Offset(width / 2, height * 0.44);
            final radius = math.min(
              math.min(width * 0.46, height * 0.47),
              172.0,
            );
            final projector = _DiscoveryOrbitProjector(
              center: center,
              radius: radius,
              cameraDistance: radius * 3.05,
              focalLength: radius * 2.82,
              tilt: 0.52,
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
                    left: center.dx - 39,
                    top: center.dy - 39,
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
    final minimumScale = widget.profiles.length <= 2 ? 0.76 : 0.64;
    final depthScale = (node.perspective * (0.7 + node.depth01 * 0.3))
        .clamp(minimumScale, 1.22)
        .toDouble();
    final finalScale = selected ? depthScale * 1.14 : depthScale;
    final baseSize = widget.profiles.length <= 2 ? 84.0 : 80.0;
    final size = baseSize * finalScale;
    final opacity = selected
        ? 1.0
        : (0.68 + node.depth01 * 0.32).clamp(0.0, 1.0).toDouble();
    final identity = _identity(profile, node.index);
    final avatarKey = uid.isEmpty ? identity : uid;

    return Positioned(
      key: ValueKey('position-$identity'),
      left: node.position.dx - size / 2,
      top: node.position.dy - size / 2,
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
                width: size,
                height: size,
                padding: EdgeInsets.all(selected ? 3.4 : 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(
                        alpha: node.depth >= 0 ? 0.96 : 0.74,
                      ),
                      const Color(0xFFBE89FF),
                      const Color(0xFF6F24B9),
                    ],
                  ),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFF0DDFF)
                        : const Color(0xFFA66ADE).withValues(alpha: 0.72),
                    width: selected ? 3.2 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9C5CFF).withValues(
                        alpha: selected ? 0.72 : 0.18 + node.depth01 * 0.2,
                      ),
                      blurRadius: selected ? 34 : 10 + node.depth01 * 16,
                      spreadRadius: selected ? 5 : 0.5,
                      offset: Offset(0, 3 + node.depth01 * 7),
                    ),
                    if (selected)
                      BoxShadow(
                        color: const Color(0xFFD8B1FF).withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: ClipOval(
                  child: RepaintBoundary(
                    key: ValueKey('photo-$identity'),
                    child: uid.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFF2A1838),
                            child: Icon(Icons.person, color: Colors.white70),
                          )
                        : widget.imageBuilder(uid),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x99150C20),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF48285F)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7135A7).withValues(alpha: 0.14),
              blurRadius: 18,
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
                color: const Color(0xFFF2E7FF),
                disabledColor: Colors.white30,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              liveRegion: true,
              excludeSemantics: true,
              label:
                  'Profile ${_selectedIndex + 1} of ${widget.profiles.length}',
              child: Text(
                '${_selectedIndex + 1}  /  ${widget.profiles.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFD4C5E2),
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Next profile',
              child: IconButton(
                key: const ValueKey('discovery-next-profile'),
                tooltip: 'Next profile',
                onPressed: enabled ? () => _moveFocus(1) : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                color: const Color(0xFFF2E7FF),
                disabledColor: Colors.white30,
                visualDensity: VisualDensity.compact,
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
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xE8261735),
              Color(0xED150D20),
              Color(0xEB0D0914),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFF70429A)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C38B8).withValues(alpha: 0.24),
              blurRadius: 34,
              spreadRadius: -4,
              offset: const Offset(0, 14),
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
                    width: 7,
                    height: 7,
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
                          color: const Color(0xFFB99CCF),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.45,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                age == null ? name : '$name, $age',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        location,
                        style: const TextStyle(color: secondaryText),
                      ),
                    ),
                  ],
                ),
              ],
              if (headline.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  headline,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: primaryText,
                        height: 1.3,
                      ),
                ),
              ],
              if (intentions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: intentions
                      .map(
                        (value) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF342047),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF8658BA),
                            ),
                          ),
                          child: Text(
                            value,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: const Color(0xFFE8D7FF),
                                ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 16),
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
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.public_outlined),
                  label: const Text('Enter their profile world'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
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
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Pass'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
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
          offset: const Offset(0, -5),
          child: _orbitControls(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
          child: Text(
            widget.profiles.length > 1
                ? 'Drag the orbit or tap a person to change focus.'
                : 'Tap the focused person to enter their world.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9E90AA),
                ),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: 1,
          height: 13,
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
          width: 78,
          height: 78,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFA962FF).withValues(alpha: 0.34),
                      const Color(0xFF5C238E).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.35),
                    colors: [
                      Color(0xFF6F36A8),
                      Color(0xFF351249),
                      Color(0xFF190921),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFFCAA4F5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA654F0).withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome,
                        color: Color(0xFFEBD7FF), size: 17),
                    SizedBox(height: 2),
                    Text(
                      'YOU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
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
      canvas.drawLine(
        first.position,
        second.position,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = front ? 1.4 + depth * 1.6 : 0.75
          ..color = const Color(0xFFB274FF).withValues(
            alpha: front ? 0.26 + depth * 0.24 : 0.11,
          ),
      );

      if (front && depth > 0.62) {
        canvas.drawLine(
          first.position,
          second.position,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 8
            ..color = primary.withValues(alpha: 0.04),
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
          ..strokeWidth = front ? 0.85 : 0.5
          ..color = secondary.withValues(alpha: front ? 0.11 : 0.06),
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
