import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _authService = AuthService();
  final _accountService = AccountService();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _bio = TextEditingController();
  final _headline = TextEditingController();
  final _gender = TextEditingController();
  final _pronouns = TextEditingController();
  final _orientation = TextEditingController();
  final _relationship = TextEditingController();
  final _relationshipStatus = TextEditingController();
  final _lookingFor = TextEditingController();
  final _interests = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _partnered = false;
  bool _openToConnections = true;
  String _profileVisibility = 'public';
  String _mapVisibility = 'matches_only';
  List<String> _intentions = [];
  final Set<String> _preferredStructures = {};
  final Set<String> _preferredIntentions = {};
  RangeValues _ageRange = const RangeValues(18, 99);
  double _distanceRadius = 50;

  static const _intentionOptions = [
    'Friendship',
    'Community',
    'Dating',
    'Long-term relationship',
    'Casual connection',
    'Join a polycule',
    'Build / grow a polycule',
    'Exploring / learning',
  ];

  static const _structureOptions = [
    'Solo poly',
    'Hierarchical poly',
    'Non-hierarchical poly',
    'Open relationship',
    'Polyfidelity',
    'Relationship anarchy',
    'Monogamish',
    'Exploring',
    'Custom / self-described',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final data = await _profileService.getProfile(uid) ?? {};
      _name.text = data['displayName'] as String? ?? '';
      _age.text = ((data['age'] as num?)?.toInt() ?? 18).toString();
      _city.text = data['city'] as String? ?? '';
      _region.text = data['region'] as String? ?? '';
      _bio.text = data['bio'] as String? ?? '';
      _headline.text = data['headline'] as String? ?? '';
      _gender.text = data['genderIdentity'] as String? ?? '';
      _pronouns.text = data['pronouns'] as String? ?? '';
      _orientation.text = data['orientation'] as String? ?? '';
      _relationship.text = data['relationshipStructure'] as String? ?? '';
      _relationshipStatus.text = data['relationshipStatus'] as String? ?? '';
      _lookingFor.text = data['lookingForNote'] as String? ?? '';
      _interests.text = List<String>.from(data['interests'] ?? const []).join(', ');
      _partnered = data['partnered'] as bool? ?? false;
      _openToConnections = data['openToConnections'] as bool? ?? true;
      _profileVisibility = data['profileVisibility'] as String? ?? 'public';
      _mapVisibility = data['mapVisibility'] as String? ?? 'matches_only';
      _intentions = List<String>.from(data['intentionTags'] ?? const []);
      _preferredStructures
        ..clear()
        ..addAll(List<String>.from(data['preferredStructures'] ?? const []));
      _preferredIntentions
        ..clear()
        ..addAll(List<String>.from(data['preferredIntentions'] ?? const []));

      final minAge = ((data['ageMin'] as num?)?.toDouble() ?? 18).clamp(18, 120).toDouble();
      final maxAgeRaw = ((data['ageMax'] as num?)?.toDouble() ?? 99).clamp(18, 120).toDouble();
      _ageRange = RangeValues(minAge, maxAgeRaw < minAge ? minAge : maxAgeRaw);
      _distanceRadius = ((data['distanceRadius'] as num?)?.toDouble() ?? 50).clamp(1, 500).toDouble();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _parsedInterests() => _interests.text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .take(20)
      .toList(growable: false);

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final age = int.tryParse(_age.text.trim());
    if (_name.text.trim().isEmpty || age == null || age < 18 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a display name and a valid age from 18 to 120.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _profileService.saveProfile(uid, {
        'displayName': _name.text.trim(),
        'age': age,
        'city': _city.text.trim(),
        'region': _region.text.trim(),
        'bio': _bio.text.trim(),
        'headline': _headline.text.trim(),
        'genderIdentity': _gender.text.trim(),
        'pronouns': _pronouns.text.trim(),
        'orientation': _orientation.text.trim(),
        'relationshipStructure': _relationship.text.trim(),
        'relationshipStatus': _relationshipStatus.text.trim(),
        'partnered': _partnered,
        'lookingForNote': _lookingFor.text.trim(),
        'interests': _parsedInterests(),
        'openToConnections': _openToConnections,
        'profileVisibility': _profileVisibility,
        'mapVisibility': _mapVisibility,
        'intentionTags': _intentions,
        'ageMin': _ageRange.start.round(),
        'ageMax': _ageRange.end.round(),
        'distanceRadius': _distanceRadius.round(),
        'preferredStructures': _preferredStructures.toList(growable: false),
        'preferredIntentions': _preferredIntentions.toList(growable: false),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your profile. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('This permanently removes your profile and account-owned data. It cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final confirm = TextEditingController();
    final second = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final confirmation'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Type DELETE to permanently delete your Polycircle account.'),
          const SizedBox(height: 12),
          TextField(controller: confirm, autocorrect: false, decoration: const InputDecoration(labelText: 'DELETE')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, confirm.text.trim() == 'DELETE'), child: const Text('Delete account')),
        ],
      ),
    );
    confirm.dispose();
    if (second != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _accountService.deleteMyAccount();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = e.code == 'failed-precondition'
          ? 'For your security, sign out and sign back in before deleting your account.'
          : 'Account deletion could not be completed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deletion could not be completed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _city.dispose();
    _region.dispose();
    _bio.dispose();
    _headline.dispose();
    _gender.dispose();
    _pronouns.dispose();
    _orientation.dispose();
    _relationship.dispose();
    _relationshipStatus.dispose();
    _lookingFor.dispose();
    _interests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Your profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text('Share enough to be understood without giving up more privacy than you want.'),
        const SizedBox(height: 22),
        _field(_name, 'Display name', maxLength: 80),
        _field(_age, 'Age', maxLength: 3, keyboardType: TextInputType.number),
        _field(_city, 'City', maxLength: 100),
        _field(_region, 'State / region', maxLength: 100),
        _field(_headline, 'Headline', maxLength: 160),
        _field(_bio, 'About me', maxLines: 4, maxLength: 1500),
        _field(_gender, 'Gender identity', maxLength: 100),
        _field(_pronouns, 'Pronouns', maxLength: 100),
        _field(_orientation, 'Orientation', maxLength: 100),
        _field(_relationship, 'Relationship structure', maxLength: 120),
        _field(_relationshipStatus, 'Relationship status', maxLength: 120),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('I currently have one or more partners'),
          value: _partnered,
          onChanged: (value) => setState(() => _partnered = value),
        ),
        _field(_lookingFor, 'What I am looking for', maxLines: 3, maxLength: 1200),
        _field(_interests, 'Interests (comma separated)', maxLines: 2),
        const SizedBox(height: 8),
        Text('Intentions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _intentionOptions.map((item) => FilterChip(
            label: Text(item),
            selected: _intentions.contains(item),
            onSelected: (selected) => setState(() => selected ? _intentions.add(item) : _intentions.remove(item)),
          )).toList(),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Open to new connections'),
          subtitle: const Text('Turn this off to stop appearing in Discover for new connections.'),
          value: _openToConnections,
          onChanged: (value) => setState(() => _openToConnections = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _profileVisibility,
          decoration: const InputDecoration(labelText: 'Profile visibility'),
          items: const [
            DropdownMenuItem(value: 'public', child: Text('Public to signed-in members')),
            DropdownMenuItem(value: 'hidden', child: Text('Hidden')),
            DropdownMenuItem(value: 'matches_only', child: Text('Connections only')),
          ],
          onChanged: (value) => setState(() => _profileVisibility = value ?? 'public'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _mapVisibility,
          decoration: const InputDecoration(labelText: 'Circle visibility'),
          items: const [
            DropdownMenuItem(value: 'public', child: Text('Public')),
            DropdownMenuItem(value: 'matches_only', child: Text('Connections only')),
            DropdownMenuItem(value: 'private', child: Text('Private')),
          ],
          onChanged: (value) => setState(() => _mapVisibility = value ?? 'matches_only'),
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 18),
        Text('Discovery preferences', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
          'These preferences are private. Polycircle applies them on the trusted backend and does not include them in profile views shown to other members.',
        ),
        const SizedBox(height: 20),
        Text('Age range: ${_ageRange.start.round()}–${_ageRange.end.round()}'),
        RangeSlider(
          values: _ageRange,
          min: 18,
          max: 120,
          divisions: 102,
          labels: RangeLabels(
            _ageRange.start.round().toString(),
            _ageRange.end.round().toString(),
          ),
          onChanged: (values) => setState(() => _ageRange = values),
        ),
        const SizedBox(height: 10),
        Text('Preferred relationship structures', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _structureOptions.map((item) => FilterChip(
            label: Text(item),
            selected: _preferredStructures.contains(item),
            onSelected: (selected) => setState(() =>
                selected ? _preferredStructures.add(item) : _preferredStructures.remove(item)),
          )).toList(),
        ),
        const SizedBox(height: 18),
        Text('Preferred intentions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _intentionOptions.map((item) => FilterChip(
            label: Text(item),
            selected: _preferredIntentions.contains(item),
            onSelected: (selected) => setState(() =>
                selected ? _preferredIntentions.add(item) : _preferredIntentions.remove(item)),
          )).toList(),
        ),
        const SizedBox(height: 18),
        Text('Distance preference: ${_distanceRadius.round()} miles'),
        Slider(
          value: _distanceRadius,
          min: 5,
          max: 500,
          divisions: 99,
          label: '${_distanceRadius.round()} mi',
          onChanged: (value) => setState(() => _distanceRadius = value),
        ),
        const Text(
          'Distance filtering will be applied only after location services are configured. Your exact location is not shown in your public profile.',
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save profile')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: (_saving || _deleting) ? null : _authService.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),
        Text('Account & privacy', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Account deletion is permanent and removes your public profile and account-owned data.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: (_saving || _deleting) ? null : _deleteAccount,
          icon: const Icon(Icons.delete_forever),
          label: Text(_deleting ? 'Deleting…' : 'Delete my account'),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
