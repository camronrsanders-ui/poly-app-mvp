import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/messaging_service.dart';
import '../messages/chat_screen.dart';

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
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
            final p = people[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(p['displayName']?.toString() ?? 'Connection'),
              subtitle: Text(p['relationshipStructure']?.toString() ?? ''),
              trailing: const Icon(Icons.chat_bubble_outline),
              onTap: () => _openChat(context, p),
            );
          },
        );
      },
    );
  }
}
