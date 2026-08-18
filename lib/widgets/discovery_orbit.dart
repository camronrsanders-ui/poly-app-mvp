import 'dart:math' as math;

import 'package:flutter/material.dart';

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

class _DiscoveryOrbitState extends State<DiscoveryOrbit> {
  static const _maxVisibleProfiles = 7;

  int _selectedIndex = 0;
  double _dragDistance = 0;

  @override
  void didUpdateWidget(covariant DiscoveryOrbit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profiles.isEmpty) {
      _selectedIndex = 0;
    } else if (_selectedIndex >= widget.profiles.length) {
      _selectedIndex = widget.profiles.length - 1;
    }
  }

  void _rotate(int delta) {
    if (widget.profiles.length < 2) return;
    setState(() {
      _selectedIndex =
          (_selectedIndex + delta + widget.profiles.length) %
              widget.profiles.length;
    });
  }

  List<int> _visibleIndices() {
    final count = widget.profiles.length;
    if (count <= _maxVisibleProfiles) {
      return List<int>.generate(count, (index) => index);
    }

    return List<int>.generate(
      _maxVisibleProfiles,
      (offset) => (_selectedIndex + offset) % count,
    );
  }

  String _displayName(Map<String, dynamic> profile) {
    final name = profile['displayName']?.toString().trim() ?? '';
    return name.isEmpty ? 'Someone' : name;
  }

  Widget _candidateAvatar({
    required Map<String, dynamic> profile,
    required int index,
    required bool selected,
  }) {
    final uid = profile['uid']?.toString() ?? '';
    final name = _displayName(profile);
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '$name is selected. Open their profile world.'
          : 'Select $name in your discovery orbit.',
      child: GestureDetector(
        onTap: () {
          if (selected) {
            widget.onViewProfile(profile);
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: selected ? 72 : 58,
          height: selected ? 72 : 58,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface,
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 4 : 2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: ClipOval(
            child: uid.isEmpty
                ? const ColoredBox(
                    color: Color(0xFFE8E0EC),
                    child: Icon(Icons.person),
                  )
                : widget.imageBuilder(uid),
          ),
        ),
      ),
    );
  }

  Widget _orbitCanvas() {
    final visible = _visibleIndices();
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 330,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;
          const centerY = 170.0;
          final radiusX = math.min(constraints.maxWidth * 0.39, 145.0);
          const radiusY = 112.0;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _dragDistance = 0,
            onHorizontalDragUpdate: (details) {
              _dragDistance += details.delta.dx;
            },
            onHorizontalDragEnd: (_) {
              if (_dragDistance.abs() < 24) return;
              _rotate(_dragDistance > 0 ? -1 : 1);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: radiusX * 2 + 44,
                      height: radiusY * 2 + 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: radiusX * 1.2,
                      height: radiusY * 1.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.secondary.withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: centerX - 38,
                  top: centerY - 38,
                  child: Semantics(
                    label: 'You are at the center of your discovery orbit.',
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primaryContainer,
                        border: Border.all(color: colors.primary, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person, color: colors.onPrimaryContainer),
                          const SizedBox(height: 2),
                          Text(
                            'You',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: colors.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                for (final index in visible)
                  _positionedCandidate(
                    index: index,
                    visibleCount: visible.length,
                    centerX: centerX,
                    centerY: centerY,
                    radiusX: radiusX,
                    radiusY: radiusY,
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.swipe, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        widget.profiles.length > 1
                            ? 'Swipe to rotate your orbit'
                            : 'Tap the profile to enter their world',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _positionedCandidate({
    required int index,
    required int visibleCount,
    required double centerX,
    required double centerY,
    required double radiusX,
    required double radiusY,
  }) {
    final count = widget.profiles.length;
    final relative = (index - _selectedIndex + count) % count;
    final slot = visibleCount == count
        ? relative
        : _visibleIndices().indexOf(index);
    final angle = -math.pi / 2 + (2 * math.pi * slot / visibleCount);
    final selected = index == _selectedIndex;
    final size = selected ? 72.0 : 58.0;
    final x = centerX + math.cos(angle) * radiusX - size / 2;
    final y = centerY + math.sin(angle) * radiusY - size / 2;

    return AnimatedPositioned(
      key: ValueKey(widget.profiles[index]['uid'] ?? index),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      left: x,
      top: y,
      child: _candidateAvatar(
        profile: widget.profiles[index],
        index: index,
        selected: selected,
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
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    final headline = profile['headline']?.toString().trim() ?? '';
    final intentions = (profile['intentionTags'] as List?)
            ?.whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .take(3)
            .toList(growable: false) ??
        const <String>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              age == null ? name : '$name, $age',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(location),
            ],
            if (headline.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                headline,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            if (intentions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: intentions
                    .map(
                      (value) => Chip(
                        label: Text(value),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: acting ? null : () => widget.onViewProfile(profile),
                icon: const Icon(Icons.public_outlined),
                label: const Text('Enter their profile world'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: acting ? null : () => widget.onPass(profile),
                    icon: const Icon(Icons.close),
                    label: const Text('Pass'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: acting ? null : () => widget.onLike(profile),
                    icon: acting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.favorite_border),
                    label: Text(acting ? 'Working…' : 'Connect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore your orbit',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Rotate through potential connections. Tap the selected person to step into their world.',
        ),
        const SizedBox(height: 8),
        _orbitCanvas(),
        const SizedBox(height: 12),
        _selectedCard(),
      ],
    );
  }
}
