import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  static const structures = [
    'Solo poly', 'Hierarchical poly', 'Non-hierarchical poly', 'Open relationship',
    'Polyfidelity', 'Relationship anarchy', 'Monogamish', 'Exploring', 'Custom / self-described',
  ];
  static const intentions = [
    'Friendship', 'Community', 'Dating', 'Long-term relationship', 'Casual connection',
    'Join a polycule', 'Build / grow a polycule', 'Exploring / learning',
  ];

  @override
  void dispose() {
    _page.dispose(); _name.dispose(); _age.dispose(); _city.dispose(); _region.dispose();
    _gender.dispose(); _pronouns.dispose(); _orientation.dispose(); _bio.dispose(); _lookingFor.dispose();
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
    if (_name.text.trim().isEmpty || int.tryParse(_age.text) == null || _structure == null || _intentions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete your name, age, relationship structure, and at least one intention.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _profileService.saveProfile(uid, {
        'displayName': _name.text.trim(),
        'age': int.parse(_age.text),
        'city': _city.text.trim(),
        'region': _region.text.trim(),
        'bio': _bio.text.trim(),
        'headline': '',
        'photoUrls': <String>[],
        'avatarUrl': '',
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
      widget.onComplete();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(controller: c, keyboardType: keyboard, decoration: InputDecoration(labelText: label)),
  );

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _OnboardingPage(title: 'Start with you', subtitle: 'Use the name you want people in your circle to know you by.', children: [
        _field(_name, 'Display name'), _field(_age, 'Age', keyboard: TextInputType.number), _field(_city, 'City'), _field(_region, 'State / region'),
      ]),
      _OnboardingPage(title: 'How do you identify?', subtitle: 'Your identity belongs to you. Self-described answers are welcome.', children: [
        _field(_gender, 'Gender identity'), _field(_pronouns, 'Pronouns'), _field(_orientation, 'Orientation'),
      ]),
      _OnboardingPage(title: 'How do you connect?', subtitle: 'Choose the relationship structure that best describes you right now. You can change this later.', children: [
        ...structures.map((s) => RadioListTile<String>(value: s, groupValue: _structure, title: Text(s), onChanged: (v) => setState(() => _structure = v))),
      ]),
      _OnboardingPage(title: 'What are you hoping to find?', subtitle: 'Choose as many as feel right.', children: [
        Wrap(spacing: 8, runSpacing: 8, children: intentions.map((i) => FilterChip(
          label: Text(i), selected: _intentions.contains(i), onSelected: (selected) => setState(() => selected ? _intentions.add(i) : _intentions.remove(i)),
        )).toList()),
      ]),
      _OnboardingPage(title: 'Tell your circle a little more', subtitle: 'Keep it genuine. You can always edit this later.', children: [
        _field(_bio, 'About me'), _field(_lookingFor, 'What are you looking for?'),
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
            if (_step > 0) TextButton(onPressed: () { setState(() => _step--); _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut); }, child: const Text('Back')),
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
      const SizedBox(height: 8), Text(subtitle), const SizedBox(height: 24), ...children,
    ],
  );
}
