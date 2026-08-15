import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

class PolycircleSpatialOrbitController {
  Map<String, Offset> _normalizedPositions = const <String, Offset>{};

  Map<String, Offset> get normalizedPositions => _normalizedPositions;

  void _replaceNormalizedPositions(
    Map<String, Offset> positions,
  ) {
    _normalizedPositions = Map<String, Offset>.unmodifiable(
      positions,
    );
  }
}

class PolycircleSpatialOrbit<T> extends StatefulWidget {
  const PolycircleSpatialOrbit({
    super.key,
    required this.items,
    required this.itemId,
    required this.avatarBuilder,
    required this.labelBuilder,
    required this.onFocused,
    required this.onOpen,
    this.centerBuilder,
    this.controller,
    this.hiddenItemIds = const <String>{},
    this.height = 380,
    this.maxVisibleItems = 12,
  });

  final List<T> items;

  final String Function(T item) itemId;

  final Widget Function(
    BuildContext context,
    T item,
    bool focused,
  ) avatarBuilder;

  final String Function(T item) labelBuilder;

  final ValueChanged<T> onFocused;
  final ValueChanged<T> onOpen;

  final WidgetBuilder? centerBuilder;

  final PolycircleSpatialOrbitController? controller;

  final Set<String> hiddenItemIds;

  final double height;
  final int maxVisibleItems;

  @override
  State<PolycircleSpatialOrbit<T>> createState() =>
      _PolycircleSpatialOrbitState<T>();
}

