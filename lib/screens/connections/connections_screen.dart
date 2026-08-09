import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/connection_service.dart';
import '../../services/messaging_service.dart';
import '../messages/chat_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  Key _reloadKey = UniqueKey();

  Future<List<Map<String, dynamic>>> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final db = FirebaseFirestore.instance;
    final a = await db.collection('matches').where('userAUid', isEqualTo: uid).where('active', isEqualTo: true).get();
    final b = await db.collection('matches').where('userBUid', isEqualTo: uid).where('active', isEqualTo: true).get();
    final matches = [...a.docs, ...b.docs];
    final result = <Map<String, dynamic>>[];
    for (final match in matches) {
      final data = match.data();
      final otherUid = data['userAUid'] == uid ? data['userBUid'] as String? : data['userAUid'] as String?;
      if (otherUid == null) continue;
      final profile = await db.collection('profiles').doc(otherUid).get();
      if (!profile.exists) continue;
      result.add({...?profile.data(), 'uid': otherUid, 'matchId': match.id});
    }
    return result;
  }

  Future<void> _openChat(BuildContext context, Map<String, dynamic> person) async {
    final otherUid = person['uid'] as String?;
    if (otherUid == null) return;
    try {
      final service = MessagingService();
      final conversationId = await service.ensureConversation(otherUid);
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          otherUid: otherUid,
          otherDisplayName: person['displayName']?.toString() ?? 'Connection',
        ),
      ));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this conversation right now.')),
        );
      }
    }
  }

  Future<void> _confirmUnmatch(Map<String, dynamic> person) async {
    final otherUid = person['uid'] as String?;
    if (otherUid == null) return;
    final name = person['displayName']?.toString() ?? 'this connection';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End connection?'),
        content: Text(
          'Ending your connection with $name will close the conversation and revoke any Private Vault access in both directions. This cannot be undone automatically.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('End connection')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ConnectionService().endConnection(otherUid);
      if (!mounted) return;
      setState(() => _reloadKey = UniqueKey());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection with $name ended.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not end this connection right now.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: _reloadKey,
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('We could not load your connections right now.'),
          ));
        }
        final people = snapshot.data ?? [];
        if (people.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline, size: 56),
              SizedBox(height: 16),
              Text('No connections yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('When interest is mutual, your new connections will appear here.', textAlign: TextAlign.center),
            ]),
          ));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: people.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final person = people[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(person['displayName']?.toString() ?? 'Connection'),
              subtitle: Text(person['relationshipStructure']?.toString() ?? ''),
              onTap: () => _openChat(context, person),
              trailing: PopupMenuButton<String>(
                tooltip: 'Connection options',
                onSelected: (value) {
                  if (value == 'chat') _openChat(context, person);
                  if (value == 'unmatch') _confirmUnmatch(person);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'chat', child: Text('Open chat')),
                  PopupMenuItem(value: 'unmatch', child: Text('End connection')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
