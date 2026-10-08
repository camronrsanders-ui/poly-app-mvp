import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/relationship_card_service.dart';

typedef RelationshipUidProvider = String? Function();

typedef RelationshipCardsWatcher = Stream<List<Map<String, dynamic>>> Function(
  String ownerUid,
);

typedef CreateRelationshipCardAction = Future<void> Function({
  required String ownerUid,
  required String label,
  required String connectionType,
  required String status,
  required String note,
  required String visibility,
  required String displayNameOptional,
  required int sortOrder,
});

typedef UpdateRelationshipCardAction = Future<void> Function({
  required String cardId,
  required String ownerUid,
  required Map<String, dynamic> values,
});

typedef RelationshipCardIdAction = Future<void> Function(String cardId);

typedef ReorderRelationshipCardsAction = Future<void> Function(
  List<Map<String, dynamic>> cards,
);

class RelationshipManagerScreen extends StatefulWidget {
  const RelationshipManagerScreen({
    super.key,
    this.uidProvider,
    this.watchCards,
    this.createCard,
    this.updateCard,
    this.deactivateCard,
    this.deleteCard,
    this.reorderCards,
  });

  final RelationshipUidProvider? uidProvider;
  final RelationshipCardsWatcher? watchCards;
  final CreateRelationshipCardAction? createCard;
  final UpdateRelationshipCardAction? updateCard;
  final RelationshipCardIdAction? deactivateCard;
  final RelationshipCardIdAction? deleteCard;
  final ReorderRelationshipCardsAction? reorderCards;

  @override
  State<RelationshipManagerScreen> createState() =>
      _RelationshipManagerScreenState();
}

class _RelationshipManagerScreenState extends State<RelationshipManagerScreen> {
  static const _connectionTypes = <String>[
    'nesting_partner',
    'anchor_partner',
    'primary_partner',
    'secondary_partner',
    'romantic_partner',
    'sexual_partner',
    'queerplatonic_partner',
    'comet_partner',
    'platonic_life_partner',
    'important_connection',
    'custom',
  ];
  static const _statuses = <String>['active', 'past', 'complicated'];
  static const _visibilities = <String>[
    'public',
    'matches_only',
    'private',
    'unnamed_public',
  ];

  RelationshipCardService? _service;

  RelationshipCardService get _fallbackService =>
      _service ??= RelationshipCardService();

  Stream<List<Map<String, dynamic>>> _watchCards(String uid) {
    final injected = widget.watchCards;
    return injected != null ? injected(uid) : _fallbackService.watchCards(uid);
  }

  Future<void> _createCard({
    required String ownerUid,
    required String label,
    required String connectionType,
    required String status,
    required String note,
    required String visibility,
    required String displayNameOptional,
    required int sortOrder,
  }) {
    final injected = widget.createCard;
    if (injected != null) {
      return injected(
        ownerUid: ownerUid,
        label: label,
        connectionType: connectionType,
        status: status,
        note: note,
        visibility: visibility,
        displayNameOptional: displayNameOptional,
        sortOrder: sortOrder,
      );
    }
    return _fallbackService.createCard(
      ownerUid: ownerUid,
      label: label,
      connectionType: connectionType,
      status: status,
      note: note,
      visibility: visibility,
      displayNameOptional: displayNameOptional,
      sortOrder: sortOrder,
    );
  }

  Future<void> _updateCard({
    required String cardId,
    required String ownerUid,
    required Map<String, dynamic> values,
  }) {
    final injected = widget.updateCard;
    if (injected != null) {
      return injected(
        cardId: cardId,
        ownerUid: ownerUid,
        values: values,
      );
    }
    return _fallbackService.updateCard(
      cardId: cardId,
      ownerUid: ownerUid,
      values: values,
    );
  }

  Future<void> _deactivateCard(String cardId) {
    final injected = widget.deactivateCard;
    return injected != null
        ? injected(cardId)
        : _fallbackService.deactivateCard(cardId);
  }

  Future<void> _deleteCard(String cardId) {
    final injected = widget.deleteCard;
    return injected != null
        ? injected(cardId)
        : _fallbackService.deleteCard(cardId);
  }

  Future<void> _reorderCards(List<Map<String, dynamic>> cards) {
    final injected = widget.reorderCards;
    return injected != null
        ? injected(cards)
        : _fallbackService.reorderCards(cards);
  }

