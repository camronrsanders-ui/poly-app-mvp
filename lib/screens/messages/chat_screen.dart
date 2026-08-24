import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/feature_flags.dart';
import '../../services/messaging_service.dart';
import '../../services/safety_service.dart';
import '../../services/shared_moments_service.dart';
import '../../services/ugc_text_policy.dart';
import '../../theme/app_theme.dart';
import '../../widgets/conversation_space_header.dart';
import 'shared_moments_screen.dart';
import 'shared_plans_screen.dart';

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
  final _sharedMoments = SharedMomentsService();
  final Set<String> _readUpdatesInFlight = {};
  final Set<String> _momentSavesInFlight = {};
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _queueMarkRead(String messageId, List<String> readBy, String uid) {
    if (readBy.contains(uid) || !_readUpdatesInFlight.add(messageId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _messages.markRead(messageId);
      } catch (_) {
        // A transient failure is safe to retry if a later snapshot/build still
        // shows the message as unread. Never block rendering on a read receipt.
      } finally {
        _readUpdatesInFlight.remove(messageId);
      }
    });
  }

  void _openSharedMoments() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedMomentsScreen(
          conversationId: widget.conversationId,
          otherDisplayName: widget.otherDisplayName,
        ),
      ),
    );
  }

  void _openSharedPlans() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedPlansScreen(
          conversationId: widget.conversationId,
          otherDisplayName: widget.otherDisplayName,
        ),
      ),
    );
  }

  Future<void> _saveMessageAsMoment(String messageId) async {
    final note = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save to Shared Moments?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This saves a reference to the message, not a copy of its text. If the original message becomes unavailable, its text is not preserved here.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 4,
                maxLength: 1200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Add a note (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save message'),
          ),
        ],
      ),
    );
    final noteText = note.text.trim();
    note.dispose();
    if (submitted != true || !_momentSavesInFlight.add(messageId)) return;

    try {
      await _sharedMoments.saveMessage(
        conversationId: widget.conversationId,
        sourceMessageId: messageId,
        note: noteText,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Shared Moments.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared Moments are not available to save yet.'),
          ),
        );
      }
    } finally {
      _momentSavesInFlight.remove(messageId);
    }
  }

  Future<void> _showMessageActions({
    required String messageId,
    required bool isMine,
  }) async {
    if (!FeatureFlags.sharedMomentsEnabled) {
      if (!isMine) {
        await _report(messageId: messageId);
      }
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('message-action-save-moment'),
                leading: const Icon(Icons.bookmark_add_outlined),
                title: const Text('Save to Shared Moments'),
                subtitle: const Text('Keep a reference to this message.'),
                onTap: () => Navigator.pop(context, 'save'),
              ),
              if (!isMine)
                ListTile(
                  key: const Key('message-action-report'),
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Report message'),
                  onTap: () => Navigator.pop(context, 'report'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'save') {
      await _saveMessageAsMoment(messageId);
    }
    if (action == 'report') {
      await _report(messageId: messageId);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await _messages.sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );
    } on UgcPolicyViolation catch (error) {
      // Keep rejected text editable so the member can remove the prohibited
      // content rather than losing their draft. Reports are a separate path and
      // are intentionally not passed through this posting filter.
      if (mounted && _controller.text.isEmpty) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    } catch (_) {
      // Do not make a transient network/backend error eat the user's draft.
      // If they already started typing a new message while this request was in
      // flight, leave that newer text alone instead of overwriting it.
      if (mounted && _controller.text.isEmpty) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Message failed to send. Your text was kept so you can retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _block() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block ${widget.otherDisplayName}?'),
        content: const Text(
          'They will no longer be able to interact with you through Polycircle. You can manage blocks later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _safety.blockUser(widget.otherUid);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not block this user right now.')),
        );
      }
    }
  }

  Future<void> _report({String? messageId}) async {
    const reasons = <String, String>{
      'harassment': 'Harassment',
      'threats_violence': 'Threats or violence',
      'child_safety': 'Child safety / underage concern',
      'sexual_content': 'Sexual content or solicitation',
      'nonconsensual_content': 'Non-consensual content',
      'hate_speech': 'Hate speech',
      'fake_profile': 'Fake profile',
      'misrepresentation': 'Misrepresentation',
      'spam': 'Spam or scam',
      'other': 'Other',
    };
    var reason = reasons.keys.first;
    final details = TextEditingController();
    final reportingMessage = messageId != null;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            reportingMessage
                ? 'Report this message'
                : 'Report ${widget.otherDisplayName}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reportingMessage) ...[
                  const Text(
                    'The report will include a protected reference to this message so moderators can review the correct content. The message text is not copied into your report details automatically.',
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  items: reasons.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setLocalState(() => reason = value ?? reason),
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Details (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) {
      try {
        await _safety.reportUser(
          reportedUid: widget.otherUid,
          reason: reason,
          details: details.text,
          contentType: reportingMessage ? 'message' : 'account',
          contentId: messageId,
          conversationId: reportingMessage ? widget.conversationId : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Report submitted. Thank you for helping protect the community.',
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not submit the report right now.'),
            ),
          );
        }
      }
    }
    details.dispose();
  }

  void _retryMessages() {
    if (mounted) setState(() {});
  }

  String _formatMessageTime(Object? rawTimestamp) {
    if (rawTimestamp is! Timestamp) return '';
    final value = rawTimestamp.toDate().toLocal();
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
            ? value.hour - 12
            : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: _ChatStateView(
          icon: Icons.lock_outline_rounded,
          title: 'Sign in to chat',
          message: 'Your conversations are available after you sign in.',
        ),
      );
    }

    final semantic = PolycircleColors.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ConversationSpaceHeader(
          otherDisplayName: widget.otherDisplayName,
        ),
        actions: [
          if (FeatureFlags.sharedMomentsEnabled)
            IconButton(
              key: const Key('conversation-shared-moments'),
              onPressed: _openSharedMoments,
              tooltip: 'Shared moments',
              icon: const Icon(Icons.bookmark_outline_rounded),
            ),
          if (FeatureFlags.sharedPlansEnabled)
            IconButton(
              key: const Key('conversation-shared-plans'),
              onPressed: _openSharedPlans,
              tooltip: 'Plans',
              icon: const Icon(Icons.event_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Conversation safety options',
            onSelected: (value) {
              if (value == 'report') _report();
              if (value == 'block') _block();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report person')),
              PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(color: semantic.border),
                  ),
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messages.watchMessages(widget.conversationId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _ChatLoadingState();
                    }
                    if (snapshot.hasError) {
                      return _ChatStateView(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load messages',
                        message:
                            'Your conversation is still here. Check your connection and try again.',
                        action: FilledButton.tonalIcon(
                          onPressed: _retryMessages,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const _ChatStateView(
                        icon: Icons.waving_hand_outlined,
                        title: 'Start your conversation',
                        message:
                            'Start with something genuine. Your connection does not have to fit a traditional script.',
                      );
                    }
                    return ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final senderUid = data['senderUid'] as String? ?? '';
                        final isMine = senderUid == uid;
                        final isDeleted = data['isDeleted'] == true;
                        final text = isDeleted
                            ? 'Message removed'
                            : (data['text'] as String? ?? '');
                        final readBy = List<String>.from(
                          data['readBy'] ?? const [],
                        );
                        if (!isMine) {
                          _queueMarkRead(doc.id, readBy, uid);
                        }
                        final canLongPress = !isDeleted &&
                            (FeatureFlags.sharedMomentsEnabled || !isMine);
                        return _MessageBubble(
                          text: text,
                          timestamp: _formatMessageTime(data['createdAt']),
                          isMine: isMine,
                          isDeleted: isDeleted,
                          isRead: isMine && readBy.contains(widget.otherUid),
                          onLongPress: canLongPress
                              ? () => _showMessageActions(
                                    messageId: doc.id,
                                    isMine: isMine,
                                  )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            _MessageComposer(
              controller: _controller,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.timestamp,
    required this.isMine,
    required this.isDeleted,
    required this.isRead,
    this.onLongPress,
  });

  final String text;
  final String timestamp;
  final bool isMine;
  final bool isDeleted;
  final bool isRead;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = PolycircleColors.of(context);
    final background = isMine ? scheme.primary : semantic.surfaceRaised;
    final foreground = isMine ? scheme.onPrimary : semantic.textPrimary;
    final metadataColor = isMine
        ? scheme.onPrimary.withValues(alpha: 0.84)
        : semantic.textSecondary;
    final border = isMine ? Colors.transparent : semantic.border;

    final statusLabel = isMine ? (isRead ? 'Read' : 'Sent') : '';
    final semanticsParts = <String>[
      isMine ? 'You' : 'Received message',
      text,
      if (timestamp.isNotEmpty) timestamp,
      if (statusLabel.isNotEmpty) statusLabel,
    ];

    return Semantics(
      label: semanticsParts.join(', '),
      button: onLongPress != null,
      hint: onLongPress == null ? null : 'Long press for message actions',
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
              minHeight: AppTheme.minimumTapTarget,
            ),
            margin: EdgeInsets.only(
              bottom: AppSpacing.xs,
              left: isMine ? AppSpacing.xxxl : 0,
              right: isMine ? 0 : AppSpacing.xxxl,
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: border),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadius.lg),
                topRight: const Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(isMine ? AppRadius.lg : 6),
                bottomRight: Radius.circular(isMine ? 6 : AppRadius.lg),
              ),
              boxShadow: isMine
                  ? null
                  : [
                      BoxShadow(
                        color: semantic.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: foreground,
                    fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                    height: 1.35,
                  ),
                ),
                if (timestamp.isNotEmpty || isMine) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timestamp.isNotEmpty)
                        Text(
                          timestamp,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: metadataColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (timestamp.isNotEmpty && isMine)
                        const SizedBox(width: AppSpacing.xs),
                      if (isMine) ...[
                        Icon(
                          isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 15,
                          color: metadataColor,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          isRead ? 'Read' : 'Sent',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: metadataColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final semantic = PolycircleColors.of(context);
    return Material(
      color: semantic.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: semantic.border)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('conversation-message-composer'),
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            SizedBox.square(
              dimension: AppTheme.minimumTapTarget,
              child: IconButton.filled(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                tooltip: 'Send message',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatLoadingState extends StatelessWidget {
  const _ChatLoadingState();

  @override
  Widget build(BuildContext context) {
    final semantic = PolycircleColors.of(context);
    return Semantics(
      label: 'Loading messages',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _LoadingBubble(
            alignment: Alignment.centerLeft,
            width: 190,
            color: semantic.surfaceRaised,
          ),
          const SizedBox(height: AppSpacing.sm),
          _LoadingBubble(
            alignment: Alignment.centerRight,
            width: 230,
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LoadingBubble(
            alignment: Alignment.centerLeft,
            width: 150,
            color: semantic.surfaceRaised,
          ),
          const SizedBox(height: AppSpacing.xl),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble({
    required this.alignment,
    required this.width,
    required this.color,
  });

  final Alignment alignment;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: width,
        height: 58,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

class _ChatStateView extends StatelessWidget {
  const _ChatStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = PolycircleColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 34,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: semantic.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: semantic.textSecondary,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
