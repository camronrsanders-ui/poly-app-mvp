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
///
/// The card renders collapsed to a one-line summary by default (H-5):
/// the summary still shows both current state labels, so collapsing
/// hides controls, not information, and the conversation keeps the
/// viewport. Expansion is session-only and never automatic.
///
/// The card is not live (H-4): check-in reads stay behind the backend
/// callables so the compliance and block guards run on every read,
/// which rules out a client-side listener. It reloads after the user's
/// own actions, when [refreshListenable] fires, and stamps each load
/// with an "Updated …" cue so stale data never presents as current.
class CheckInCard extends StatefulWidget {
  const CheckInCard({
    super.key,
    required this.actions,
    required this.otherDisplayName,
    this.otherUid = '',
    this.refreshListenable,
  });

  final CheckInActions actions;
  final String otherDisplayName;

  /// The other participant's uid when the caller already knows it; used
  /// only to attribute the shared note. Falls back to the snapshot's
  /// `otherUid` from the backend.
  final String otherUid;

  /// Optional external refresh signal (H-4). When it notifies, the card
  /// reloads. The chat screen bumps it on app resume, on return from a
  /// pushed route, and (debounced) when the other participant sends a
  /// message — the event-driven substitute for the listener this data
  /// deliberately cannot have.
  final Listenable? refreshListenable;

  @override
  State<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<CheckInCard> {
  CheckInSnapshot? _snapshot;
  bool _loading = true;
  bool _busy = false;
  Object? _loadError;

  /// Session-only expansion (H-5). Starts collapsed on every chat-open;
  /// nothing persists it, and the card never expands itself.
  bool _expanded = false;

  /// When the last successful load completed; drives the "Updated …"
  /// as-of cue (H-4).
  int? _loadedAtMs;

  Timer? _relativeTimeTicker;

  @override
  void initState() {
    super.initState();
    widget.refreshListenable?.addListener(_onRefreshSignal);
    // Relative labels ("Posted 2h ago", "Updated 4m ago") are computed
    // at build time from stored timestamps; without a periodic rebuild
    // they would freeze at whatever they said when the card last
    // loaded. Thirty seconds keeps them honest at minute granularity.
    _relativeTimeTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) setState(() {});
      },
    );
    unawaited(_load());
  }

  @override
  void didUpdateWidget(CheckInCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_onRefreshSignal);
      widget.refreshListenable?.addListener(_onRefreshSignal);
    }
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_onRefreshSignal);
    _relativeTimeTicker?.cancel();
    super.dispose();
  }

  void _onRefreshSignal() {
    if (!mounted) return;
    unawaited(_load());
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.actions.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _loadError = null;
        _loadedAtMs = DateTime.now().millisecondsSinceEpoch;
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

  /// Clearing the shared note erases it for both participants with no
  /// trace (M-14), so it asks first — unlike clearing your own state,
  /// which affects only you and stays one tap.
  Future<void> _confirmClearSharedNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear the shared note?'),
        content: const Text(
          'This clears the note for both of you, and it cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('check-in-clear-note-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear note'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(widget.actions.clearSharedNote);
  }

  @override
  Widget build(BuildContext context) {
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
        child: _expanded ? _buildExpanded(context) : _buildCollapsed(context),
      ),
    );
  }

  /// The expanded card: the header, the as-of cue under it, then the
  /// full slot rows and shared note — the original layout, unchanged
  /// inside.
  Widget _buildExpanded(BuildContext context) {
    final semantic = PolycircleColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: const Key('check-in-toggle'),
          onTap: _toggleExpanded,
          child: Row(
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
              Icon(
                Icons.expand_less_rounded,
                size: 20,
                color: semantic.textSecondary,
              ),
            ],
          ),
        ),
        if (_loadedAtMs != null && _loadError == null && !_loading) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            key: const Key('check-in-updated'),
            'Updated ${_relativeTime(
              DateTime.now().millisecondsSinceEpoch,
              _loadedAtMs!,
            )}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: semantic.textMuted,
                ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        _buildBody(context),
      ],
    );
  }

  /// The collapsed card (H-5): a single tappable row — both current
  /// state labels, a shared-note indicator when a note exists, the
  /// as-of cue, and the expand chevron. Loading and error states keep
  /// their honest one-line forms here too.
  Widget _buildCollapsed(BuildContext context) {
    final semantic = PolycircleColors.of(context);
    return InkWell(
      key: const Key('check-in-toggle'),
      onTap: _toggleExpanded,
      child: Row(
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 20,
            color: semantic.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          if (_loading) ...[
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Expanded(child: Text('Loading check-ins…')),
          ] else if (_loadError != null || _snapshot == null) ...[
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
          ] else ...[
            Expanded(child: _buildSummaryText(context, _snapshot!)),
            if (_snapshot!.sharedNote != null) ...[
              Icon(
                Icons.sticky_note_2_outlined,
                size: 16,
                color: semantic.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (_loadedAtMs != null) ...[
              Text(
                key: const Key('check-in-updated'),
                'Updated ${_relativeTime(
                  DateTime.now().millisecondsSinceEpoch,
                  _loadedAtMs!,
                )}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: semantic.textMuted,
                    ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ],
          Icon(
            Icons.expand_more_rounded,
            size: 20,
            color: semantic.textSecondary,
          ),
        ],
      ),
    );
  }

  /// The one-line collapsed summary. An expired slot reads as "—",
  /// never as its stale label; with nothing current and no note, the
  /// line is an invitation instead of two dashes.
  Widget _buildSummaryText(BuildContext context, CheckInSnapshot snapshot) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final mine = snapshot.currentMine(nowMs);
    final other = snapshot.currentOther(nowMs);
    final empty =
        mine == null && other == null && snapshot.sharedNote == null;
    return Text(
      key: const Key('check-in-summary'),
      empty
          ? 'Check in — how are we doing?'
          : 'You: ${mine == null ? '—' : checkInStateLabel(mine.state)}'
              ' · ${widget.otherDisplayName}: '
              '${other == null ? '—' : checkInStateLabel(other.state)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildBody(BuildContext context) {
    final semantic = PolycircleColors.of(context);
    if (_loading) {
      return const Padding(
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
      );
    }
    if (_loadError != null || _snapshot == null) {
      return Row(
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
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _buildLoaded(context, _snapshot!),
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
                onPressed: _busy ? null : _confirmClearSharedNote,
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
            const Text('Your partner will see this note'),
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
