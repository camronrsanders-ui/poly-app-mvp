import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/models/profile.dart';

void main() {
  group('Profile', () {
    test('round-trips through map serialization', () {
      const profile = Profile(
        uid: 'user-1',
        displayName: 'Alex',
        age: 32,
        city: 'Boston',
        region: 'MA',
        bio: 'Community-minded and open to connection.',
        headline: 'Building my circle intentionally',
        genderIdentity: 'Nonbinary',
        pronouns: 'they/them',
        orientation: 'Queer',
        customIdentityTags: ['polyamorous'],
        relationshipStructure: 'Non-hierarchical poly',
        relationshipStatus: 'Partnered',
        partnered: true,
        openToConnections: true,
        intentionTags: ['Friendship', 'Dating'],
        interests: ['Cooking', 'Travel'],
        lookingForNote: 'Open to genuine connections.',
        ageMin: 25,
        ageMax: 45,
        distanceRadius: 30,
        preferredStructures: ['Solo poly'],
        preferredIntentions: ['Friendship'],
        profileVisibility: 'public',
        mapVisibility: 'matches_only',
      );

      final restored = Profile.fromMap(profile.uid, profile.toMap());

      expect(restored.uid, profile.uid);
      expect(restored.displayName, profile.displayName);
      expect(restored.age, profile.age);
      expect(restored.intentionTags, profile.intentionTags);
      expect(restored.customIdentityTags, profile.customIdentityTags);
      expect(restored.profileVisibility, 'public');
      expect(restored.mapVisibility, 'matches_only');
      expect(profile.toMap().containsKey('photoUrls'), isFalse);
      expect(profile.toMap().containsKey('avatarUrl'), isFalse);
    });

    test('uses privacy-conscious defaults for missing fields', () {
      final profile = Profile.fromMap('user-2', const {});

      expect(profile.age, 18);
      expect(profile.ageMin, 18);
      expect(profile.ageMax, 99);
      expect(profile.distanceRadius, 50);
      expect(profile.openToConnections, isTrue);
      expect(profile.profileVisibility, 'public');
      expect(profile.mapVisibility, 'matches_only');
      expect(profile.customIdentityTags, isEmpty);
    });
  });
}
