import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/connection_service.dart';
import '../../services/messaging_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _messages = MessagingService();
  final _connections = ConnectionService();
  late Future<Map<String, Map<String, dynamic>>> _connectionProfiles;

  @override
  void initState() {
    super.initState();
    _connectionProfiles = _loadConnectionProfiles();
  }

  Future<Map<String, Map<String, dynamic>>> _loadConnectionProfiles() async {
    final profiles = await _connections.loadConnections();
    return {
      for (final profile in profiles)
        if (profile['uid'] is String) profile['uid'] as String: profile,
    };
  }

  Future<void> _refreshConnectionProfiles() async {
    final next = _loadConnectionProfiles();
    setState(() => _connectionProfiles = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Sign in to view messages.'));

    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _connectionProfiles,
      builder: (context, profilesSnapshot) {
        final profiles = profilesSnapshot.data ?? const <String, Map<String, dynamic>>{};
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _messages.watchConversations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('We could not load your conversations. Please try again.'),
              ));
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline, size: 64),
                  SizedBox(height: 16),
                  Text('No conversations yet'),
                  SizedBox(height: 8),
                  Text('When you connect with someone, you can start a conversation here.', textAlign: TextAlign.center),
                ]),
              ));
            }

            return RefreshIndicator(
              onRefresh: _refreshConnectionProfiles,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final participants = List<String>.from(data['participantUids'] ?? const []);
                  final otherUid = participants.firstWhere((id) => id != uid, orElse: () => '');
                  if (otherUid.isEmpty) return const SizedBox.shrink();

                  // Full profile documents are owner-only. Display data for the
                  // other participant comes from the trusted connection-view
                  // callable rather than a cross-user Firestore profile read.
                  final profile = profiles[otherUid];
                  final rawName = profile?['displayName']?.toString().trim() ?? '';
                  final name = rawName.isEmpty ? 'Polycircle connection' : rawName;
                  final structure = profile?['relationshipStructure']?.toString().trim() ?? '';

                  return ListTile(
                    leading: CircleAvatar(child: Text(name.characters.first.toUpperCase())),
                    title: Text(name),
                    subtitle: Text(structure.isEmpty ? 'Open conversation' : structure),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: doc.id,
                        otherUid: otherUid,
                        otherDisplayName: name,
                      ),
                    )),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
