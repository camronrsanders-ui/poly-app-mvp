import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/connection_service.dart';
import '../../services/messaging_service.dart';
import '../../services/profile_media_service.dart';
import '../messages/chat_screen.dart';
import '../profile/profile_detail_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final _connections = ConnectionService();
  final _profileMedia = ProfileMediaService();

  late Future<List<Map<String, dynamic>>> _future;

  final Map<String, Future<List<VisibleProfilePhoto>>> _photoFutures = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _future = _connections.loadConnections();
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
            content: Text(
              'Could not open this conversation right now.',
            ),
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

  Future<void> _confirmUnmatch(
    Map<String, dynamic> person,
  ) async {
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
          'Ending your connection with $name will close the '
          'conversation and revoke any Private Vault access '
          'in both directions. This cannot be undone '
          'automatically.',
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
        SnackBar(
          content: Text('Connection with $name ended.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not end this connection right now.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && _busy.contains(otherUid)) {
        setState(() => _busy.remove(otherUid));
      }
    }
  }

  Widget _photoFallback() {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.secondaryContainer,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 58,
          color: colors.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _profilePhoto(String uid) {
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

        return _photoFallback();
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

    if (output.length < 3) {
      addValues(person['interests']);
    }

    return output.take(3).toList(growable: false);
  }

  Widget _tag(String text) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withAlpha(115),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _connectionCard(Map<String, dynamic> person) {
    final colors = Theme.of(context).colorScheme;

    final uid = person['uid']?.toString() ?? '';
    final busy = uid.isNotEmpty && _busy.contains(uid);

    final name = person['displayName']?.toString().trim() ?? '';

    final age = person['age'];

    final title = '${name.isEmpty ? 'Connection' : name}'
        '${age != null ? ', $age' : ''}';

    final relationship =
        person['relationshipStructure']?.toString().trim() ?? '';

    final status = person['relationshipStatus']?.toString().trim() ?? '';

    final relationshipLine = [
      relationship,
      status,
    ].where((value) => value.isNotEmpty).join(' • ');

    final location = [
      person['city'],
      person['region'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');

    final headline = person['headline']?.toString().trim() ?? '';

    final bio = person['bio']?.toString().trim() ?? '';

    final story = headline.isNotEmpty ? headline : bio;
    final tags = _displayTags(person);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : () => _openProfile(person),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 116,
                      height: 138,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colors.primary.withAlpha(65),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: _profilePhoto(uid),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CONNECTED',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.08,
                                  ),
                            ),
                            if (relationshipLine.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text(
                                relationshipLine,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Connection options',
                      enabled: !busy,
                      onSelected: (value) {
                        if (value == 'profile') {
                          _openProfile(person);
                        }
                        if (value == 'chat') {
                          _openChat(context, person);
                        }
                        if (value == 'unmatch') {
                          _confirmUnmatch(person);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'profile', child: Text('View profile')),
                        PopupMenuItem(value: 'chat', child: Text('Open chat')),
                        PopupMenuDivider(),
                        PopupMenuItem(
                            value: 'unmatch', child: Text('End connection')),
                      ],
                    ),
                  ],
                ),
                if (story.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      story,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.35),
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map(_tag).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () => _openProfile(person),
                        icon: const Icon(
                          Icons.person_outline_rounded,
                        ),
                        label: const Text('View profile'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => _openChat(
                                  context,
                                  person,
                                ),
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.chat_bubble_outline_rounded,
                              ),
                        label: Text(
                          busy ? 'Opening…' : 'Message',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(int count) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        4,
        4,
        4,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'People you’ve mutually chosen',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            count == 1
                ? 'One connection, built through mutual interest.'
                : '$count connections, built through mutual interest.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
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
              'Connections load failed: ${snapshot.error}',
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 54,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connections are unavailable',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We could not load your people right now. '
                    'Check your connection and try again.',
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
          );
        }

        final people = snapshot.data ?? [];

        if (people.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(34),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.people_alt_outlined,
                      size: 42,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'No connections yet',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'When interest is mutual, the people you '
                    'choose each other with will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              14,
              18,
              14,
              32,
            ),
            itemCount: people.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _header(people.length);
              }

              return _connectionCard(
                people[index - 1],
              );
            },
          ),
        );
      },
    );
  }
}
