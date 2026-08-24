import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

import '../../services/connection_service.dart';
import '../../theme/app_theme.dart';
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

  String _previewFor(Map<String, dynamic> profile) {
    for (final key in const [
      'lastMessagePreview',
      'lastMessageText',
      'lastMessage',
    ]) {
      final value = profile[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    final structure = profile['relationshipStructure']?.toString().trim() ?? '';
    return structure.isEmpty ? 'Open conversation' : structure;
  }

  String _formatConversationTime(Object? rawMillis) {
    if (rawMillis is! num) return '';
    final millis = rawMillis.toInt();
    if (millis <= 0) return '';

    final value = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final difference = today.difference(date).inDays;

    if (difference == 0) {
      final hour = value.hour == 0
          ? 12
          : value.hour > 12
              ? value.hour - 12
              : value.hour;
      final minute = value.minute.toString().padLeft(2, '0');
      final period = value.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }
    if (difference == 1) return 'Yesterday';
    if (difference >= 0 && difference < 7) {
      return const [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ][value.weekday - 1];
    }
    return '${value.month}/${value.day}/${value.year.toString().substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _ConversationLoadingState();
        }
        if (snapshot.hasError) {
          return _ConversationStateView(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load conversations',
            message:
                'Your connections are still safe. Check your connection and try again.',
            action: FilledButton.tonalIcon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          );
        }

        final conversations = snapshot.data ?? const <Map<String, dynamic>>[];
        if (conversations.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              children: const [
                SizedBox(height: 132),
                _ConversationStateView(
                  icon: Icons.forum_outlined,
                  title: 'No conversations yet',
                  message:
                      'When you connect with someone, start a chat from the Connections tab.',
                  inline: true,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xl,
            ),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
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
              final preview = _previewFor(profile);
              final timestamp =
                  _formatConversationTime(profile['lastMessageAtMs']);

              return _ConversationRow(
                name: name,
                preview: preview,
                timestamp: timestamp,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(
                      conversationId: conversationId,
                      otherUid: otherUid,
                      otherDisplayName: name,
                    ),
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

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.name,
    required this.preview,
    required this.timestamp,
    required this.onTap,
  });

  final String name;
  final String preview;
  final String timestamp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = PolycircleColors.of(context);
    final initial = name.characters.first.toUpperCase();

    return Semantics(
      button: true,
      label: [
        'Conversation with $name',
        preview,
        if (timestamp.isNotEmpty) timestamp,
      ].join(', '),
      child: Material(
        color: semantic.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: semantic.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.brandPurple, AppTheme.accentPink],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: semantic.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: semantic.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (timestamp.isNotEmpty)
                        Text(
                          timestamp,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: semantic.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: semantic.textMuted,
                        semanticLabel: 'Open conversation',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationLoadingState extends StatelessWidget {
  const _ConversationLoadingState();

  @override
  Widget build(BuildContext context) {
    final semantic = PolycircleColors.of(context);
    return Semantics(
      label: 'Loading conversations',
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) => Container(
          height: 80,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: semantic.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: semantic.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: semantic.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 130,
                      decoration: BoxDecoration(
                        color: semantic.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      height: 11,
                      width: 210,
                      decoration: BoxDecoration(
                        color: semantic.surfaceRaised,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationStateView extends StatelessWidget {
  const _ConversationStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.inline = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = PolycircleColors.of(context);
    final content = Column(
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
          child: Icon(icon, size: 34, color: theme.colorScheme.primary),
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
    );

    if (inline) return content;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: content,
      ),
    );
  }
}
