import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _headline = TextEditingController();
  final _gender = TextEditingController();
  final _pronouns = TextEditingController();
  final _orientation = TextEditingController();
  final _relationship = TextEditingController();
  final _lookingFor = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _openToConnections = true;
  String _profileVisibility = 'public';
  String _mapVisibility = 'matches_only';
  List<String> _intentions = [];

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
      _bio.text = data['bio'] as String? ?? '';
      _headline.text = data['headline'] as String? ?? '';
      _gender.text = data['genderIdentity'] as String? ?? '';
      _pronouns.text = data['pronouns'] as String? ?? '';
      _orientation.text = data['orientation'] as String? ?? '';
      _relationship.text = data['relationshipStructure'] as String? ?? '';
      _lookingFor.text = data['lookingForNote'] as String? ?? '';
      _openToConnections = data['openToConnections'] as bool? ?? true;
      _profileVisibility = data['profileVisibility'] as String? ?? 'public';
      _mapVisibility = data['mapVisibility'] as String? ?? 'matches_only';
      _intentions = List<String>.from(data['intentionTags'] ?? const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await _profileService.saveProfile(uid, {
        'displayName': _name.text.trim(),
        'bio': _bio.text.trim(),
        'headline': _headline.text.trim(),
        'genderIdentity': _gender.text.trim(),
        'pronouns': _pronouns.text.trim(),
        'orientation': _orientation.text.trim(),
        'relationshipStructure': _relationship.text.trim(),
        'lookingForNote': _lookingFor.text.trim(),
        'openToConnections': _openToConnections,
        'profileVisibility': _profileVisibility,
        'mapVisibility': _mapVisibility,
        'intentionTags': _intentions,
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

  Widget _field(TextEditingController controller, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _headline.dispose();
    _gender.dispose();
    _pronouns.dispose();
    _orientation.dispose();
    _relationship.dispose();
    _lookingFor.dispose();
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
        _field(_name, 'Display name'),
        _field(_headline, 'Headline'),
        _field(_bio, 'About me', maxLines: 4),
        _field(_gender, 'Gender identity'),
        _field(_pronouns, 'Pronouns'),
        _field(_orientation, 'Orientation'),
        _field(_relationship, 'Relationship structure'),
        _field(_lookingFor, 'What I am looking for', maxLines: 3),
        const SizedBox(height: 8),
        Text('Intentions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _intentionOptions.map((item) => FilterChip(
            label: Text(item),
            selected: _intentions.contains(item),
            onSelected: (selected) => setState(() {
              if (selected) {
                _intentions.add(item);
              } else {
                _intentions.remove(item);
              }
            }),
          )).toList(),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Open to new connections'),
          value: _openToConnections,
          onChanged: (value) => setState(() => _openToConnections = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _profileVisibility,
          decoration: const InputDecoration(labelText: 'Profile visibility'),
          items: const [
            DropdownMenuItem(value: 'public', child: Text('Public to signed-in members')),
            DropdownMenuItem(value: 'hidden', child: Text('Hidden')),
          ],
          onChanged: (value) => setState(() => _profileVisibility = value ?? 'public'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _mapVisibility,
          decoration: const InputDecoration(labelText: 'Circle visibility'),
          items: const [
            DropdownMenuItem(value: 'public', child: Text('Public')),
            DropdownMenuItem(value: 'matches_only', child: Text('Connections only')),
            DropdownMenuItem(value: 'private', child: Text('Private')),
          ],
          onChanged: (value) => setState(() => _mapVisibility = value ?? 'matches_only'),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save profile'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : _authService.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
