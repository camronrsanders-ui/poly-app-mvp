import 'package:flutter/material.dart';

import '../../services/safety_service.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety center')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Your boundaries are part of the product',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Polycircle is built for consensual adult connections. A match never means consent to sexual messages, intimate media, meeting in person, or continued contact.',
          ),
          const SizedBox(height: 20),
          _section(
            context,
            icon: Icons.block,
            title: 'Block at any time',
            body: 'Blocking ends interaction through Polycircle. Existing connection and chat access are closed, and any private-media access is revoked. Unblocking does not automatically restore them.',
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _BlockedMembersScreen()),
            ),
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('Manage blocked members'),
          ),
          const SizedBox(height: 14),
          _section(
            context,
            icon: Icons.link_off,
            title: 'End a connection',
            body: 'Ending a connection closes the chat and revokes private-media sharing in both directions. The person will not silently reappear in Discover through the current reconnect flow.',
          ),
          _section(
            context,
            icon: Icons.flag_outlined,
            title: 'Report concerning behavior',
            body: 'Profiles and chats include reporting controls for harassment, fake profiles, hate speech, misrepresentation, spam, non-consensual content, and other safety concerns.',
          ),
          _section(
            context,
            icon: Icons.lock_outline,
            title: 'Private media stays gated',
            body: 'Private Vault is not available until its additional consent, moderation, retention, and security requirements pass. When enabled, sharing will require explicit consent and protected delivery.',
          ),
          _section(
            context,
            icon: Icons.photo_outlined,
            title: 'Profile photos are protected',
            body: 'Profile photos use a protected processing and review flow. Other permitted members receive short-lived access instead of permanent public Storage links.',
          ),
          _section(
            context,
            icon: Icons.location_off_outlined,
            title: 'Keep location coarse',
            body: 'The current profile uses city and region rather than publishing exact location. Share only the location detail you are comfortable putting on your profile.',
          ),
          _section(
            context,
            icon: Icons.people_outline,
            title: 'Relationship descriptions are not verification',
            body: 'A relationship card describes the account owner’s view. Naming another person does not mean that person has confirmed the relationship or consented to be represented.',
          ),
          _section(
            context,
            icon: Icons.no_accounts_outlined,
            title: 'Adults only',
            body: 'Polycircle is for people age 18 and older. Sexual or romantic exploitation of minors and sexual content involving minors are prohibited.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Polycircle’s block and report tools are product safety controls, not emergency services. If you are in immediate danger, use the emergency resources appropriate to your location.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BlockedMembersScreen extends StatefulWidget {
  const _BlockedMembersScreen();

  @override
  State<_BlockedMembersScreen> createState() => _BlockedMembersScreenState();
}

class _BlockedMembersScreenState extends State<_BlockedMembersScreen> {
  final _safety = SafetyService();
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _working = {};

  @override
  void initState() {
    super.initState();
    _future = _safety.listBlockedUsers();
  }

  Future<void> _refresh() async {
    final next = _safety.listBlockedUsers();
    setState(() => _future = next);
    await next;
  }

  Future<void> _unblock(Map<String, dynamic> block) async {
    final uid = block['blockedUid']?.toString() ?? '';
    if (uid.isEmpty || _working.contains(uid)) return;
    final name = block['displayName']?.toString().trim() ?? '';
    final label = name.isEmpty ? 'this member' : name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unblock $label?'),
        content: const Text(
          'Unblocking allows future eligible interaction, but it does not restore a previous match, conversation, or private-media access.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unblock')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working.add(uid));
    try {
      await _safety.unblockUser(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label unblocked.')));
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not unblock this member right now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _working.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blocked members')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('Could not load blocked members.', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _refresh, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }

        final blocks = snapshot.data ?? const <Map<String, dynamic>>[];
        if (blocks.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Icon(Icons.check_circle_outline, size: 56),
                SizedBox(height: 12),
                Text('No blocked members', textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: blocks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final block = blocks[index];
              final uid = block['blockedUid']?.toString() ?? '';
              final rawName = block['displayName']?.toString().trim() ?? '';
              final name = rawName.isEmpty ? 'Blocked member' : rawName;
              final working = uid.isNotEmpty && _working.contains(uid);
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.block)),
                title: Text(name),
                subtitle: const Text('Previous connections and private access stay closed.'),
                trailing: TextButton(
                  onPressed: working || uid.isEmpty ? null : () => _unblock(block),
                  child: working
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Unblock'),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