class _PolycircleSpatialOrbitState<T> extends State<PolycircleSpatialOrbit<T>>
    with SingleTickerProviderStateMixin {
  static const double _focusAngle = math.pi / 2;

  late final AnimationController _motion;

  double _rotation = _focusAngle;
  double _angularVelocity = 0;

  double? _lastPointerAngle;

  int _focusedIndex = 0;
  int _lastHapticIndex = 0;

  String? _lastPublishedId;

  bool _dragging = false;

  List<T> get _items =>
      widget.items.take(widget.maxVisibleItems).toList(growable: false);

  @override
  void initState() {
    super.initState();

    _motion = AnimationController.unbounded(
      vsync: this,
    )..addListener(_motionFrame);
  }

  @override
  void dispose() {
    _motion
      ..removeListener(_motionFrame)
      ..dispose();

    super.dispose();
  }

  @override
  void didUpdateWidget(
    covariant PolycircleSpatialOrbit<T> oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (_items.isEmpty) {
      _focusedIndex = 0;
      return;
    }

    if (_focusedIndex >= _items.length) {
      _focusedIndex = 0;
      _rotation = _focusAngle;
    }
  }

  double _normalize(double angle) {
    while (angle > math.pi) {
      angle -= math.pi * 2;
    }

    while (angle < -math.pi) {
      angle += math.pi * 2;
    }

    return angle;
  }

  double _baseAngle(
    int index,
    int count,
  ) {
    return (math.pi * 2 * index) / count;
  }

  double _angleForIndex(
    int index, [
    double? rotation,
  ]) {
    if (_items.isEmpty) return 0;

    return _baseAngle(
          index,
          _items.length,
        ) +
        (rotation ?? _rotation);
  }

  int _nearestIndexFor(
    double rotation,
  ) {
    if (_items.isEmpty) return 0;

    var nearest = 0;
    var smallestDistance = double.infinity;

    for (var index = 0; index < _items.length; index++) {
      final angle = _angleForIndex(
        index,
        rotation,
      );

      final distance = _normalize(
        angle - _focusAngle,
      ).abs();

      if (distance < smallestDistance) {
        smallestDistance = distance;
        nearest = index;
      }
    }

    return nearest;
  }

  void _publishFocus(
    int index, {
    required bool haptic,
  }) {
    if (_items.isEmpty || index < 0 || index >= _items.length) {
      return;
    }

    final item = _items[index];
    final id = widget.itemId(item);

    if (haptic && index != _lastHapticIndex) {
      _lastHapticIndex = index;

      HapticFeedback.selectionClick();
    }

    if (id == _lastPublishedId) return;

    _lastPublishedId = id;
    widget.onFocused(item);
  }

  void _motionFrame() {
    if (!mounted || _items.isEmpty) {
      return;
    }

    final next = _motion.value;
    final nearest = _nearestIndexFor(next);

    final changed = nearest != _focusedIndex;

    setState(() {
      _rotation = next;
      _focusedIndex = nearest;
    });

    if (changed) {
      _publishFocus(
        nearest,
        haptic: true,
      );
    }
  }

  double _pointerAngle(
    Offset position,
    Offset center,
  ) {
    // Correct the pointer space for the visually
    // flattened perspective ellipse. This makes
    // dragging around the ring feel circular.
    final dx = position.dx - center.dx;

    final dy = (position.dy - center.dy) * 1.65;

    return math.atan2(dy, dx);
  }

  void _beginDrag(
    Offset position,
    Offset center,
  ) {
    _motion.stop();

    _dragging = true;
    _angularVelocity = 0;

    _lastPointerAngle = _pointerAngle(
      position,
      center,
    );

    HapticFeedback.lightImpact();
  }

  void _updateDrag(
    Offset position,
    Offset center,
  ) {
    if (!_dragging || _lastPointerAngle == null || _items.isEmpty) {
      return;
    }

    final current = _pointerAngle(
      position,
      center,
    );

    final delta = _normalize(
      current - _lastPointerAngle!,
    );

    _lastPointerAngle = current;

    _angularVelocity = (_angularVelocity * .52) + (delta * 34);

    final nextRotation = _rotation + delta;

    final nearest = _nearestIndexFor(
      nextRotation,
    );

    final changed = nearest != _focusedIndex;

    setState(() {
      _rotation = nextRotation;
      _focusedIndex = nearest;
    });

    if (changed) {
      _publishFocus(
        nearest,
        haptic: true,
      );
    }
  }

  Future<void> _endDrag() async {
    if (!_dragging || _items.isEmpty) {
      return;
    }

    _dragging = false;
    _lastPointerAngle = null;

    _motion.stop();
    _motion.value = _rotation;

    final velocity = _angularVelocity.clamp(-4.4, 4.4).toDouble();

    if (velocity.abs() > .08) {
      await _motion.animateWith(
        FrictionSimulation(
          .27,
          _rotation,
          velocity,
        ),
      );
    }

    if (!mounted) return;

    await _focusIndex(
      _nearestIndexFor(
        _rotation,
      ),
    );
  }

  Future<void> _focusIndex(
    int index, {
    bool openIfAlreadyFocused = false,
  }) async {
    if (_items.isEmpty || index < 0 || index >= _items.length) {
      return;
    }

    if (index == _focusedIndex && openIfAlreadyFocused) {
      HapticFeedback.mediumImpact();

      widget.onOpen(
        _items[index],
      );

      return;
    }

    _motion.stop();

    final current = _angleForIndex(index);

    final correction = _normalize(
      _focusAngle - current,
    );

    final target = _rotation + correction;

    _motion.value = _rotation;

    await _motion.animateTo(
      target,
      duration: const Duration(
        milliseconds: 390,
      ),
      curve: Curves.easeOutCubic,
    );

    if (!mounted) return;

    setState(() {
      _rotation = target;
      _focusedIndex = index;
    });

    _publishFocus(
      index,
      haptic: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return SizedBox(
        height: widget.height,
      );
    }

    final colors = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final width = constraints.maxWidth;

            final height = constraints.maxHeight;

            final center = Offset(
              width / 2,
              height * .43,
            );

            final radius = math.min(
              width * .435,
              160.0,
            );

            final cameraDistance = radius * 3.0;

            final focalLength = cameraDistance * .79;

            const tilt = .50;

            final projector = _OrbitProjector(
              center: center,
              radius: radius,
              cameraDistance: cameraDistance,
              focalLength: focalLength,
              tilt: tilt,
            );

            final projected = <_ProjectedNode>[];

            for (var index = 0; index < _items.length; index++) {
              projected.add(
                projector.project(
                  index: index,
                  angle: _angleForIndex(
                    index,
                  ),
                ),
              );
            }

            widget.controller?._replaceNormalizedPositions(
              <String, Offset>{
                for (final node in projected)
                  widget.itemId(
                    _items[node.index],
                  ): Offset(
                    width <= 0 ? .5 : node.position.dx / width,
                    height <= 0 ? .43 : node.position.dy / height,
                  ),
              },
            );

            final backNodes = projected
                .where(
                  (node) => node.depth < 0,
                )
                .toList()
              ..sort(
                (a, b) => a.depth.compareTo(
                  b.depth,
                ),
              );

            final frontNodes = projected
                .where(
                  (node) => node.depth >= 0,
                )
                .toList()
              ..sort(
                (a, b) => a.depth.compareTo(
                  b.depth,
                ),
              );

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                _beginDrag(
                  details.localPosition,
                  center,
                );
              },
              onPanUpdate: (details) {
                _updateDrag(
                  details.localPosition,
                  center,
                );
              },
              onPanEnd: (_) {
                _endDrag();
              },
              onPanCancel: () {
                _endDrag();
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SpatialAtmospherePainter(
                        center: center,
                        radius: radius,
                        primary: colors.primary,
                      ),
                    ),
                  ),

                  // Rear half of the actual
                  // projected orbital plane.
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ProjectedRingPainter(
                        projector: projector,
                        front: false,
                        primary: colors.primary,
                        secondary: colors.secondary,
                      ),
                    ),
                  ),

                  // Members physically behind
                  // YOU are painted first.
                  for (final node in backNodes)
                    _buildNode(
                      context: context,
                      node: node,
                    ),

                  // The center sphere occludes
                  // distant members.
                  Positioned(
                    left: center.dx - 52,
                    top: center.dy - 52,
                    child: SizedBox(
                      width: 104,
                      height: 104,
                      child: widget.centerBuilder?.call(
                            context,
                          ) ??
                          _SpatialCenter(
                            colors: colors,
                          ),
                    ),
                  ),

                  // Front orbital rail literally
                  // crosses in front of YOU.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ProjectedRingPainter(
                          projector: projector,
                          front: true,
                          primary: colors.primary,
                          secondary: colors.secondary,
                        ),
                      ),
                    ),
                  ),

                  // Foreground members pass
                  // in front of the center.
                  for (final node in frontNodes)
                    _buildNode(
                      context: context,
                      node: node,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNode({
    required BuildContext context,
    required _ProjectedNode node,
  }) {
    final colors = Theme.of(context).colorScheme;

    final focused = node.index == _focusedIndex;

    final item = _items[node.index];

    final label = widget.labelBuilder(
      item,
    );

    if (widget.hiddenItemIds.contains(
      widget.itemId(item),
    )) {
      return const SizedBox.shrink();
    }

    // Perspective already alters
    // scale. Depth adds another
    // controlled layer of emphasis.
    final visualScale = (node.perspective * (.78 + node.depth01 * .20))
        .clamp(
          .53,
          1.30,
        )
        .toDouble();

    final finalScale = focused ? visualScale * 1.12 : visualScale;

    final opacity = focused
        ? 1.0
        : (.36 + node.depth01 * .64)
            .clamp(
              0.0,
              1.0,
            )
            .toDouble();

    const baseSize = 76.0;

    final displayedSize = baseSize * finalScale;

    return Positioned(
      left: node.position.dx - displayedSize / 2,
      top: node.position.dy - displayedSize / 2,
      child: Semantics(
        button: true,
        selected: focused,
        label: label,
        hint: focused ? 'Tap to open' : 'Tap to bring into focus',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focusIndex(
              node.index,
              openIfAlreadyFocused: true,
            );
          },
          child: Opacity(
            opacity: opacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: displayedSize,
                  height: displayedSize,
                  padding: EdgeInsets.all(
                    focused ? 3 : 2,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    // A highlight and a darker
                    // lower-right edge makes the
                    // photo frame read as a sphere.
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withAlpha(
                          node.depth >= 0 ? 245 : 170,
                        ),
                        colors.secondaryContainer,
                        colors.primary.withAlpha(
                          focused ? 215 : 110,
                        ),
                      ],
                    ),

                    border: Border.all(
                      color: focused ? colors.primary : colors.outlineVariant,
                      width: focused ? 3 : 1.2,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(
                          focused ? 68 : (8 + node.depth01 * 32).round(),
                        ),
                        blurRadius: focused ? 28 : 8 + node.depth01 * 18,
                        spreadRadius: focused ? 4 : 0,
                        offset: Offset(
                          0,
                          4 + node.depth01 * 8,
                        ),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.avatarBuilder(
                      context,
                      item,
                      focused,
                    ),
                  ),
                ),
                if (focused) ...[
                  const SizedBox(
                    height: 7,
                  ),
                  Container(
                    constraints: const BoxConstraints(
                      maxWidth: 112,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(
                        999,
                      ),
                      border: Border.all(
                        color: colors.primary.withAlpha(
                          50,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(
                            18,
                          ),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(
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
    );
  }
}

class _OrbitProjector {
  const _OrbitProjector({
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

  // Radians.
  final double tilt;

  _ProjectedNode project({
    required int index,
    required double angle,
  }) {
    // World space:
    //
    // X = side-to-side position.
    // Z = distance toward/away from camera.
    //
    // The orbit starts as a true circle
    // on the X/Z plane.
    final worldX = radius * math.cos(angle);

    final worldZ = radius * math.sin(angle);

    // Tilt that circular plane toward
    // the viewer. Positive Z becomes
    // both closer AND lower on-screen.
    final tiltedY = worldZ * math.sin(tilt);

    final cameraZ = worldZ * math.cos(tilt);

    final denominator = cameraDistance - cameraZ;

    final perspective = cameraDistance / denominator;

    final screenX = center.dx + focalLength * worldX / denominator;

    final screenY = center.dy + focalLength * tiltedY / denominator;

    final maximumDepth = radius * math.cos(tilt);

    final depth01 = ((cameraZ / maximumDepth) + 1) / 2;

    return _ProjectedNode(
      index: index,
      position: Offset(
        screenX,
        screenY,
      ),
      depth: cameraZ,
      depth01: depth01.clamp(
        0.0,
        1.0,
      ),
      perspective: perspective,
    );
  }
}

class _ProjectedNode {
  const _ProjectedNode({
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

class _SpatialCenter extends StatelessWidget {
  const _SpatialCenter({
    required this.colors,
  });

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors.primary.withAlpha(
                  48,
                ),
                colors.secondary.withAlpha(
                  20,
                ),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(
                -.32,
                -.38,
              ),
              radius: .95,
              colors: [
                Colors.white.withAlpha(
                  245,
                ),
                colors.secondaryContainer,
                colors.primaryContainer,
              ],
            ),
            border: Border.all(
              color: colors.primary.withAlpha(
                110,
              ),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withAlpha(
                  52,
                ),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.blur_circular_rounded,
                size: 29,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                'YOU',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpatialAtmospherePainter extends CustomPainter {
  const _SpatialAtmospherePainter({
    required this.center,
    required this.radius,
    required this.primary,
  });

  final Offset center;
  final double radius;
  final Color primary;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    // Suspended shadow beneath the
    // relationship universe.
    final shadowCenter = Offset(
      center.dx,
      center.dy + radius * .82,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter,
        width: radius * 1.42,
        height: 20,
      ),
      Paint()
        ..color = primary.withAlpha(
          14,
        )
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          13,
        ),
    );

    // Very soft atmosphere around YOU.
    canvas.drawCircle(
      center,
      68,
      Paint()
        ..color = primary.withAlpha(
          9,
        )
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          18,
        ),
    );
  }

  @override
  bool shouldRepaint(
    covariant _SpatialAtmospherePainter oldDelegate,
  ) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.primary != primary;
  }
}

class _ProjectedRingPainter extends CustomPainter {
  const _ProjectedRingPainter({
    required this.projector,
    required this.front,
    required this.primary,
    required this.secondary,
  });

  final _OrbitProjector projector;

  final bool front;

  final Color primary;
  final Color secondary;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    const segmentCount = 132;

    // Main physical orbital rail.
    for (var index = 0; index < segmentCount; index++) {
      final a = (math.pi * 2 * index) / segmentCount;

      final b = (math.pi * 2 * (index + 1)) / segmentCount;

      final first = projector.project(
        index: index,
        angle: a,
      );

      final second = projector.project(
        index: index + 1,
        angle: b,
      );

      final averageDepth = (first.depth + second.depth) / 2;

      final isFront = averageDepth >= 0;

      if (isFront != front) {
        continue;
      }

      final depth01 = ((first.depth01 + second.depth01) / 2);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = front ? 1.7 + depth01 * 2.0 : .8 + depth01 * .7
        ..color = primary.withAlpha(
          front ? (70 + depth01 * 90).round() : (24 + depth01 * 34).round(),
        );

      canvas.drawLine(
        first.position,
        second.position,
        paint,
      );

      // Luminous outer edge only on
      // the near side of the ring.
      if (front && depth01 > .60) {
        canvas.drawLine(
          first.position,
          second.position,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 7
            ..color = primary.withAlpha(
              8,
            ),
        );
      }
    }

    // Secondary orbital plane.
    //
    // This is intentionally subtle:
    // it makes the space feel larger
    // without turning the UI into a
    // game HUD.
    final alternate = _OrbitProjector(
      center: projector.center,
      radius: projector.radius * .77,
      cameraDistance: projector.cameraDistance,
      focalLength: projector.focalLength,
      tilt: -.34,
    );

    for (var index = 0; index < segmentCount; index++) {
      final a = (math.pi * 2 * index) / segmentCount;

      final b = (math.pi * 2 * (index + 1)) / segmentCount;

      final first = alternate.project(
        index: index,
        angle: a,
      );

      final second = alternate.project(
        index: index + 1,
        angle: b,
      );

      final averageDepth = (first.depth + second.depth) / 2;

      if ((averageDepth >= 0) != front) {
        continue;
      }

      final depth01 = (first.depth01 + second.depth01) / 2;

      canvas.drawLine(
        first.position,
        second.position,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = front ? 1.1 : .6
          ..color = secondary.withAlpha(
            front ? (18 + depth01 * 26).round() : 12,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _ProjectedRingPainter oldDelegate,
  ) {
    return oldDelegate.projector.center != projector.center ||
        oldDelegate.projector.radius != projector.radius ||
        oldDelegate.front != front ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}
