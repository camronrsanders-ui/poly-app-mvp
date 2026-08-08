import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/messaging_service.dart';
import '../../services/safety_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUid,
    required this.otherDisplayName,
  });

  final String conversationId;
  final String otherUid;
  final String otherDisplayName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _messages = MessagingService();
  final _safety = SafetyService();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final text = _controller.text;
      _controller.clear();
      await _messages.sendMessage(
        conversationId: widget.conversationId,
        senderUid: uid,
        text: text,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message failed to send. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _block() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block ${widget.otherDisplayName}?'),
        content: const Text('They will no longer be able to interact with you through Polycircle. You can manage blocks later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _safety.blockUser(blockerUid: uid, blockedUid: widget.otherUid);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _report() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    const reasons = [
      'harassment',
      'fake_profile',
      'hate_speech',
      'misrepresentation',
      'spam',
      'nonconsensual_content',
      'other',
    ];
    var reason = reasons.first;
    final details = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('Report ${widget.otherDisplayName}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: reason,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r.replaceAll('_', ' ')))).toList(),
                onChanged: (v) => setLocalState(() => reason = v ?? reason),
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: details,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Details (optional)'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit report')),
          ],
        ),
      ),
    );
    if (submitted == true) {
      await _safety.reportUser(
        reporterUid: uid,
        reportedUid: widget.otherUid,
        reason: reason,
        details: details.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you for helping protect the community.')),
        );
      }
    }
    details.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Sign in to chat.')));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherDisplayName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _report();
              if (value == 'block') _block();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report')),
              PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messages.watchMessages(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Could not load messages.'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Start with something genuine. Your connection does not have to fit a traditional script.'),
                    ));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final senderUid = data['senderUid'] as String? ?? '';
                      final isMine = senderUid == uid;
                      final text = data['isDeleted'] == true ? 'Message removed' : (data['text'] as String? ?? '');
                      if (!isMine) {
                        final readBy = List<String>.from(data['readBy'] ?? const []);
                        if (!readBy.contains(uid)) {
                          _messages.markRead(doc.id, uid);
                        }
                      }
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(text),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(hintText: 'Message…'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  tooltip: 'Send message',
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
