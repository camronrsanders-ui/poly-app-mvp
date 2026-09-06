import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/world_crossing.dart';
import '../services/profile_service.dart';

class WhyOurWorldsCrossSection extends StatefulWidget {
  const WhyOurWorldsCrossSection({
    super.key,
    required this.otherProfile,
  });

  final Map<String, dynamic> otherProfile;

  @override
  State<WhyOurWorldsCrossSection> createState() =>
      _WhyOurWorldsCrossSectionState();
}

class _WhyOurWorldsCrossSectionState extends State<WhyOurWorldsCrossSection> {
  final _profiles = ProfileService();
  late final Future<Map<String, dynamic>?> _viewerProfileFuture;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _viewerProfileFuture =
        uid == null ? Future.value(null) : _profiles.getProfile(uid);
  }

  IconData _iconFor(String title) {
    switch (title) {
      case 'Shared interests':
        return Icons.favorite_border;
      case 'Shared intentions':
        return Icons.explore_outlined;
      default:
        return Icons.hub_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Why our worlds cross',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Shared details come only from what you both chose to put on your profiles — never a compatibility score.',
            ),
            const SizedBox(height: 14),
            FutureBuilder<Map<String, dynamic>?>(
              future: _viewerProfileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError || snapshot.data == null) {
                  return const Text(
                    'Shared profile details are unavailable right now.',
                  );
                }

                final insights = WorldCrossing.fromProfiles(
                  snapshot.data!,
                  widget.otherProfile,
                );

                if (insights.isEmpty) {
                  return const Text(
                    'No shared profile details are visible yet. As both profiles add interests and intentions, meaningful overlap can appear here.',
                  );
                }

                return Column(
                  children: insights
                      .map(
                        (insight) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colors.primaryContainer,
                                    foregroundColor: colors.onPrimaryContainer,
                                    child: Icon(_iconFor(insight.title)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          insight.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(insight.detail),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: insight.tags
                                              .map(
                                                (tag) => Chip(
                                                  label: Text(tag),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                              )
                                              .toList(growable: false),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
