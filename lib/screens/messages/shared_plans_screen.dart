import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/feature_flags.dart';
import '../../services/shared_plans_service.dart';

class SharedPlansScreen extends StatefulWidget {
  const SharedPlansScreen({
    super.key,
    required this.conversationId,
    required this.otherDisplayName,
  });

  final String conversationId;
  final String otherDisplayName;

  @override
  State<SharedPlansScreen> createState() => _SharedPlansScreenState();
}

class _SharedPlansScreenState extends State<SharedPlansScreen> {
  final SharedPlansService _service = SharedPlansService();
  List<SharedPlan> _plans = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (FeatureFlags.sharedPlansEnabled) {
      _reload();
    } else {
      _loading = false;
    }
  }

  Future<void> _reload() async {
    if (!FeatureFlags.sharedPlansEnabled) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await _service.list(conversationId: widget.conversationId);
      if (!mounted) return;
      setState(() => _plans = plans);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load plans right now.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _dateFor(SharedPlan plan) {
    final millis = plan.plannedForMs;
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  DateTime? _cancelledAtFor(SharedPlan plan) {
    final millis = plan.cancelledAtMs;
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  String _formatDateTime(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(value);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '$date • $time';
  }

  String _cancelledStatusLabel(BuildContext context, SharedPlan plan) {
    final cancelledAt = _cancelledAtFor(plan);
    if (cancelledAt == null) return 'Cancelled';
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(cancelledAt);
    return 'Cancelled • $date';
  }

  String _plannedByLabel(SharedPlan plan, String? uid) {
    if (uid == null || plan.creatorUid.isEmpty) {
      return 'Planned in this conversation';
    }
    return plan.creatorUid == uid
        ? 'Planned by you'
        : 'Planned by ${widget.otherDisplayName}';
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    // Stay comfortably inside the backend's rolling two-year maximum even
    // when the local picker uses midnight and the server compares exact time.
    final lastDate = firstDate.add(const Duration(days: 729));
    var safeInitial = initial;
    if (safeInitial.isBefore(firstDate)) safeInitial = firstDate;
    if (safeInitial.isAfter(lastDate)) safeInitial = lastDate;

    final date = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (!mounted || date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _editPlan({SharedPlan? plan}) async {
    final editing = plan != null;
    final title = TextEditingController(text: plan?.title ?? '');
    final place = TextEditingController(text: plan?.placeLabel ?? '');
    final note = TextEditingController(text: plan?.note ?? '');
    var plannedFor = plan == null
        ? DateTime.now().add(const Duration(days: 1))
        : (_dateFor(plan) ?? DateTime.now().add(const Duration(days: 1)));

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(editing ? 'Edit plan' : 'Make a plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Plan'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Date and time'),
                  subtitle: Text(_formatDateTime(context, plannedFor)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final selected = await _pickDateTime(plannedFor);
                    if (selected != null) {
                      setLocalState(() => plannedFor = selected);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: place,
                  maxLength: 160,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Place (optional)',
                    helperText: 'Use a name only — no precise location needed.',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 1200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
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
              child: Text(editing ? 'Save changes' : 'Create plan'),
            ),
          ],
        ),
      ),
    );

    final titleText = title.text.trim();
    final placeText = place.text.trim();
    final noteText = note.text.trim();
    title.dispose();
    place.dispose();
    note.dispose();

    if (submitted != true || _saving) return;
    if (titleText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a plan title before saving.')),
        );
      }
      return;
    }
    if (!plannedFor.isAfter(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a future date and time.')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      if (editing) {
        await _service.update(
          conversationId: widget.conversationId,
          planId: plan.planId,
          title: titleText,
          plannedFor: plannedFor,
          placeLabel: placeText,
          note: noteText,
        );
      } else {
        await _service.create(
          conversationId: widget.conversationId,
          title: titleText,
          plannedFor: plannedFor,
          placeLabel: placeText,
          note: noteText,
        );
      }
      await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plans are not available to save yet.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel(SharedPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this plan?'),
        content: const Text(
          'The plan will stay in your shared history marked as cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel plan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.cancel(
        conversationId: widget.conversationId,
        planId: plan.planId,
      );
      await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not cancel this plan right now.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.sharedPlansEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plans')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Plans are still being prepared for a future Polycircle update.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _editPlan(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Make a plan'),
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
                      'Make something to look forward to',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Simple plans with ${widget.otherDisplayName}: what, when, and an optional place or note. No automatic calendar or location sharing.',
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
            else if (_plans.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No plans yet. When you are ready, make one together from this conversation.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList.separated(
                  itemCount: _plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    final date = _dateFor(plan);
                    final mine = uid != null && plan.creatorUid == uid;
                    final cancelled = plan.status == 'cancelled';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  child: Icon(Icons.event_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plan.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              decoration: cancelled
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                      ),
                                      if (date != null) ...[
                                        const SizedBox(height: 4),
                                        Text(_formatDateTime(context, date)),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        _plannedByLabel(plan, uid),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (mine && !cancelled)
                                  PopupMenuButton<String>(
                                    tooltip: 'Plan options',
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editPlan(plan: plan);
                                      }
                                      if (value == 'cancel') {
                                        _cancel(plan);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit plan'),
                                      ),
                                      PopupMenuItem(
                                        value: 'cancel',
                                        child: Text('Cancel plan'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if (plan.placeLabel.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.place_outlined, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(plan.placeLabel)),
                                ],
                              ),
                            ],
                            if (plan.note.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(plan.note),
                            ],
                            if (cancelled) ...[
                              const SizedBox(height: 12),
                              Chip(
                                avatar: const Icon(
                                  Icons.block_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _cancelledStatusLabel(context, plan),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
