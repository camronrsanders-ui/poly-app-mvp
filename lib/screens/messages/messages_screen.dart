import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/messaging_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Sign in to view messages.'));
    final service = MessagingService();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchConversations(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final participants = List<String>.from(data['participantUids'] ?? const []);
            final otherUid = participants.firstWhere((id) => id != uid, orElse: () => '');
            if (otherUid.isEmpty) return const SizedBox.shrink();
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('profiles').doc(otherUid).get(),
              builder: (context, profileSnap) {
                final profile = profileSnap.data?.data();
                final name = (profile?['displayName'] as String?)?.trim();
                return ListTile(
                  leading: CircleAvatar(child: Text((name?.isNotEmpty == true ? name![0] : '?').toUpperCase())),
                  title: Text(name?.isNotEmpty == true ? name! : 'Polycircle connection'),
                  subtitle: const Text('Open conversation'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(conversationId: doc.id, otherUid: otherUid, otherDisplayName: name ?? 'Connection'),
                  )),
                );
              },
            );
          },
        );
      },
    );
  }
}
