import 'package:flutter/material.dart';

import '../../services/circle_view_service.dart';
import '../../services/connection_service.dart';
import '../../services/safety_service.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({
    super.key,
    required this.profile,
  });

  final Map<String, dynamic> profile;

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final _connections = ConnectionService();
  final _safety = SafetyService();
  final _circle = CircleViewService();
  bool _acting = false;

  String get _uid => widget.profile['uid']?.toString() ?? '';
  String _text(String key) => widget.profile[key]?.toString().trim() ?? '';

  List<String> _strings(String key) {
    final raw = widget.profile[key];
    if (raw is! List) return const [];
    return raw.whereType<String>().where((item) => item.trim().isNotEmpty).toList(growable: false);
  }

  Future<void> _like() async {
    if (_uid.isEmpty || _acting) return;
    setState(() => _acting = true);
    try {
      final matched = await _connections.likeUser(_uid);
      if (!mounted) return;
      Navigator.of(context).pop(matched ? 'matched' : 'liked');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send interest right now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _block() async {
    if (_uid.isEmpty || _acting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text(
          'They will no longer be able to interact with you. Any existing match, chat access, and private-media sharing are revoked.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acting = true);
    try {
      await _safety.blockUser(_uid);
      if (!mounted) return;
      Navigator.of(context).pop('blocked');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not block this person right now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _report() async {
    if (_uid.isEmpty || _acting) return;
    const reasons = <String, String>{
      'harassment': 'Harassment',
      'fake_profile': 'Fake profile',
      'hate_speech': 'Hate speech',
      'misrepresentation': 'Misrepresentation',
      'spam': 'Spam',
      'nonconsensual_content': 'Non-consensual content',
      'other': 'Other',
    };
    var reason = 'harassment';
    final details = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: reasons.entries
                    .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                    .toList(growable: false),
                onChanged: (value) => setDialogState(() => reason = value ?? 'harassment'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: details,
                maxLength: 2000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  hintText: 'Share only what is useful for the safety review.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit report')),
          ],
        ),
      ),
    );

    final detailText = details.text.trim();
    details.dispose();
    if (submitted != true || !mounted) return;

    setState(() => _acting = true);
    try {
      await _safety.reportUser(reportedUid: _uid, reason: reason, details: detailText);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you for helping keep Polycircle safer.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit the report right now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Widget _chips(List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) => Chip(label: Text(value))).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _text('displayName').isEmpty ? 'Profile' : _text('displayName');
    final age = widget.profile['age'] is num ? (widget.profile['age'] as num).toInt() : null;
    final location = [_text('city'), _text('region')].where((value) => value.isNotEmpty).join(', ');
    final headline = _text('headline');
    final bio = _text('bio');
    final pronouns = _text('pronouns');
    final gender = _text('genderIdentity');
    final orientation = _text('orientation');
    final structure = _text('relationshipStructure');
    final status = _text('relationshipStatus');
    final lookingFor = _text('lookingForNote');
    final intentions = _strings('intentionTags');
    final interests = _strings('interests');

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          PopupMenuButton<String>(
            enabled: !_acting,
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: CircleAvatar(radius: 48, child: Icon(Icons.person, size: 46)),
          ),
          const SizedBox(height: 18),
          Text(
            age == null ? displayName : '$displayName, $age',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (headline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(headline, textAlign: TextAlign.center),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(location, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 22),
          if (pronouns.isNotEmpty || gender.isNotEmpty || orientation.isNotEmpty)
            _chips([pronouns, gender, orientation].where((value) => value.isNotEmpty).toList()),
          if (structure.isNotEmpty || status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Relationship style', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text([structure, status].where((value) => value.isNotEmpty).join(' • ')),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('About', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(bio),
          ],
          if (intentions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Intentions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _chips(intentions),
          ],
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Interests', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _chips(interests),
          ],
          if (lookingFor.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Looking for', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(lookingFor),
          ],
          const SizedBox(height: 26),
          const Divider(),
          const SizedBox(height: 18),
          Text('Their Circle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Relationship details appear only when their Circle and individual card privacy settings allow it.'),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _uid.isEmpty ? Future.value(const []) : _circle.loadForProfile(_uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const Text('This Circle is not shared with you.');
              }
              final cards = snapshot.data ?? const [];
              if (cards.isEmpty) return const Text('No Circle details are currently shared with you.');
              return Column(
                children: cards.map((card) {
                  final name = card['displayNameOptional']?.toString().trim() ?? '';
                  final label = card['label']?.toString().trim() ?? 'Connection';
                  final type = card['connectionType']?.toString().trim() ?? '';
                  final cardStatus = card['status']?.toString().trim() ?? '';
                  final note = card['note']?.toString().trim() ?? '';
                  final subtitleParts = [type, cardStatus].where((value) => value.isNotEmpty).join(' • ');
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.hub_outlined),
                      title: Text(name.isEmpty ? label : '$label · $name'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subtitleParts.isNotEmpty) Text(subtitleParts),
                          if (note.isNotEmpty) Text(note),
                        ],
                      ),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _acting ? null : _like,
            icon: const Icon(Icons.favorite_border),
            label: Text(_acting ? 'Please wait…' : 'Send interest'),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