  String _safeChoice(Object? raw, List<String> choices, String fallback) {
    final value = raw?.toString().trim() ?? '';
    return choices.contains(value) ? value : fallback;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final injectedUidProvider = widget.uidProvider;
    final uid = injectedUidProvider != null
        ? injectedUidProvider()
        : FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to manage your circle.'));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _watchCards(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StateMessage(
            icon: Icons.error_outline,
            title: 'We could not load your circle',
            text: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final cards = snapshot.data!;
        if (cards.isEmpty) {
          return _StateMessage(
            icon: Icons.hub_outlined,
            title: 'Build your circle',
            text:
                'Represent the relationships that matter to you. You control what other people can see.',
            actionLabel: 'Add relationship',
            onAction: () => _openEditor(uid: uid, sortOrder: 0),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                        'Your relationship cards can be public, connection-only, unnamed, or private.'),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        _openEditor(uid: uid, sortOrder: cards.length),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  final label = card['label']?.toString().trim() ?? '';
                  final initial = label.isEmpty
                      ? '?'
                      : label.characters.first.toUpperCase();
                  final cardId = card['id']?.toString() ?? '';
                  return Card(
                    key: ValueKey(cardId),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(initial)),
                      title: Text(label.isEmpty ? 'Relationship' : label),
                      subtitle: Text(_subtitle(card)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Move up',
                            onPressed: index == 0
                                ? null
                                : () => _moveCard(cards, index, index - 1),
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            tooltip: 'Move down',
                            onPressed: index == cards.length - 1
                                ? null
                                : () => _moveCard(cards, index, index + 1),
                            icon: const Icon(Icons.arrow_downward),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (cardId.isEmpty) {
                                _showError(
                                    'This relationship card could not be changed. Please refresh and try again.');
                                return;
                              }
                              try {
                                if (value == 'edit') {
                                  await _openEditor(
                                      uid: uid,
                                      existing: card,
                                      sortOrder: index);
                                } else if (value == 'hide') {
                                  await _deactivateCard(cardId);
                                } else if (value == 'delete') {
                                  final confirmed = await _confirmDelete();
                                  if (confirmed == true) {
                                    await _deleteCard(cardId);
                                  }
                                }
                              } catch (_) {
                                _showError(
                                    'That Circle change could not be saved. Please try again.');
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'hide', child: Text('Deactivate')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _openEditor(
                          uid: uid, existing: card, sortOrder: index),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _moveCard(
      List<Map<String, dynamic>> cards, int oldIndex, int newIndex) async {
    try {
      final reordered = [...cards];
      final item = reordered.removeAt(oldIndex);
      reordered.insert(newIndex, item);
      await _reorderCards(reordered);
    } catch (_) {
      _showError('Could not reorder your Circle right now.');
    }
  }

  String _subtitle(Map<String, dynamic> card) {
    final type = '${card['connectionType'] ?? ''}'.replaceAll('_', ' ');
    final visibility =
        '${card['visibility'] ?? 'private'}'.replaceAll('_', ' ');
    final name = '${card['displayNameOptional'] ?? ''}'.trim();
    return [if (name.isNotEmpty) name, type, visibility]
        .where((e) => e.isNotEmpty)
        .join(' • ');
  }

  Future<void> _openEditor({
    required String uid,
    Map<String, dynamic>? existing,
    required int sortOrder,
  }) async {
    var label = '${existing?['label'] ?? ''}';
    var displayName = '${existing?['displayNameOptional'] ?? ''}';
    var note = '${existing?['note'] ?? ''}';
    var type = _safeChoice(
        existing?['connectionType'], _connectionTypes, 'romantic_partner');
    var status = _safeChoice(existing?['status'], _statuses, 'active');
    var visibility =
        _safeChoice(existing?['visibility'], _visibilities, 'matches_only');
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(modalContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    existing == null ? 'Add relationship' : 'Edit relationship',
                    style: Theme.of(modalContext).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: label,
                  maxLength: 100,
                  onChanged: (value) => label = value,
                  decoration: const InputDecoration(
                      labelText: 'Label, e.g. Anchor partner'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: displayName,
                  maxLength: 100,
                  onChanged: (value) => displayName = value,
                  decoration: const InputDecoration(
                      labelText: 'Display name (optional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration:
                      const InputDecoration(labelText: 'Connection type'),
                  items: _connectionTypes
                      .map((v) => DropdownMenuItem(
                          value: v, child: Text(v.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (v) => setModalState(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statuses
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (v) => setModalState(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: visibility,
                  decoration:
                      const InputDecoration(labelText: 'Who can see this?'),
                  items: _visibilities
                      .map((v) => DropdownMenuItem(
                          value: v, child: Text(v.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (v) =>
                          setModalState(() => visibility = v ?? visibility),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: note,
                  maxLength: 1000,
                  maxLines: 3,
                  onChanged: (value) => note = value,
                  decoration:
                      const InputDecoration(labelText: 'Note (optional)'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (label.trim().isEmpty) {
                            ScaffoldMessenger.of(modalContext).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Add a label for this relationship.')),
                            );
                            return;
                          }
                          setModalState(() => saving = true);
                          try {
                            if (existing == null) {
                              await _createCard(
                                ownerUid: uid,
                                label: label,
                                connectionType: type,
                                displayNameOptional: displayName,
                                status: status,
                                note: note,
                                visibility: visibility,
                                sortOrder: sortOrder,
                              );
                            } else {
                              final cardId = existing['id']?.toString() ?? '';
                              if (cardId.isEmpty) {
                                throw StateError(
                                    'Missing relationship card ID.');
                              }
                              await _updateCard(
                                cardId: cardId,
                                ownerUid: uid,
                                values: {
                                  'label': label.trim(),
                                  'connectionType': type,
                                  'displayNameOptional': displayName.trim(),
                                  'status': status,
                                  'note': note.trim(),
                                  'visibility': visibility,
                                },
                              );
                            }
                            if (modalContext.mounted) {
                              Navigator.pop(modalContext);
                            }
                          } catch (_) {
                            if (modalContext.mounted) {
                              ScaffoldMessenger.of(modalContext).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Could not save this relationship. Please try again.')),
                              );
                              setModalState(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(existing == null
                          ? 'Add to my circle'
                          : 'Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete relationship card?'),
          content: const Text(
              'This permanently removes this card from your circle.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete')),
          ],
        ),
      );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage(
      {required this.icon,
      required this.title,
      required this.text,
      required this.actionLabel,
      required this.onAction});
  final IconData icon;
  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      );
}
