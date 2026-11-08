import 'dart:async';

import 'package:flutter/material.dart';

import '../services/check_in_service.dart';
import '../theme/app_theme.dart';

String _relativeTime(int nowMs, int thenMs) {
  final diffMs = nowMs - thenMs;
  if (diffMs < 60_000) return 'just now';
  final minutes = diffMs ~/ 60_000;
  if (minutes < 60) return '${minutes}m ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return '${hours}h ago';
  return 'over a day ago';
}

/// The bilateral check-in card at the top of a Connection Space.
///
/// Both participants see the same card: their own current state, the
/// other person's current state, and one shared note with visible
/// attribution. States expire 24 hours after posting (enforced by the
/// backend projection and re-checked here via [CheckInSlot.isCurrentAt]),
/// so an expired state renders as "no current check-in" — never as a
/// stale state pinned to a person. There are deliberately no read
/// receipts, counts, or prompts to respond: posting a state never tells
/// anyone whether it was seen.
class CheckInCard extends StatefulWidget {
  const CheckInCard({
    super.key,
    required this.actions,
    required this.otherDisplayName,
    this.otherUid = '',
  });

  final CheckInActions actions;
  final String otherDisplayName;

  /// The other participant's uid when the caller already knows it; used
  /// only to attribute the shared note. Falls back to the snapshot's
  /// `otherUid` from the backend.
  final String otherUid;

  @override
  State<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<CheckInCard> {
  CheckInSnapshot? _snapshot;
  bool _loading = true;
  bool _busy = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.actions.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update the check-in right now.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _otherUid => widget.otherUid.isNotEmpty
      ? widget.otherUid
      : (_snapshot?.otherUid ?? '');

  Future<void> _showStatePicker() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final current = _snapshot?.currentMine(nowMs);
    final result = await showDialog<({String state, String note})>(
      context: context,
      builder: (_) => _StatePickerDialog(
        initialState: current?.state ?? checkInStateOptions.first.id,
        initialNote: current?.note ?? '',
      ),
    );
    if (result == null) return;
    await _run(
      () => widget.actions.setMyState(state: result.state, note: result.note),
    );
  }

