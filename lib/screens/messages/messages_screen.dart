import 'package:flutter/material.dart';

import '../../services/connection_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _connections = ConnectionService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadConversations();
  }

  Future<List<Map<String, dynamic>>> _loadConversations() async {
    final connections = await _connections.loadConnections();
    final conversations = connections.where((profile) {
      final id = profile['conversationId']?.toString().trim() ?? '';
      return id.isNotEmpty;
    }).toList(growable: false);

    conversations.sort((a, b) {
      final aTime = (a['lastMessageAtMs'] as num?)?.toInt() ?? 0;
      final bTime = (b['lastMessageAtMs'] as num?)?.toInt() ?? 0;
      return bTime.compareTo(aTime);
    });
    return conversations;
  }

  Future<void> _refresh() async {
    final next = _loadConversations();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'We could not load your conversations. Please try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: _refresh, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }

        final conversations = snapshot.data ?? const <Map<String, dynamic>>[];
        if (conversations.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline, size: 64),
                    SizedBox(height: 16),
                    Text('No conversations yet'),
                    SizedBox(height: 8),
                    Text(
                      'When you connect with someone, start a chat from the Connections tab.',
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final profile = conversations[index];
              final otherUid = profile['uid']?.toString() ?? '';
              final conversationId =
                  profile['conversationId']?.toString() ?? '';
              if (otherUid.isEmpty || conversationId.isEmpty) {
                return const SizedBox.shrink();
              }

              final rawName = profile['displayName']?.toString().trim() ?? '';
              final name = rawName.isEmpty ? 'Polycircle connection' : rawName;
              final structure =
                  profile['relationshipStructure']?.toString().trim() ?? '';

              return ListTile(
                leading: CircleAvatar(
                    child: Text(name.characters.first.toUpperCase())),
                title: Text(name),
                subtitle:
                    Text(structure.isEmpty ? 'Open conversation' : structure),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    conversationId: conversationId,
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
  }
}
