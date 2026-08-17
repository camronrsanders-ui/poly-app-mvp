import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/connection_service.dart';
import '../../services/messaging_service.dart';
import '../../services/profile_media_service.dart';
import '../messages/chat_screen.dart';
import '../profile/profile_detail_screen.dart';
import '../safety/safety_center_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({
    super.key,
    this.onFindPeople,
  });

  final VoidCallback? onFindPeople;

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final _connections = ConnectionService();
  final _profileMedia = ProfileMediaService();
  final _spotlightController = PageController(viewportFraction: 0.9);

  late Future<List<Map<String, dynamic>>> _future;

  final Map<String, Future<List<VisibleProfilePhoto>>> _photoFutures = {};
  final Set<String> _busy = {};

  int _spotlightPage = 0;

  @override
  void initState() {
    super.initState();
    _future = _connections.loadConnections();
  }

  @override
  void dispose() {
    _spotlightController.dispose();
    super.dispose();
  }

  Future<List<VisibleProfilePhoto>> _photosFor(String uid) {
    if (uid.isEmpty) {
      return Future.value(const <VisibleProfilePhoto>[]);
    }

    return _photoFutures.putIfAbsent(
      uid,
      () => _profileMedia.listVisiblePhotos(uid),
    );
  }

  void _reload() {
    if (!mounted) return;

    setState(() {
      _photoFutures.clear();
      _future = _connections.loadConnections();
    });
  }

  Future<void> _refresh() async {
    final future = _connections.loadConnections();

    if (!mounted) return;

    setState(() {
      _photoFutures.clear();
      _future = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder owns the visible error state.
    }
  }

  Future<void> _openChat(
    BuildContext context,
    Map<String, dynamic> person,
  ) async {
    final otherUid = person['uid']?.toString();

    if (otherUid == null || otherUid.isEmpty || _busy.contains(otherUid)) {
      return;
    }

    setState(() => _busy.add(otherUid));

    try {
      var conversationId = person['conversationId']?.toString().trim() ?? '';

      if (conversationId.isEmpty) {
        conversationId = await MessagingService().ensureConversation(otherUid);
        person['conversationId'] = conversationId;
      }

      if (!context.mounted) return;

      setState(() => _busy.remove(otherUid));

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUid: otherUid,
            otherDisplayName: person['displayName']?.toString() ?? 'Connection',
          ),
        ),
      );

      if (mounted) _reload();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Open connection chat failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this conversation right now.'),
          ),
        );
      }
    } finally {
      if (mounted && _busy.contains(otherUid)) {
        setState(() => _busy.remove(otherUid));
      }
    }
  }

  Future<void> _openProfile(Map<String, dynamic> person) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(
          profile: person,
          showConnectAction: false,
        ),
      ),
    );

    if (!mounted) return;
    if (result == 'blocked') _reload();
  }

  Future<void> _confirmUnmatch(Map<String, dynamic> person) async {
    final otherUid = person['uid']?.toString();

    if (otherUid == null || otherUid.isEmpty || _busy.contains(otherUid)) {
      return;
    }

    final name = person['displayName']?.toString() ?? 'this connection';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End connection?'),
        content: Text(
          'Ending your connection with $name will close the conversation and '
          'revoke any Private Vault access in both directions. This cannot be '
          'undone automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End connection'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy.add(otherUid));

    try {
      await _connections.endConnection(otherUid);

      if (!mounted) return;

      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection with $name ended.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not end this connection right now.'),
          ),
        );
      }
    } finally {
      if (mounted && _busy.contains(otherUid)) {
        setState(() => _busy.remove(otherUid));
      }
    }
  }

  Widget _photoFallback({double iconSize = 40}) {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.secondaryContainer,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: iconSize,
          color: colors.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _profilePhoto(
    String uid, {
    BoxFit fit = BoxFit.cover,
    double fallbackIconSize = 40,
  }) {
    return FutureBuilder<List<VisibleProfilePhoto>>(
      future: _photosFor(uid),
      builder: (context, snapshot) {
        final photos = snapshot.data ?? const <VisibleProfilePhoto>[];

        if (photos.isNotEmpty) {
          return Image.network(
            photos.first.url.toString(),
            width: double.infinity,
            height: double.infinity,
            fit: fit,
            errorBuilder: (_, __, ___) =>
                _photoFallback(iconSize: fallbackIconSize),
          );
        }

        return _photoFallback(iconSize: fallbackIconSize);
      },
    );
  }

  List<String> _displayTags(Map<String, dynamic> person) {
    final output = <String>[];
    final seen = <String>{};

    void addValues(Object? raw) {
      if (raw is! List) return;

      for (final item in raw) {
        final value = item?.toString().trim() ?? '';
        if (value.isEmpty || !seen.add(value)) continue;
        output.add(value);
        if (output.length == 3) return;
      }
    }

    addValues(person['intentionTags']);
    if (output.length < 3) addValues(person['interests']);

    return output.take(3).toList(growable: false);
  }

  String _nameFor(Map<String, dynamic> person) {
    final name = person['displayName']?.toString().trim() ?? '';
    return name.isEmpty ? 'Connection' : name;
  }

  String _locationFor(Map<String, dynamic> person) {
    return [person['city'], person['region']]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
  }

  String _relationshipLabel(Map<String, dynamic> person) {
    final status = person['relationshipStatus']?.toString().trim() ?? '';
    if (status.isNotEmpty) return status;

    final structure = person['relationshipStructure']?.toString().trim() ?? '';
    if (structure.isNotEmpty) return structure;

    return 'Connected';
  }

  String _relativeTime(Map<String, dynamic> person) {
    final value = person['lastMessageAtMs'];
    final millis = value is num ? value.toInt() : null;

    if (millis == null || millis <= 0) return 'New connection';

    final then = DateTime.fromMillisecondsSinceEpoch(millis);
    final diff = DateTime.now().difference(then);

    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 35) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  String _momentFor(Map<String, dynamic> person) {
    final hasConversation =
        (person['conversationId']?.toString().trim() ?? '').isNotEmpty;
    if (hasConversation) return 'Your conversation is open';
    return 'You chose each other';
  }

  Color _softTint(Color base, Color surface) {
    return Color.alphaBlend(base.withAlpha(24), surface);
  }

  Color _connectionChipBg(String label) {
    final value = label.toLowerCase();

    if (value.contains('dating')) {
      return const Color(0xFFF6E3EC);
    }
    if (value.contains('partner')) {
      return const Color(0xFFEDE3F7);
    }
    if (value.contains('open')) {
      return const Color(0xFFE4F3E9);
    }
    if (value.contains('friend')) {
      return const Color(0xFFE8EEF8);
    }

    return const Color(0xFFF0E8F4);
  }

  Color _connectionChipFg(String label) {
    final value = label.toLowerCase();

    if (value.contains('dating')) {
      return const Color(0xFF7A3155);
    }
    if (value.contains('partner')) {
      return const Color(0xFF5A3075);
    }
    if (value.contains('open')) {
      return const Color(0xFF2C6345);
    }
    if (value.contains('friend')) {
      return const Color(0xFF355A7A);
    }

    return const Color(0xFF5D3C69);
  }

  Widget _connectionStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _connectionChipBg(label),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _connectionChipFg(label),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _pill(
    String text, {
    IconData? icon,
    Color? color,
  }) {
    final colors = Theme.of(context).colorScheme;
    final foreground = color ?? colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> person, {double size = 72}) {
    final colors = Theme.of(context).colorScheme;
    final uid = person['uid']?.toString() ?? '';

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface,
        border: Border.all(color: colors.primary.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: _profilePhoto(uid, fallbackIconSize: size * 0.42),
      ),
    );
  }

  Widget _topHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connections',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Nurture what matters.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Safety center',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SafetyCenterScreen()),
            ),
            icon: const Icon(Icons.shield_outlined),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Find people',
            onPressed: widget.onFindPeople,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
    );
  }

  Widget _spotlightCard(Map<String, dynamic> person, int index) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = _nameFor(person);
    final relationship = _relationshipLabel(person);

    final accent = index.isEven ? colors.primary : colors.tertiary;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _softTint(accent, colors.surface),
              colors.surface,
              _softTint(colors.secondary, colors.surface),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.outlineVariant.withAlpha(150)),
          boxShadow: [
            BoxShadow(
              color: accent.withAlpha(18),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pill(
                      index == 0 ? 'FEATURED' : 'SPOTLIGHT',
                      icon: index == 0
                          ? Icons.star_rounded
                          : Icons.auto_awesome_rounded,
                      color: accent,
                    ),
                    const Spacer(),
                    Text(
                      '$name is worth celebrating',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.02,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'You chose each other. Keep building what matters.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => _openProfile(person),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Celebrate'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withAlpha(150),
                      colors.primary.withAlpha(230),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    const Spacer(),
                    _avatar(person, size: 86),
                    const SizedBox(height: 14),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name.toUpperCase(),
                        maxLines: 1,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _connectionStatusChip(relationship),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _spotlight(List<Map<String, dynamic>> people) {
    final visible = people.take(4).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _spotlightController,
            padEnds: false,
            itemCount: visible.length,
            onPageChanged: (index) {
              if (mounted) setState(() => _spotlightPage = index);
            },
            itemBuilder: (context, index) =>
                _spotlightCard(visible[index], index),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(
            visible.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: index == _spotlightPage ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _spotlightPage
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surface,
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Icon(icon, size: 20, color: colors.primary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectionCard(Map<String, dynamic> person) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final uid = person['uid']?.toString() ?? '';
    final busy = uid.isNotEmpty && _busy.contains(uid);
    final name = _nameFor(person);
    final location = _locationFor(person);
    final tags = _displayTags(person);
    final relationship = _relationshipLabel(person);
    final moment = _momentFor(person);
    final relative = _relativeTime(person);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
      decoration: BoxDecoration(
        color: colors.surface.withAlpha(242),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withAlpha(160)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(person, size: 74),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _connectionStatusChip(relationship),
                          ),
                        ),
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                moment,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                relative,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags
                            .take(2)
                            .map((tag) => _pill(tag))
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Connection options',
                enabled: !busy,
                onSelected: (value) {
                  if (value == 'profile') _openProfile(person);
                  if (value == 'chat') _openChat(context, person);
                  if (value == 'unmatch') _confirmUnmatch(person);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'profile', child: Text('View profile')),
                  PopupMenuItem(value: 'chat', child: Text('Open chat')),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'unmatch',
                    child: Text('End connection'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: colors.outlineVariant.withAlpha(120)),
          const SizedBox(height: 4),
          Row(
            children: [
              _quickAction(
                icon: busy
                    ? Icons.hourglass_top_rounded
                    : Icons.chat_bubble_outline_rounded,
                label: busy ? 'Opening' : 'Message',
                onPressed: busy ? null : () => _openChat(context, person),
              ),
              _quickAction(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                onPressed: busy ? null : () => _openProfile(person),
              ),
              _quickAction(
                icon: Icons.favorite_border_rounded,
                label: 'Check in',
                onPressed: busy ? null : () => _openChat(context, person),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keepInTouchHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep in touch',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Moments keep connections strong.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Most recent',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _intentBanner() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _softTint(colors.primary, colors.surface),
            _softTint(colors.secondary, colors.surface),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withAlpha(120)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.surface.withAlpha(210),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.spa_outlined,
              color: colors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build your circle with intention',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Explore people who align with your values and inspire growth.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: widget.onFindPeople,
            child: const Text('Find people'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primaryContainer,
                      colors.secondaryContainer,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_border_rounded,
                  size: 44,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Your connections will live here',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 9),
              Text(
                'When interest is mutual, you can nurture those connections '
                'here with more intention.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: widget.onFindPeople,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Discover people'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 54,
                color: colors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Connections are unavailable',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'We could not load your people right now. Check your '
                'connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: _reload,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _softTint(colors.secondary, colors.surface),
            colors.surface,
            _softTint(colors.primary, colors.surface),
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              if (kDebugMode) {
                debugPrint('Connections load failed: ${snapshot.error}');
              }

              return Column(
                children: [
                  _topHeader(),
                  _errorState(),
                ],
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                children: [
                  _topHeader(),
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }

            final people = snapshot.data ?? const <Map<String, dynamic>>[];

            if (people.isEmpty) {
              return Column(
                children: [
                  _topHeader(),
                  _emptyState(),
                ],
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                children: [
                  _topHeader(),
                  _spotlight(people),
                  _keepInTouchHeader(),
                  ...people.map(_connectionCard),
                  _intentBanner(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
