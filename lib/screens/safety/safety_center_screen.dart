import 'package:flutter/material.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety center')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Your boundaries are part of the product',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Polycircle is built for consensual adult connections. A match never means consent to sexual messages, intimate media, meeting in person, or continued contact.',
          ),
          const SizedBox(height: 20),
          _section(
            context,
            icon: Icons.block,
            title: 'Block at any time',
            body: 'Blocking ends interaction through Polycircle. Existing connection and chat access are closed, and any private-media access is revoked. Unblocking does not automatically restore them.',
          ),
          _section(
            context,
            icon: Icons.link_off,
            title: 'End a connection',
            body: 'Ending a connection closes the chat and revokes private-media sharing in both directions. The person will not silently reappear in Discover through the current reconnect flow.',
          ),
          _section(
            context,
            icon: Icons.flag_outlined,
            title: 'Report concerning behavior',
            body: 'Profiles and chats include reporting controls for harassment, fake profiles, hate speech, misrepresentation, spam, non-consensual content, and other safety concerns.',
          ),
          _section(
            context,
            icon: Icons.lock_outline,
            title: 'Private media stays gated',
            body: 'Private Vault is not available until its additional consent, moderation, retention, and security requirements pass. When enabled, sharing will require explicit consent and protected delivery.',
          ),
          _section(
            context,
            icon: Icons.photo_outlined,
            title: 'Profile photos are protected',
            body: 'Profile photos use a protected processing and review flow. Other permitted members receive short-lived access instead of permanent public Storage links.',
          ),
          _section(
            context,
            icon: Icons.location_off_outlined,
            title: 'Keep location coarse',
            body: 'The current profile uses city and region rather than publishing exact location. Share only the location detail you are comfortable putting on your profile.',
          ),
          _section(
            context,
            icon: Icons.people_outline,
            title: 'Relationship descriptions are not verification',
            body: 'A relationship card describes the account owner’s view. Naming another person does not mean that person has confirmed the relationship or consented to be represented.',
          ),
          _section(
            context,
            icon: Icons.no_accounts_outlined,
            title: 'Adults only',
            body: 'Polycircle is for people age 18 and older. Sexual or romantic exploitation of minors and sexual content involving minors are prohibited.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Polycircle’s block and report tools are product safety controls, not emergency services. If you are in immediate danger, use the emergency resources appropriate to your location.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
