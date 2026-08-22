import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/feature_flags.dart';
import '../../services/shared_moments_service.dart';

class SharedMomentsScreen extends StatefulWidget {
  const SharedMomentsScreen({
    super.key,
    required this.conversationId,
    required this.otherDisplayName,
  });

  final String conversationId;
  final String otherDisplayName;

  @override
  State<SharedMomentsScreen> createState() => _SharedMomentsScreenState();
}

class _SharedMomentsScreenState extends State<SharedMomentsScreen> {
  final SharedMomentsService _service = SharedMomentsService();
  List<SharedMoment> _moments = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (FeatureFlags.sharedMomentsEnabled) {
      _reload();
    } else {
      _loading = false;
    }
  }

  Future<void> _reload() async {
    if (!FeatureFlags.sharedMomentsEnabled) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final moments = await _service.list(
        conversationId: widget.conversationId,
      );
      if (!mounted) return;
      setState(() => _moments = moments);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load shared moments right now.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateMenu() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Save a shared moment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Keep something you intentionally want to remember together.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Write a note'),
                subtitle: const Text('Save a short memory or thought.'),
                onTap: () => Navigator.pop(context, 'note'),
              ),
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: const Text('Remember a place'),
                subtitle: const Text('Use a name only — no precise location.'),
                onTap: () => Navigator.pop(context, 'place'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || kind == null) return;
    await _createMoment(kind);
  }

  Future<void> _createMoment(String kind) async {
    final title = TextEditingController();
    final note = TextEditingController();
    final place = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(kind == 'place' ? 'Remember a place' : 'Write a note'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              if (kind == 'place') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: place,
                  maxLength: 160,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Place name',
                    helperText: 'No address or precise coordinates required.',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 5,
                maxLength: 1200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
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
            child: const Text('Save moment'),
          ),
        ],
      ),
    );

    final titleText = title.text.trim();
    final noteText = note.text.trim();
    final placeText = place.text.trim();
    title.dispose();
    note.dispose();
    place.dispose();

    if (submitted != true || _saving) return;
    if (titleText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a title before saving.')),
        );
      }
      return;
    }
    if (kind == 'place' && placeText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a place name before saving.')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      if (kind == 'place') {
        await _service.createPlace(
          conversationId: widget.conversationId,
          title: titleText,
          placeLabel: placeText,
          note: noteText,
        );
      } else {
        await _service.createNote(
          conversationId: widget.conversationId,
          title: titleText,
          note: noteText,
        );
      }
      await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared Moments are not available to save yet.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(SharedMoment moment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this moment?'),
        content: const Text(
          'This removes the shared-history entry. It does not delete the original chat message if this moment references one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(
        conversationId: widget.conversationId,
        momentId: moment.momentId,
      );
      await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove this moment right now.'),
          ),
        );
      }
    }
  }

  IconData _iconFor(String kind) {
    return switch (kind) {
      'place' => Icons.place_outlined,
      'message' => Icons.chat_bubble_outline_rounded,
      'photo' => Icons.photo_outlined,
      _ => Icons.auto_awesome_outlined,
    };
  }

  String _savedByLabel(SharedMoment moment, String? uid) {
    if (uid == null) return 'Saved in this conversation';
    return moment.creatorUid == uid
        ? 'Saved by you'
        : 'Saved by ${widget.otherDisplayName}';
  }

  Widget _subtitleFor(SharedMoment moment, String? uid) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    if (moment.kind == 'message') {
      if (moment.sourceMessagePreview.isNotEmpty) {
        children.add(
          Text(
            '“${moment.sourceMessagePreview}”',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        );
        children.add(const SizedBox(height: 2));
        children.add(
          Text(
            '— ${moment.sourceMessageFromCaller ? 'You' : widget.otherDisplayName}',
            style: theme.textTheme.bodySmall,
          ),
        );
      } else {
        children.add(const Text('Original message unavailable'));
      }
    }
    if (moment.placeLabel.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 4));
      children.add(Text(moment.placeLabel));
    }
    if (moment.note.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 4));
      children.add(
        Text(
          moment.note,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (children.isNotEmpty) children.add(const SizedBox(height: 4));
    children.add(
      Text(
        _savedByLabel(moment, uid),
        style: theme.textTheme.labelSmall,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.sharedMomentsEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shared moments')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Shared Moments are still being prepared for a future Polycircle update.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Shared moments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _showCreateMenu,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Save moment'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A history you choose together',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Notes, places, and meaningful messages you intentionally save with ${widget.otherDisplayName}. Nothing is saved automatically.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _reload,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_moments.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No shared moments yet. Save only the things you both want to keep close.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final moment = _moments[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _moments.length - 1 ? 0 : 10,
                      ),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            10,
                            8,
                            10,
                          ),
                          leading: CircleAvatar(
                            child: Icon(_iconFor(moment.kind)),
                          ),
                          title: Text(moment.title),
                          subtitle: _subtitleFor(moment, uid),
                          trailing: uid != null && moment.creatorUid == uid
                              ? IconButton(
                                  onPressed: () => _delete(moment),
                                  tooltip: 'Remove shared moment',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }, childCount: _moments.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