  Future<void> _showNoteEditor() async {
    final existing = _snapshot?.sharedNote;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _SharedNoteDialog(
        initialText: existing?.text ?? '',
        isNew: existing == null,
      ),
    );
    if (text == null || text.isEmpty) return;
    await _run(() => widget.actions.setSharedNote(text));
  }

  @override
  Widget build(BuildContext context) {
    final semantic = PolycircleColors.of(context);
    return Card(
      key: const Key('check-in-card'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 20,
                  color: semantic.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'How are we doing right now?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text('Loading check-ins…'),
                  ],
                ),
              )
            else if (_loadError != null || _snapshot == null)
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: semantic.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Expanded(child: Text('Couldn’t load check-ins.')),
                  TextButton(
                    key: const Key('check-in-retry'),
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() => _loading = true);
                            unawaited(_load());
                          },
                    child: const Text('Retry'),
                  ),
                ],
              )
            else
              ..._buildLoaded(context, _snapshot!),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLoaded(BuildContext context, CheckInSnapshot snapshot) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final mine = snapshot.currentMine(nowMs);
    final other = snapshot.currentOther(nowMs);
    return [
      _SlotRow(
        key: const Key('check-in-my-state'),
        label: 'You',
        slot: mine,
        emptyText: 'No current check-in',
        nowMs: nowMs,
        actions: [
          TextButton(
            key: const Key('check-in-set-state'),
            onPressed: _busy ? null : _showStatePicker,
            child: Text(mine == null ? 'Check in' : 'Update'),
          ),
          if (mine != null)
            TextButton(
              key: const Key('check-in-clear-state'),
              onPressed: _busy ? null : () => _run(widget.actions.clearMyState),
              child: const Text('Clear'),
            ),
        ],
      ),
      const Divider(height: AppSpacing.md),
      _SlotRow(
        key: const Key('check-in-other-state'),
        label: widget.otherDisplayName,
        slot: other,
        emptyText: 'No current check-in',
        nowMs: nowMs,
        actions: const [],
      ),
      const Divider(height: AppSpacing.md),
      _buildSharedNote(context, snapshot),
    ];
  }

  Widget _buildSharedNote(BuildContext context, CheckInSnapshot snapshot) {
    final semantic = PolycircleColors.of(context);
    final note = snapshot.sharedNote;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return Column(
      key: const Key('check-in-shared-note'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shared note',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: semantic.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        if (note == null)
          Text(
            'No shared note yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: semantic.textSecondary,
                ),
          )
        else ...[
          Text(note.text, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            note.updatedByUid == _otherUid && _otherUid.isNotEmpty
                ? 'Last edited by ${widget.otherDisplayName} · '
                    '${_relativeTime(nowMs, note.updatedAtMs)}'
                : 'Last edited by you · '
                    '${_relativeTime(nowMs, note.updatedAtMs)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: semantic.textMuted,
                ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: const Key('check-in-edit-note'),
              onPressed: _busy ? null : _showNoteEditor,
              child: Text(note == null ? 'Add a shared note' : 'Edit'),
            ),
            if (note != null)
              TextButton(
                key: const Key('check-in-clear-note'),
                onPressed:
                    _busy ? null : () => _run(widget.actions.clearSharedNote),
                child: const Text('Clear'),
              ),
          ],
        ),
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    super.key,
    required this.label,
    required this.slot,
    required this.emptyText,
    required this.nowMs,
    required this.actions,
  });

  final String label;
  final CheckInSlot? slot;
  final String emptyText;
  final int nowMs;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final semantic = PolycircleColors.of(context);
    final current = slot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: semantic.textSecondary,
                    ),
              ),
            ),
            ...actions,
          ],
        ),
        if (current == null)
          Text(
            emptyText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: semantic.textSecondary,
                ),
          )
        else ...[
          Text(
            checkInStateLabel(current.state),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (current.note.isNotEmpty)
            Text(
              current.note,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          Text(
            'Posted ${_relativeTime(nowMs, current.updatedAtMs)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: semantic.textMuted,
                ),
          ),
        ],
      ],
    );
  }
}

/// State picker dialog. Owns its text controller so the controller is
/// disposed when the route unmounts, not while the pop transition is
/// still rebuilding the field.
class _StatePickerDialog extends StatefulWidget {
  const _StatePickerDialog({
    required this.initialState,
    required this.initialNote,
  });

  final String initialState;
  final String initialNote;

  @override
  State<_StatePickerDialog> createState() => _StatePickerDialogState();
}

class _StatePickerDialogState extends State<_StatePickerDialog> {
  late String _selected = widget.initialState;
  late final TextEditingController _noteController =
      TextEditingController(text: widget.initialNote);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('How are you doing right now?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (value) {
                if (value != null) setState(() => _selected = value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in checkInStateOptions)
                    RadioListTile<String>(
                      value: option.id,
                      title: Text(option.label),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('check-in-state-note-field'),
              controller: _noteController,
              maxLength: CheckInService.noteMaxLength,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Add a note (optional)',
              ),
            ),
            const Text(
              'Your check-in shows for 24 hours, then clears itself.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            (state: _selected, note: _noteController.text.trim()),
          ),
          child: const Text('Post check-in'),
        ),
      ],
    );
  }
}

/// Shared-note editor dialog; owns its text controller for the same
/// route-lifecycle reason as [_StatePickerDialog].
class _SharedNoteDialog extends StatefulWidget {
  const _SharedNoteDialog({required this.initialText, required this.isNew});

  final String initialText;
  final bool isNew;

  @override
  State<_SharedNoteDialog> createState() => _SharedNoteDialogState();
}

class _SharedNoteDialogState extends State<_SharedNoteDialog> {
  late final TextEditingController _noteController =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Add a shared note' : 'Edit shared note'),
      content: TextField(
        key: const Key('check-in-shared-note-field'),
        controller: _noteController,
        maxLength: CheckInService.noteMaxLength,
        maxLines: 3,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Shared note',
          helperText: 'Both of you can read and edit this note.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _noteController.text.trim()),
          child: const Text('Save note'),
        ),
      ],
    );
  }
}
