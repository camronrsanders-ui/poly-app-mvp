import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../config/discovery_options.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import 'profile_photos_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _profileVisibilityOptions = ['public', 'hidden', 'matches_only'];
  static const _mapVisibilityOptions = ['public', 'matches_only', 'private'];

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
  Object? _loadError;
  bool _partnered = false;
  bool _openToConnections = true;
  String _profileVisibility = 'public';
  String _mapVisibility = 'matches_only';
  List<String> _intentions = [];
  final Set<String> _preferredStructures = {};
  final Set<String> _preferredIntentions = {};
  RangeValues _ageRange = const RangeValues(18, 99);
  double _distanceRadius = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String ? value : '';
  }

  List<String> _strings(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String _choice(Object? raw, List<String> allowed, String fallback) {
    final value = raw?.toString() ?? '';
    return allowed.contains(value) ? value : fallback;
  }

  bool _shouldRetryProfileLoad(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseException) {
      return const {
        'aborted',
        'cancelled',
        'deadline-exceeded',
        'internal',
        'unavailable',
        'unknown',
      }.contains(error.code);
    }
    return false;
  }

  Future<Map<String, dynamic>?> _loadProfileWithRetry(String uid) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await _profileService
            .getProfile(uid)
            .timeout(const Duration(seconds: 8));
      } catch (error) {
        debugPrint('Profile load attempt $attempt/3 failed: $error');
        if (attempt == 3 || !_shouldRetryProfileLoad(error)) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: attempt == 1 ? 300 : 700),
        );
      }
    }
    throw StateError('Profile load retry loop ended unexpectedly.');
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final data = await _loadProfileWithRetry(uid) ?? {};
      _name.text = _string(data, 'displayName');
      _age.text = ((data['age'] as num?)?.toInt() ?? 18).clamp(18, 120).toString();
      _city.text = _string(data, 'city');
      _region.text = _string(data, 'region');
      _bio.text = _string(data, 'bio');
      _headline.text = _string(data, 'headline');
      _gender.text = _string(data, 'genderIdentity');
      _pronouns.text = _string(data, 'pronouns');
      _orientation.text = _string(data, 'orientation');
      _relationship.text = _string(data, 'relationshipStructure');
      _relationshipStatus.text = _string(data, 'relationshipStatus');
      _lookingFor.text = _string(data, 'lookingForNote');
      _interests.text = _strings(data['interests']).take(20).join(', ');
      _partnered = data['partnered'] is bool ? data['partnered'] as bool : false;
      _openToConnections = data['openToConnections'] is bool ? data['openToConnections'] as bool : true;
      _profileVisibility = _choice(data['profileVisibility'], _profileVisibilityOptions, 'public');
      _mapVisibility = _choice(data['mapVisibility'], _mapVisibilityOptions, 'matches_only');
      _intentions = _strings(data['intentionTags'])
          .where(connectionIntentionOptions.contains)
          .take(12)
          .toList(growable: true);
      _preferredStructures
        ..clear()
        ..addAll(_strings(data['preferredStructures']).where(relationshipStructureOptions.contains).take(12));
      _preferredIntentions
        ..clear()
        ..addAll(_strings(data['preferredIntentions']).where(connectionIntentionOptions.contains).take(12));

      final minAge = ((data['ageMin'] as num?)?.toDouble() ?? 18).clamp(18, 120).toDouble();
      final maxAgeRaw = ((data['ageMax'] as num?)?.toDouble() ?? 99).clamp(18, 120).toDouble();
      _ageRange = RangeValues(minAge, maxAgeRaw < minAge ? minAge : maxAgeRaw);
      _distanceRadius = ((data['distanceRadius'] as num?)?.toDouble() ?? 50).clamp(1, 500).toDouble();
    } catch (error) {
      _loadError = error;
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
          ? 'For your security, sign in again before finishing account deletion.'
          : e.code == 'internal'
              ? 'Deletion is paused safely. Sign in again to finish the remaining cleanup.'
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
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 52),
              const SizedBox(height: 14),
              Text('Could not load your profile', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Your profile was not changed. Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Your profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text('Share enough to be understood without giving up more privacy than you want.'),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfilePhotosScreen()),
          ),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Manage profile photos'),
        ),
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
          children: connectionIntentionOptions.map((item) => FilterChip(
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
          children: relationshipStructureOptions.map((item) => FilterChip(
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
          children: connectionIntentionOptions.map((item) => FilterChip(
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
          min: 1,
          max: 500,
          divisions: 499,
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
