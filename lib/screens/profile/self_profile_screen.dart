import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/circle_view_service.dart';
import '../../services/profile_media_service.dart';
import '../../services/profile_service.dart';
import 'profile_photos_screen.dart';
import 'profile_screen.dart';

enum _PreviewAudience { member, connection }

class SelfProfileScreen extends StatefulWidget {
  const SelfProfileScreen({super.key});

  @override
  State<SelfProfileScreen> createState() => _SelfProfileScreenState();
}

class _SelfProfileScreenState extends State<SelfProfileScreen> {
  final _profiles = ProfileService();
  final _media = ProfileMediaService();
  final _circle = CircleViewService();

  late Future<_SelfProfileData> _future;
  _PreviewAudience _audience = _PreviewAudience.member;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SelfProfileData> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in required.');
    }

    final profile = Map<String, dynamic>.from(
      await _profiles.getProfile(uid) ?? <String, dynamic>{},
    );
    profile['uid'] = uid;

    final statuses = await _media.listMyPhotos();
    final active = statuses
        .where((photo) => photo.status == 'active')
        .toList(growable: false)
      ..sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

    final visiblePhotos = <VisibleProfilePhoto>[];
    for (final photo in active) {
      try {
        final url = await _media.getAccessUrl(photo.photoId);
        visiblePhotos.add(VisibleProfilePhoto(
          photoId: photo.photoId,
          url: url,
          createdAt: photo.createdAt,
        ));
      } catch (_) {
        // One unavailable protected image must not break the whole preview.
      }
    }

    List<Map<String, dynamic>> circleCards = const [];
    try {
      circleCards = await _circle.loadForProfile(uid);
    } catch (_) {
      // The basic member-facing preview remains usable if Circle is unavailable.
    }

    return _SelfProfileData(
      profile: profile,
      photoStatuses: statuses,
      visiblePhotos: visiblePhotos,
      circleCards: circleCards,
    );
  }

  Future<void> _reload() async {
    final next = _load();
    if (mounted) {
      setState(() {
        _future = next;
      });
    }
    await next;
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Edit profile')),
          body: const ProfileScreen(),
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _managePhotos() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ProfilePhotosScreen()),
    );
    if (mounted) await _reload();
  }

  String _text(Map<String, dynamic> profile, String key, {int? maxLength}) {
    final raw = profile[key];
    if (raw is! String) return '';
    final value = raw.trim();
    if (maxLength == null || value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }

  int? _age(Map<String, dynamic> profile) {
    final raw = profile['age'];
    if (raw is! num) return null;
    final value = raw.toInt();
    return value >= 18 && value <= 120 ? value : null;
  }

  List<String> _strings(
    Map<String, dynamic> profile,
    String key, {
    required int maxItems,
    required int maxItemLength,
  }) {
    final raw = profile[key];
    if (raw is! List) return const [];
    final seen = <String>{};
    final output = <String>[];
    for (final item in raw.whereType<String>()) {
      var value = item.trim();
      if (value.isEmpty) continue;
      if (value.length > maxItemLength) {
        value = value.substring(0, maxItemLength);
      }
      if (!seen.add(value)) continue;
      output.add(value);
      if (output.length >= maxItems) break;
    }
    return output;
  }

  Widget _chips(List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map((value) => Chip(label: Text(value)))
          .toList(growable: false),
    );
  }

  Widget _photoArea(_SelfProfileData data) {
    final photos = data.visiblePhotos;
    if (photos.isNotEmpty) {
      return SizedBox(
        height: 360,
        child: PageView.builder(
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  photo.url.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _photoPlaceholder(
                    'This protected photo link expired. Pull down to refresh.',
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final pending = data.photoStatuses.any((photo) =>
        photo.status == 'awaiting_upload' ||
        photo.status == 'pending_processing' ||
        photo.status == 'processed_pending_review');
    return _photoPlaceholder(
      pending
          ? 'Your photo is still processing or awaiting review. You will see it here after approval.'
          : 'Add an approved profile photo to see it here.',
    );
  }

  Widget _photoPlaceholder(String message) => Container(
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 48,
                  child: Icon(Icons.person, size: 46),
                ),
                const SizedBox(height: 14),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );

  List<Map<String, dynamic>> _circleForAudience(_SelfProfileData data) {
    final mapVisibility = _text(data.profile, 'mapVisibility');
    final isConnection = _audience == _PreviewAudience.connection;

    if (mapVisibility == 'private') return const [];
    if (mapVisibility == 'matches_only' && !isConnection) return const [];
    if (mapVisibility != 'public' && mapVisibility != 'matches_only') {
      return const [];
    }

    final output = <Map<String, dynamic>>[];
    for (final raw in data.circleCards) {
      final visibility = raw['visibility']?.toString() ?? 'private';
      if (visibility == 'private') continue;
      if (visibility == 'matches_only' && !isConnection) continue;
      if (visibility != 'public' &&
          visibility != 'matches_only' &&
          visibility != 'unnamed_public') {
        continue;
      }

      final card = Map<String, dynamic>.from(raw);
      if (visibility == 'unnamed_public') {
        card.remove('displayNameOptional');
        card.remove('note');
      }
      output.add(card);
    }
    output.sort((a, b) =>
        (a['sortOrder'] as num? ?? 0).compareTo(b['sortOrder'] as num? ?? 0));
    return output;
  }

  String _circleEmptyText(_SelfProfileData data) {
    final mapVisibility = _text(data.profile, 'mapVisibility');
    final isConnection = _audience == _PreviewAudience.connection;
    if (mapVisibility == 'private') {
      return 'Your Circle is private, so it is not shown in this member-facing preview.';
    }
    if (mapVisibility == 'matches_only' && !isConnection) {
      return 'Your Circle is shared with connections only.';
    }
    return 'No Circle details are shared with this audience.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SelfProfileData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 52),
                  const SizedBox(height: 14),
                  Text(
                    'Could not load your profile preview',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your profile was not changed. Try again to request fresh protected profile data.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _reload, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final profile = data.profile;
        final displayName = _text(profile, 'displayName', maxLength: 80).isEmpty
            ? 'Your profile'
            : _text(profile, 'displayName', maxLength: 80);
        final age = _age(profile);
        final location = [
          _text(profile, 'city', maxLength: 100),
          _text(profile, 'region', maxLength: 100),
        ].where((value) => value.isNotEmpty).join(', ');
        final headline = _text(profile, 'headline', maxLength: 160);
        final bio = _text(profile, 'bio', maxLength: 1500);
        final pronouns = _text(profile, 'pronouns', maxLength: 100);
        final gender = _text(profile, 'genderIdentity', maxLength: 100);
        final orientation = _text(profile, 'orientation', maxLength: 100);
        final structure =
            _text(profile, 'relationshipStructure', maxLength: 120);
        final relationshipStatus =
            _text(profile, 'relationshipStatus', maxLength: 120);
        final lookingFor = _text(profile, 'lookingForNote', maxLength: 1200);
        final customIdentityTags = _strings(
          profile,
          'customIdentityTags',
          maxItems: 12,
          maxItemLength: 100,
        );
        final intentions = _strings(
          profile,
          'intentionTags',
          maxItems: 12,
          maxItemLength: 100,
        );
        final interests = _strings(
          profile,
          'interests',
          maxItems: 20,
          maxItemLength: 100,
        );
        final visibility = _text(profile, 'profileVisibility');
        final circleCards = _circleForAudience(data);

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.visibility_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'View my profile',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Preview the profile fields and approved protected photos that other members can receive. Private discovery preferences are never shown here.',
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<_PreviewAudience>(
                        segments: const [
                          ButtonSegment(
                            value: _PreviewAudience.member,
                            icon: Icon(Icons.person_outline),
                            label: Text('Member'),
                          ),
                          ButtonSegment(
                            value: _PreviewAudience.connection,
                            icon: Icon(Icons.people_outline),
                            label: Text('Connection'),
                          ),
                        ],
                        selected: {_audience},
                        onSelectionChanged: (selection) {
                          if (selection.isNotEmpty) {
                            setState(() => _audience = selection.first);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _audience == _PreviewAudience.member
                            ? 'Member preview: how a signed-in member who is not connected to you can see your shared profile.'
                            : 'Connection preview: how an active connection can see profile and Circle fields allowed by your privacy settings.',
                      ),
                      if (visibility == 'hidden') ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Your profile is currently hidden. This is a preview only; hidden profiles are not available through normal member discovery.',
                        ),
                      ] else if (visibility == 'matches_only' &&
                          _audience == _PreviewAudience.member) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Your profile is set to Connections only, so a non-connected member normally cannot open it. This preview lets you inspect the content safely.',
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _editProfile,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit profile'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _managePhotos,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Photos'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _photoArea(data),
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
              if (pronouns.isNotEmpty ||
                  gender.isNotEmpty ||
                  orientation.isNotEmpty ||
                  customIdentityTags.isNotEmpty)
                _chips([
                  pronouns,
                  gender,
                  orientation,
                  ...customIdentityTags,
                ].where((value) => value.isNotEmpty).toList(growable: false)),
              if (structure.isNotEmpty || relationshipStatus.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Relationship style',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text([
                  structure,
                  relationshipStatus,
                ].where((value) => value.isNotEmpty).join(' • ')),
              ],
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('About', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(bio),
              ],
              if (intentions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Intentions',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _chips(intentions),
              ],
              if (interests.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Interests',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _chips(interests),
              ],
              if (lookingFor.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Looking for',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(lookingFor),
              ],
              const SizedBox(height: 26),
              const Divider(),
              const SizedBox(height: 18),
              Text('Circle preview',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Circle cards below are filtered to the selected audience. Private cards remain hidden, and unnamed-public cards stay redacted.',
              ),
              const SizedBox(height: 12),
              if (circleCards.isEmpty)
                Text(_circleEmptyText(data))
              else
                ...circleCards.map((card) {
                  final name =
                      card['displayNameOptional']?.toString().trim() ?? '';
                  final label =
                      card['label']?.toString().trim() ?? 'Connection';
                  final type = card['connectionType']?.toString().trim() ?? '';
                  final status = card['status']?.toString().trim() ?? '';
                  final note = card['note']?.toString().trim() ?? '';
                  final subtitleParts = [type, status]
                      .where((value) => value.isNotEmpty)
                      .join(' • ');
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
                }),
              const SizedBox(height: 28),
            ],
          ),
        );
      },
    );
  }
}

class _SelfProfileData {
  const _SelfProfileData({
    required this.profile,
    required this.photoStatuses,
    required this.visiblePhotos,
    required this.circleCards,
  });

  final Map<String, dynamic> profile;
  final List<ProfileMediaStatus> photoStatuses;
  final List<VisibleProfilePhoto> visiblePhotos;
  final List<Map<String, dynamic>> circleCards;
}
