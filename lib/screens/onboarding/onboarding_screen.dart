import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/discovery_options.dart';
import '../../services/profile_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  final _profileService = ProfileService();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _gender = TextEditingController();
  final _pronouns = TextEditingController();
  final _orientation = TextEditingController();
  final _bio = TextEditingController();
  final _lookingFor = TextEditingController();
  int _step = 0;
  bool _busy = false;
  String? _structure;
  final Set<String> _intentions = {};

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _age.dispose();
    _city.dispose();
    _region.dispose();
    _gender.dispose();
    _pronouns.dispose();
    _orientation.dispose();
    _bio.dispose();
    _lookingFor.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 4) {
      setState(() => _step++);
      _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final age = int.tryParse(_age.text.trim());
    if (_name.text.trim().isEmpty || age == null || _structure == null || _intentions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please complete your name, age, relationship structure, and at least one intention.'),
      ));
      return;
    }
    if (age < 18) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Polycircle is for adults age 18 and older.'),
      ));
      return;
    }
    if (age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid age.'),
      ));
      return;
    }

    setState(() => _busy = true);
    try {
      await _profileService.saveProfile(uid, {
        'displayName': _name.text.trim(),
        'age': age,
        'city': _city.text.trim(),
        'region': _region.text.trim(),
        'bio': _bio.text.trim(),
        'headline': '',
        'genderIdentity': _gender.text.trim(),
        'pronouns': _pronouns.text.trim(),
        'orientation': _orientation.text.trim(),
        'customIdentityTags': <String>[],
        'relationshipStructure': _structure,
        'relationshipStatus': '',
        'partnered': false,
        'openToConnections': true,
        'intentionTags': _intentions.toList(),
        'interests': <String>[],
        'lookingForNote': _lookingFor.text.trim(),
        'ageMin': 18,
        'ageMax': 99,
        'distanceRadius': 50,
        'preferredStructures': <String>[],
        'preferredIntentions': <String>[],
        'profileVisibility': 'public',
        'mapVisibility': 'matches_only',
      });
      await _profileService.completeOnboarding(uid);
      if (!mounted) return;
      widget.onComplete();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Onboarding save failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('We could not finish setting up your profile. Your answers are still here—please try again.'),
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: c,
      keyboardType: keyboard,
      maxLength: maxLength,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _OnboardingPage(title: 'Start with you', subtitle: 'Use the name you want people in your circle to know you by.', children: [
        _field(_name, 'Display name', maxLength: 80),
        _field(_age, 'Age (18+)', keyboard: TextInputType.number, maxLength: 3),
        _field(_city, 'City', maxLength: 100),
        _field(_region, 'State / region', maxLength: 100),
      ]),
      _OnboardingPage(title: 'How do you identify?', subtitle: 'Your identity belongs to you. Self-described answers are welcome.', children: [
        _field(_gender, 'Gender identity', maxLength: 100),
        _field(_pronouns, 'Pronouns', maxLength: 100),
        _field(_orientation, 'Orientation', maxLength: 100),
      ]),
      _OnboardingPage(title: 'How do you connect?', subtitle: 'Choose the relationship structure that best describes you right now. You can change this later.', children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: relationshipStructureOptions.map((s) => ChoiceChip(
            label: Text(s),
            selected: _structure == s,
            onSelected: _busy ? null : (_) => setState(() => _structure = s),
          )).toList(),
        ),
      ]),
      _OnboardingPage(title: 'What are you hoping to find?', subtitle: 'Choose as many as feel right.', children: [
        Wrap(spacing: 8, runSpacing: 8, children: connectionIntentionOptions.map((i) => FilterChip(
          label: Text(i), selected: _intentions.contains(i), onSelected: _busy ? null : (selected) => setState(() => selected ? _intentions.add(i) : _intentions.remove(i)),
        )).toList()),
      ]),
      _OnboardingPage(title: 'Tell your circle a little more', subtitle: 'Keep it genuine. You can always edit this later.', children: [
        _field(_bio, 'About me', maxLength: 1500),
        _field(_lookingFor, 'What are you looking for?', maxLength: 1200),
        const ListTile(title: Text('Relationship cards come next'), subtitle: Text('After onboarding, Circle lets you represent important relationships with individual privacy controls.')),
      ]),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Create your Polycircle')),
      body: SafeArea(child: Column(children: [
        LinearProgressIndicator(value: (_step + 1) / pages.length),
        Expanded(child: PageView(controller: _page, physics: const NeverScrollableScrollPhysics(), children: pages)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (_step > 0)
              TextButton(
                onPressed: _busy ? null : () {
                  setState(() => _step--);
                  _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                },
                child: const Text('Back'),
              ),
            const Spacer(),
            FilledButton(onPressed: _busy ? null : _next, child: Text(_busy ? 'Saving…' : (_step == pages.length - 1 ? 'Enter Polycircle' : 'Continue'))),
          ]),
        ),
      ])),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(subtitle),
      const SizedBox(height: 24),
      ...children,
    ],
  );
}
