import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/connection_service.dart';
import '../../services/discovery_service.dart';
import '../profile/profile_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _discovery = DiscoveryService();
  final _connections = ConnectionService();
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _actingOn = {};

  @override
  void initState() {
    super.initState();
    _future = _discovery.loadCandidates();
  }

  void _reload() => setState(() => _future = _discovery.loadCandidates());

  Future<void> _like(Map<String, dynamic> profile) async {
    final uid = profile['uid'] as String?;
    if (uid == null || _actingOn.contains(uid)) return;
    setState(() => _actingOn.add(uid));
    try {
      final matched = await _connections.likeUser(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(matched ? 'You connected 🎉' : 'Interest sent.'),
      ));
      _reload();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover like failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send interest right now.')),
      );
    } finally {
      if (mounted) setState(() => _actingOn.remove(uid));
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
        const SnackBar(content: Text('Passed. This profile will stay out of Discover.')),
      );
      _reload();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Discover pass failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that Pass right now.')),
      );
    } finally {
      if (mounted) setState(() => _actingOn.remove(uid));
    }
  }

  Future<void> _viewProfile(Map<String, dynamic> profile) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ProfileDetailScreen(profile: profile)),
    );
    if (!mounted) return;
    if (result == 'liked' || result == 'matched' || result == 'blocked') {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('Discover load failed: ${snapshot.error}');
            if (snapshot.stackTrace != null) {
              debugPrintStack(stackTrace: snapshot.stackTrace!);
            }
          }
          return _StateMessage(
            icon: Icons.error_outline,
            title: 'Discover is taking a break',
            text: 'We could not load profiles. Check your connection and try again.',
            debugDetails: kDebugMode ? snapshot.error?.toString() : null,
            action: TextButton(onPressed: _reload, child: const Text('Try again')),
          );
        }
        final profiles = snapshot.data ?? [];
        if (profiles.isEmpty) {
          return _StateMessage(
            icon: Icons.travel_explore,
            title: 'Your circle is still growing',
            text: 'No new profiles match the current discovery settings yet.',
            action: TextButton(onPressed: _reload, child: const Text('Refresh')),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final p = profiles[index];
              final uid = p['uid']?.toString() ?? '';
              final acting = uid.isNotEmpty && _actingOn.contains(uid);
              final intentions = (p['intentionTags'] as List?)?.cast<String>() ?? const <String>[];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 32)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['displayName'] ?? 'Someone'}${p['age'] != null ? ', ${p['age']}' : ''}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text([p['city'], p['region']]
                                .whereType<String>()
                                .where((e) => e.isNotEmpty)
                                .join(', ')),
                          ],
                        )),
                      ]),
                      const SizedBox(height: 14),
                      if ((p['relationshipStructure'] ?? '').toString().isNotEmpty)
                        Chip(label: Text(p['relationshipStructure'].toString())),
                      if ((p['bio'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(p['bio'].toString()),
                      ],
                      if (intentions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: intentions.map((i) => Chip(label: Text(i))).toList(),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          IconButton.outlined(
                            tooltip: 'Pass',
                            onPressed: acting ? null : () => _pass(p),
                            icon: const Icon(Icons.close),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: acting ? null : () => _viewProfile(p),
                              child: const Text('View profile'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: acting ? null : () => _like(p),
                              icon: const Icon(Icons.favorite_border),
                              label: const Text('Connect'),
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
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
      ]),
    ),
  );
}
